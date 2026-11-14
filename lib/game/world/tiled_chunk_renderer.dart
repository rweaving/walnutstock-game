import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'day_night_atmosphere.dart';
import 'tiled_map_parser.dart';

/// Pre-records 16x16-tile `Picture` chunks for ground/decor and overhead canopy layers
/// with 2.5D directional sun/moon shadows, wet-ground specular reflections, wind sway, and height parallax.
class TiledChunkLayerComponent extends Component {
  TiledChunkLayerComponent({
    required this.map,
    required this.tilesetImage,
    required this.isCanopyLayer,
    this.metricsGetter,
    this.cameraCenterGetter,
    this.viewBoundsGetter,
    this.timeGetter,
    super.priority,
  }) {
    if (!isCanopyLayer) {
      final tw = map.tileWidth.toDouble();
      final th = map.tileHeight.toDouble();
      for (var ty = 0; ty < map.height; ty++) {
        for (var tx = 0; tx < map.width; tx++) {
          final dGid = map.decorGidAt(tx, ty);
          if (dGid < map.firstGid) continue;
          final def = map.defForGid(dGid);
          if (def == null) continue;
          final center = Offset((tx + 0.5) * tw, (ty + 0.5) * th);
          if (def.lantern) {
            _lanternCenters.add(center);
          }
          if (def.collidable) {
            _decorShadowCasters.add(Offset((tx + 0.5) * tw, (ty + 0.82) * th));
          }
        }
      }
    }
  }

  static const int chunkTiles = 16;

  final OrchardMapData map;
  final Image tilesetImage;
  final bool isCanopyLayer;
  final DayNightMetrics Function()? metricsGetter;
  final Offset Function()? cameraCenterGetter;
  final Rect Function()? viewBoundsGetter;
  final double Function()? timeGetter;

  late final int _chunksX = (map.width + chunkTiles - 1) ~/ chunkTiles;
  late final int _chunksY = (map.height + chunkTiles - 1) ~/ chunkTiles;
  final Map<int, Picture> _chunkPictures = {};
  final List<Offset> _lanternCenters = [];
  final List<Offset> _decorShadowCasters = [];

  bool lanternsLit = false;

  List<Offset> get lanternCenters => _lanternCenters;

  void invalidateAllChunks() {
    for (final pic in _chunkPictures.values) {
      pic.dispose();
    }
    _chunkPictures.clear();
  }

  @override
  void onRemove() {
    invalidateAllChunks();
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;

    final metrics = metricsGetter?.call() ?? DayNightMetrics.middayDefault;
    final cam = cameraCenterGetter?.call();
    final time = timeGetter?.call() ?? 0.0;

    final chunkPixelW = chunkTiles * map.tileWidth.toDouble();
    final chunkPixelH = chunkTiles * map.tileHeight.toDouble();

    // Frustum-cull chunks around camera (with generous margin) for locked 60 FPS
    int minCx = 0;
    int maxCx = _chunksX - 1;
    int minCy = 0;
    int maxCy = _chunksY - 1;
    Rect? viewBounds = viewBoundsGetter?.call().inflate(140.0);
    if (viewBounds == null && cam != null) {
      viewBounds = Rect.fromCenter(center: cam, width: 820, height: 760);
    }
    if (viewBounds != null) {
      minCx = (viewBounds.left / chunkPixelW).floor().clamp(0, _chunksX - 1);
      maxCx = (viewBounds.right / chunkPixelW).ceil().clamp(0, _chunksX - 1);
      minCy = (viewBounds.top / chunkPixelH).floor().clamp(0, _chunksY - 1);
      maxCy = (viewBounds.bottom / chunkPixelH).ceil().clamp(0, _chunksY - 1);
    }

    if (isCanopyLayer) {
      _renderCanopyWithParallaxAndShadows(
        canvas: canvas,
        paint: paint,
        metrics: metrics,
        cam: cam,
        viewBounds: viewBounds,
        time: time,
        minCx: minCx,
        maxCx: maxCx,
        minCy: minCy,
        maxCy: maxCy,
      );
      return;
    }

    for (var cy = minCy; cy <= maxCy; cy++) {
      for (var cx = minCx; cx <= maxCx; cx++) {
        final key = cy * _chunksX + cx;
        final pic = _chunkPictures[key] ??= _buildChunkPicture(cx, cy, paint);
        canvas.drawPicture(pic);
      }
    }

    // Dynamic solar/lunar 3D ground shadows cast by trees, tents, speakers & props
    if (metrics.shadowAlpha > 0.05 && _decorShadowCasters.isNotEmpty) {
      final shadowPaint = Paint()
        ..color = Color.fromRGBO(
          10,
          16,
          14,
          (metrics.shadowAlpha * 0.62).clamp(0.0, 0.30),
        );
      final sx = metrics.shadowOffset.dx * 0.72;
      final sy = metrics.shadowOffset.dy * 0.72;
      final stretchW = 14.0 + metrics.shadowOffset.dx.abs() * 0.65;
      for (final base in _decorShadowCasters) {
        if (viewBounds != null && !viewBounds.contains(base)) continue;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(base.dx + sx, base.dy + sy),
            width: stretchW,
            height: 6.5,
          ),
          shadowPaint,
        );
      }
    }

    // Wet-ground shimmering specular reflections & warm evening lantern halos
    if (lanternsLit && _lanternCenters.isNotEmpty) {
      final flicker = 0.92 + 0.08 * math.sin(time * 5.2);
      final glowPaint = Paint()
        ..color = Color.fromRGBO(255, 207, 86, (0.30 * flicker).clamp(0.0, 0.42))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
      final corePaint = Paint()
        ..color = Color.fromRGBO(255, 243, 176, (0.78 * flicker).clamp(0.0, 0.92));

      for (final center in _lanternCenters) {
        if (viewBounds != null && !viewBounds.contains(center)) continue;
        canvas.drawCircle(center, 18.5, glowPaint);
        canvas.drawCircle(Offset(center.dx, center.dy - 2.0), 2.4, corePaint);

        // Vertical 3D wet-pavement/mud reflection streak during & after rainstorm!
        if (metrics.wetness > 0.08) {
          final reflectAlpha = (0.34 * metrics.wetness * flicker).clamp(0.0, 0.38);
          final shimmerX = math.sin(time * 4.0 + center.dx) * 0.9;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(center.dx + shimmerX, center.dy + 13.0),
              width: 5.5,
              height: 16.0,
            ),
            Paint()
              ..color = Color.fromRGBO(255, 214, 112, reflectAlpha)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
      }
    }
  }

  void _renderCanopyWithParallaxAndShadows({
    required Canvas canvas,
    required Paint paint,
    required DayNightMetrics metrics,
    required Offset? cam,
    required Rect? viewBounds,
    required double time,
    required int minCx,
    required int maxCx,
    required int minCy,
    required int maxCy,
  }) {
    final swayAmp = 0.55 + metrics.windStrength * 2.1;
    final swayFreq = 1.25 + metrics.windStrength * 2.3;
    final swayX = math.sin(time * swayFreq) * swayAmp;
    final swayY = math.cos(time * swayFreq * 0.72) * (swayAmp * 0.38);

    // Subtle 2.5D elevated plane perspective parallax relative to camera
    var parallaxX = 0.0;
    var parallaxY = 0.0;
    if (cam != null) {
      parallaxX = ((cam.dx - map.pixelWidth * 0.5) * -0.012).clamp(-8.0, 8.0);
      parallaxY = ((cam.dy - map.pixelHeight * 0.5) * -0.012).clamp(-6.0, 6.0);
    }

    // 1. Cast soft offset canopy drop-shadow onto ground & stage edges
    if (metrics.shadowAlpha > 0.06 && viewBounds != null) {
      canvas.saveLayer(
        viewBounds,
        Paint()
          ..colorFilter = ColorFilter.mode(
            Color.fromRGBO(
              8,
              15,
              11,
              (metrics.shadowAlpha * 0.52).clamp(0.0, 0.24),
            ),
            BlendMode.srcIn,
          ),
      );
      canvas.translate(
        metrics.shadowOffset.dx * 1.15 + swayX * 0.6,
        metrics.shadowOffset.dy * 1.15 + 5.5 + swayY * 0.6,
      );
      for (var cy = minCy; cy <= maxCy; cy++) {
        for (var cx = minCx; cx <= maxCx; cx++) {
          final key = cy * _chunksX + cx;
          final pic = _chunkPictures[key] ??= _buildChunkPicture(cx, cy, paint);
          canvas.drawPicture(pic);
        }
      }
      canvas.restore();
    }

    // 2. Render elevated 3D-lit canopy chunks with wind sway + perspective parallax
    canvas.save();
    canvas.translate(parallaxX + swayX, parallaxY + swayY);
    for (var cy = minCy; cy <= maxCy; cy++) {
      for (var cx = minCx; cx <= maxCx; cx++) {
        final key = cy * _chunksX + cx;
        final pic = _chunkPictures[key] ??= _buildChunkPicture(cx, cy, paint);
        canvas.drawPicture(pic);
      }
    }
    canvas.restore();
  }

  Picture _buildChunkPicture(int cx, int cy, Paint paint) {
    final recorder = PictureRecorder();
    final c = Canvas(recorder);
    final tw = map.tileWidth.toDouble();
    final th = map.tileHeight.toDouble();

    final startX = cx * chunkTiles;
    final startY = cy * chunkTiles;
    final endX = (startX + chunkTiles).clamp(0, map.width);
    final endY = (startY + chunkTiles).clamp(0, map.height);

    for (var ty = startY; ty < endY; ty++) {
      for (var tx = startX; tx < endX; tx++) {
        final dst = Rect.fromLTWH(tx * tw, ty * th, tw, th);
        if (isCanopyLayer) {
          final cGid = map.canopyGidAt(tx, ty);
          if (cGid >= map.firstGid) {
            c.drawImageRect(tilesetImage, _srcRect(cGid), dst, paint);
          }
        } else {
          final gGid = map.groundGidAt(tx, ty);
          if (gGid >= map.firstGid) {
            c.drawImageRect(tilesetImage, _srcRect(gGid), dst, paint);
          }
          final dGid = map.decorGidAt(tx, ty);
          if (dGid >= map.firstGid) {
            c.drawImageRect(tilesetImage, _srcRect(dGid), dst, paint);
          }
        }
      }
    }
    return recorder.endRecording();
  }

  Rect _srcRect(int gid) {
    final id = gid - map.firstGid;
    final col = id % map.tilesetColumns;
    final row = id ~/ map.tilesetColumns;
    final tw = map.tileWidth.toDouble();
    final th = map.tileHeight.toDouble();
    return Rect.fromLTWH(col * tw, row * th, tw, th);
  }
}
