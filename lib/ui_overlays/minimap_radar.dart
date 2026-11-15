import 'package:flutter/foundation.dart' show setEquals;
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../state/journal_state.dart';
import '../state/providers.dart';
import '../state/world_flags.dart';

class MinimapRadarWidget extends ConsumerWidget {
  const MinimapRadarWidget({
    super.key,
    required this.playerX,
    required this.playerY,
  });

  final double playerX;
  final double playerY;

  static Offset? resolveQuestTarget(
    FestivalDataBundle data,
    JournalState journal,
    WorldFlags flags,
  ) {
    final trackedId = journal.trackedQuestId;
    if (trackedId == null) return null;
    final q = data.questById(trackedId);
    if (q == null) return null;

    if (q.id == 'quest_penny_tapestry' && !flags.pennyTapestryQuestCompleted) {
      if (flags.pennyTapestryQuestStarted) {
        if (!flags.fabricSwatches.contains('swatch_gate_petal')) {
          return const Offset(640, 1200);
        }
        if (!flags.fabricSwatches.contains('swatch_meadow_clover')) {
          return const Offset(1120, 520);
        }
        if (!flags.fabricSwatches.contains('swatch_urbano_gold')) {
          return const Offset(256, 1136);
        }
      }
      return const Offset(944, 1136);
    }
    if (q.id == 'quest_roxie_string' &&
        flags.roxieStringQuestStarted &&
        !flags.roxieStringQuestCompleted &&
        !flags.hasNickelString &&
        !journal.hasItem('quest_nickel_string')) {
      return const Offset(1360, 1208);
    }
    if (q.id == 'quest_fern_compass' &&
        !flags.fernCompassQuestCompleted &&
        (flags.hasBrassCompass || journal.hasItem('quest_brass_compass'))) {
      return const Offset(1184, 272);
    }
    return Offset(q.targetX, q.targetY);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final clock = ref.watch(festivalClockProvider);
    final flags = ref.watch(worldFlagsProvider);
    final journal = ref.watch(journalStateProvider);
    final data = ref.watch(festivalDataProvider);

    final activeStageIds = data.setlist
        .activeTracksAt(clock.day, clock.minuteOfDay)
        .map((t) => t.stageId)
        .toSet();

    final questTarget = resolveQuestTarget(data, journal, flags);

    final isCompact = MediaQuery.sizeOf(context).shortestSide < 540;
    final mapW = settings.minimapExpanded
        ? (isCompact ? 148.0 : 176.0)
        : (isCompact ? 90.0 : 112.0);
    final mapH = settings.minimapExpanded
        ? (isCompact ? 111.0 : 132.0)
        : (isCompact ? 68.0 : 84.0);

    return GestureDetector(
      key: const ValueKey('minimap_radar_toggle'),
      onTap: () => ref.read(settingsProvider.notifier).toggleMinimapExpanded(),
      child: Container(
        width: mapW,
        height: mapH,
        decoration: BoxDecoration(
          color: const Color(0xD9141E15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF74C69D), width: 1.5),
        ),
        child: CustomPaint(
          painter: _RadarPainter(
            playerX: playerX,
            playerY: playerY,
            activeStageIds: activeStageIds,
            stages: data.setlist.stages.values.toList(growable: false),
            showPeaceMarkers: flags.bittershellMapCompleted,
            mossBloomed: flags.mossBridgesBloomed,
            showDay2BlueberryShare: clock.isDay2BlueberrySharingActive,
            questTarget: questTarget,
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({
    required this.playerX,
    required this.playerY,
    required this.activeStageIds,
    required this.stages,
    required this.showPeaceMarkers,
    required this.mossBloomed,
    required this.showDay2BlueberryShare,
    required this.questTarget,
  });

  static const double worldW = 2048.0;
  static const double worldH = 1536.0;

  final double playerX;
  final double playerY;
  final Set<String> activeStageIds;
  final List<dynamic> stages;
  final bool showPeaceMarkers;
  final bool mossBloomed;
  final bool showDay2BlueberryShare;
  final Offset? questTarget;

  Offset _scale(double wx, double wy, Size size) => Offset(
        (wx / worldW).clamp(0.0, 1.0) * size.width,
        (wy / worldH).clamp(0.0, 1.0) * size.height,
      );

  @override
  void paint(Canvas canvas, Size size) {
    // Orchard lane crosshairs
    final roadPaint = Paint()
      ..color = const Color(0x669C7448)
      ..strokeWidth = 2.0;
    canvas.drawLine(
      _scale(608, 672, size),
      _scale(608, 1480, size),
      roadPaint,
    );
    canvas.drawLine(
      _scale(224, 624, size),
      _scale(1720, 624, size),
      roadPaint,
    );
    canvas.drawLine(
      _scale(224, 1104, size),
      _scale(1720, 1104, size),
      roadPaint,
    );

    if (mossBloomed) {
      canvas.drawCircle(
        _scale(208, 240, size),
        3.5,
        Paint()..color = const Color(0xFF4FE39B),
      );
    }

    // Barnaby Bittershell's secret dorsal subwoofer peace-sign bloom markers!
    if (showPeaceMarkers) {
      final center = _scale(608, 520, size);
      final peacePaint = Paint()
        ..color = const Color(0x99FFB703)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(center, 9, peacePaint);
      canvas.drawLine(
        center + const Offset(0, -9),
        center + const Offset(0, 9),
        peacePaint,
      );
    }

    // Stage dots (pulsing amber when live!)
    for (final s in stages) {
      if (s.id == 'pa_global_horn') continue;
      final pt = _scale(s.x as double, s.y as double, size);
      final isLive = activeStageIds.contains(s.id);
      if (isLive) {
        canvas.drawCircle(pt, 5.5, Paint()..color = const Color(0x66FFBE0B));
      }
      canvas.drawCircle(
        pt,
        2.5,
        Paint()
          ..color = isLive ? const Color(0xFFFFBE0B) : const Color(0xFF8ECAE6),
      );
    }

    // Day 2 Creekside Electric Purple Blueberries beacon near Willow Creek & Meadow Stage
    if (showDay2BlueberryShare) {
      final berryPt = _scale(1096, 496, size);
      canvas.drawCircle(berryPt, 5.2, Paint()..color = const Color(0x669D4EDD));
      canvas.drawCircle(berryPt, 2.4, Paint()..color = const Color(0xFFE0AAFF));
    }

    // Pinned Quest Objective Beacon (golden compass diamond + outer halo!)
    if (questTarget != null) {
      final qPt = _scale(questTarget!.dx, questTarget!.dy, size);
      canvas.drawCircle(qPt, 6.2, Paint()..color = const Color(0x55FFD166));
      final diamond = Path()
        ..moveTo(qPt.dx, qPt.dy - 4.5)
        ..lineTo(qPt.dx + 4.5, qPt.dy)
        ..lineTo(qPt.dx, qPt.dy + 4.5)
        ..lineTo(qPt.dx - 4.5, qPt.dy)
        ..close();
      canvas.drawPath(diamond, Paint()..color = const Color(0xFFFFD166));
      canvas.drawPath(
        diamond,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = const Color(0xFF1B120B),
      );
    }

    // Player walnut beacon
    final pPt = _scale(playerX, playerY, size);
    canvas.drawCircle(pPt, 3.8, Paint()..color = const Color(0xFFFF595E));
    canvas.drawCircle(
      pPt,
      3.8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.playerX != playerX ||
      old.playerY != playerY ||
      old.showPeaceMarkers != showPeaceMarkers ||
      old.mossBloomed != mossBloomed ||
      old.showDay2BlueberryShare != showDay2BlueberryShare ||
      old.questTarget != questTarget ||
      !setEquals(old.activeStageIds, activeStageIds);
}
