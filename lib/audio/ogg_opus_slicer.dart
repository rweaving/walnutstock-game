import 'dart:math' as math;
import 'dart:typed_data';

/// Precomputed direct (non-reflected) Ogg CRC-32 lookup table (`poly = 0x04C11DB7`).
final Uint32List _oggCrcTable = _buildOggCrcTable();

Uint32List _buildOggCrcTable() {
  final table = Uint32List(256);
  for (var i = 0; i < 256; i++) {
    var r = i << 24;
    for (var bit = 0; bit < 8; bit++) {
      if ((r & 0x80000000) != 0) {
        r = ((r << 1) ^ 0x04C11DB7) & 0xFFFFFFFF;
      } else {
        r = (r << 1) & 0xFFFFFFFF;
      }
    }
    table[i] = r;
  }
  return table;
}

/// Computes the standard RFC 3533 Ogg page CRC-32 over [pageBytes], treating
/// header checksum bytes `22..25` as zero.
int computeOggPageCrc32(Uint8List pageBytes) {
  var crc = 0;
  for (var i = 0; i < pageBytes.length; i++) {
    final byte = (i >= 22 && i <= 25) ? 0 : pageBytes[i];
    crc = (((crc << 8) & 0xFFFFFFFF) ^
            _oggCrcTable[((crc >>> 24) ^ byte) & 0xFF]) &
        0xFFFFFFFF;
  }
  return crc;
}

/// Reads a 64-bit little-endian signed Ogg `granule_position` using 32-bit
/// operations so it works identically on Dart VM and `dart2js` (Flutter Web,
/// where `ByteData.getInt64` throws `UnsupportedError` at runtime).
int readOggGranulePos(ByteData bd, int byteOffset) {
  final lo = bd.getUint32(byteOffset, Endian.little);
  final hi = bd.getUint32(byteOffset + 4, Endian.little);
  if ((hi & 0x80000000) != 0) {
    return -1;
  }
  // Multiply by 2^32 instead of `<< 32` because JS bitwise shift wraps mod 32.
  return hi * 4294967296 + lo;
}

/// Writes a 64-bit little-endian signed Ogg `granule_position` without using
/// `ByteData.setInt64` (unsupported in `dart2js`).
void writeOggGranulePos(ByteData bd, int byteOffset, int granule) {
  if (granule < 0) {
    bd.setUint32(byteOffset, 0xFFFFFFFF, Endian.little);
    bd.setUint32(byteOffset + 4, 0xFFFFFFFF, Endian.little);
    return;
  }
  final hi = granule ~/ 4294967296;
  final lo = granule.remainder(4294967296);
  bd.setUint32(byteOffset, lo, Endian.little);
  bd.setUint32(byteOffset + 4, hi, Endian.little);
}

class _OggPageSpan {
  const _OggPageSpan({
    required this.offset,
    required this.length,
    required this.headerType,
    required this.granulePos,
  });

  final int offset;
  final int length;
  final int headerType;
  final int granulePos;

  bool get isContinuedPacket => (headerType & 0x01) != 0;
  bool get isEos => (headerType & 0x04) != 0;
}

class OggOpusSliceResult {
  const OggOpusSliceResult({
    required this.bytes,
    required this.actualSeekSeconds,
    this.totalDurationSeconds,
    this.isAtOrPastEof = false,
  });

  final Uint8List bytes;
  final double actualSeekSeconds;
  final double? totalDurationSeconds;
  final bool isAtOrPastEof;
}

/// Slices a compressed Ogg Opus byte buffer so `SoLoud.setBufferStream` on Web
/// begins decoding cleanly at [seekSeconds] ("Live Concert Illusion", GDD §6.2)
/// while retaining mandatory `OpusHead` + `OpusTags` headers, continuous page
/// sequence numbers, adjusted EOS granule count, and valid Ogg page CRCs.
OggOpusSliceResult sliceOggOpusFromSeconds(
  Uint8List sourceBytes,
  double seekSeconds,
) {
  if (sourceBytes.length < 64 ||
      sourceBytes[0] != 0x4F ||
      sourceBytes[1] != 0x67 ||
      sourceBytes[2] != 0x67 ||
      sourceBytes[3] != 0x53) {
    return OggOpusSliceResult(bytes: sourceBytes, actualSeekSeconds: 0.0);
  }
  if (seekSeconds <= 0.4) {
    return OggOpusSliceResult(bytes: sourceBytes, actualSeekSeconds: 0.0);
  }

  final pages = <_OggPageSpan>[];
  final bd = ByteData.sublistView(sourceBytes);
  var cursor = 0;
  var preSkipSamples = 312;

  while (cursor + 27 <= sourceBytes.length) {
    if (sourceBytes[cursor] != 0x4F ||
        sourceBytes[cursor + 1] != 0x67 ||
        sourceBytes[cursor + 2] != 0x67 ||
        sourceBytes[cursor + 3] != 0x53) {
      break;
    }
    final headerType = sourceBytes[cursor + 5];
    final granule = readOggGranulePos(bd, cursor + 6);
    final segCount = sourceBytes[cursor + 26];
    if (cursor + 27 + segCount > sourceBytes.length) break;

    var bodyLen = 0;
    for (var s = 0; s < segCount; s++) {
      bodyLen += sourceBytes[cursor + 27 + s];
    }
    final pageLen = 27 + segCount + bodyLen;
    if (cursor + pageLen > sourceBytes.length) break;

    // Parse OpusHead pre_skip from BOS page body ('OpusHead' + version + channels + uint16 pre_skip)
    if (pages.isEmpty && bodyLen >= 12) {
      final bodyStart = cursor + 27 + segCount;
      if (sourceBytes[bodyStart] == 0x4F &&
          sourceBytes[bodyStart + 1] == 0x70 &&
          sourceBytes[bodyStart + 2] == 0x75 &&
          sourceBytes[bodyStart + 3] == 0x73) {
        preSkipSamples = bd.getUint16(bodyStart + 10, Endian.little);
      }
    }

    pages.add(
      _OggPageSpan(
        offset: cursor,
        length: pageLen,
        headerType: headerType,
        granulePos: granule,
      ),
    );
    cursor += pageLen;
  }

  if (pages.length < 4) {
    return OggOpusSliceResult(bytes: sourceBytes, actualSeekSeconds: 0.0);
  }

  // Retain leading header pages (granulePos == 0, e.g. OpusHead + OpusTags + continuation tags)
  var headerEndIdx = 0;
  while (headerEndIdx < pages.length && pages[headerEndIdx].granulePos == 0) {
    headerEndIdx++;
  }
  if (headerEndIdx == 0 || headerEndIdx >= pages.length - 1) {
    return OggOpusSliceResult(bytes: sourceBytes, actualSeekSeconds: 0.0);
  }

  var lastValidGranule = 0;
  for (var i = pages.length - 1; i >= headerEndIdx; i--) {
    if (pages[i].granulePos > preSkipSamples) {
      lastValidGranule = pages[i].granulePos;
      break;
    }
  }
  final totalDurationSeconds = lastValidGranule > preSkipSamples
      ? (lastValidGranule - preSkipSamples) / 48000.0
      : null;
  if (totalDurationSeconds != null &&
      seekSeconds >= totalDurationSeconds - 0.45) {
    return OggOpusSliceResult(
      bytes: Uint8List(0),
      actualSeekSeconds: totalDurationSeconds,
      totalDurationSeconds: totalDurationSeconds,
      isAtOrPastEof: true,
    );
  }

  // Ogg Opus granule positions always advance at 48,000 Hz (RFC 7845 §4)
  final targetGranule = preSkipSamples + (seekSeconds * 48000.0).round();
  var audioStartIdx = headerEndIdx;
  var prevGranule = preSkipSamples;

  for (var i = headerEndIdx; i < pages.length - 1; i++) {
    final p = pages[i];
    if (!p.isContinuedPacket) {
      if (prevGranule <= targetGranule) {
        audioStartIdx = i;
      } else {
        break;
      }
    }
    if (p.granulePos > 0) {
      prevGranule = p.granulePos;
    }
  }

  if (audioStartIdx <= headerEndIdx) {
    return OggOpusSliceResult(
      bytes: sourceBytes,
      actualSeekSeconds: 0.0,
      totalDurationSeconds: totalDurationSeconds,
    );
  }

  // Compute granulepos at end of page immediately preceding audioStartIdx
  var skippedAudioGranule = 0;
  for (var i = audioStartIdx - 1; i >= headerEndIdx; i--) {
    if (pages[i].granulePos > preSkipSamples) {
      skippedAudioGranule = pages[i].granulePos - preSkipSamples;
      break;
    }
  }
  if (skippedAudioGranule <= 0) {
    return OggOpusSliceResult(
      bytes: sourceBytes,
      actualSeekSeconds: 0.0,
      totalDurationSeconds: totalDurationSeconds,
    );
  }

  var outLength = 0;
  for (var i = 0; i < headerEndIdx; i++) {
    outLength += pages[i].length;
  }
  for (var i = audioStartIdx; i < pages.length; i++) {
    outLength += pages[i].length;
  }

  final out = Uint8List(outLength);
  var writePos = 0;
  var seqNo = 0;

  for (var i = 0; i < headerEndIdx; i++) {
    final p = pages[i];
    out.setRange(writePos, writePos + p.length, sourceBytes, p.offset);
    writePos += p.length;
    seqNo++;
  }

  for (var i = audioStartIdx; i < pages.length; i++) {
    final p = pages[i];
    out.setRange(writePos, writePos + p.length, sourceBytes, p.offset);
    final pageView = Uint8List.sublistView(out, writePos, writePos + p.length);
    final pageBd = ByteData.sublistView(pageView);

    // Adjust granulepos so EOS trimming matches the exact sliced sample count
    if (p.granulePos > 0) {
      final adjusted =
          math.max(preSkipSamples, p.granulePos - skippedAudioGranule);
      writeOggGranulePos(pageBd, 6, adjusted);
    }
    // Rewrite sequential page_sequence_number so libogg sees zero packet gap
    pageBd.setUint32(18, seqNo, Endian.little);
    pageBd.setUint32(22, 0, Endian.little);
    final crc = computeOggPageCrc32(pageView);
    pageBd.setUint32(22, crc, Endian.little);

    writePos += p.length;
    seqNo++;
  }

  return OggOpusSliceResult(
    bytes: out,
    actualSeekSeconds: skippedAudioGranule / 48000.0,
    totalDurationSeconds: totalDurationSeconds,
  );
}
