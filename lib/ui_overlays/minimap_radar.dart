import 'package:flutter/foundation.dart' show setEquals;
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../game/world/orchard_gate_component.dart';
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

/// Interactive 1969 Folded Program Orchard Map used inside `PocketProgramSheet`.
class OrchardProgramMapView extends ConsumerWidget {
  const OrchardProgramMapView({
    super.key,
    required this.playerX,
    required this.playerY,
    required this.onSelectWorldPoint,
  });

  final double playerX;
  final double playerY;
  final void Function(double worldX, double worldY) onSelectWorldPoint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clock = ref.watch(festivalClockProvider);
    final flags = ref.watch(worldFlagsProvider);
    final journal = ref.watch(journalStateProvider);
    final profile = ref.watch(playerProfileProvider);
    final data = ref.watch(festivalDataProvider);

    final activeStageIds = data.setlist
        .activeTracksAt(clock.day, clock.minuteOfDay)
        .map((t) => t.stageId)
        .toSet();
    final questTarget = MinimapRadarWidget.resolveQuestTarget(
      data,
      journal,
      flags,
    );

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return GestureDetector(
            key: const ValueKey('orchard_program_map_view'),
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              if (w <= 1 || h <= 1) return;
              final wx = (details.localPosition.dx / w).clamp(0.02, 0.98) *
                  _RadarPainter.worldW;
              final wy = (details.localPosition.dy / h).clamp(0.02, 0.98) *
                  _RadarPainter.worldH;
              onSelectWorldPoint(wx, wy);
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF172318),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFD49A5A),
                  width: 1.8,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: CustomPaint(
                painter: _ProgramMapPainter(
                  playerX: playerX,
                  playerY: playerY,
                  activeStageIds: activeStageIds,
                  stages: data.setlist.stages.values.toList(growable: false),
                  discoveredCultivars: profile.discoveredCultivarIds,
                  questTarget: questTarget,
                  showDay2BlueberryShare: clock.isDay2BlueberrySharingActive,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProgramMapPainter extends CustomPainter {
  const _ProgramMapPainter({
    required this.playerX,
    required this.playerY,
    required this.activeStageIds,
    required this.stages,
    required this.discoveredCultivars,
    required this.questTarget,
    required this.showDay2BlueberryShare,
  });

  static const double _worldW = 2048.0;
  static const double _worldH = 1536.0;

  final double playerX;
  final double playerY;
  final Set<String> activeStageIds;
  final List<StageInfo> stages;
  final Set<String> discoveredCultivars;
  final Offset? questTarget;
  final bool showDay2BlueberryShare;

  Offset _pt(double wx, double wy, Size size) => Offset(
        (wx / _worldW).clamp(0.0, 1.0) * size.width,
        (wy / _worldH).clamp(0.0, 1.0) * size.height,
      );

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Screen-printed parchment-on-forest grid lines
    final gridPaint = Paint()
      ..color = const Color(0x2295D5B2)
      ..strokeWidth = 1.0;
    for (var i = 1; i < 4; i++) {
      final gx = size.width * (i / 4);
      final gy = size.height * (i / 4);
      canvas.drawLine(Offset(gx, 0), Offset(gx, size.height), gridPaint);
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), gridPaint);
    }

    // 2. Main orchard dirt lanes & Willow Creek ribbon
    final creekPath = Path()
      ..moveTo(_pt(960, 0, size).dx, _pt(960, 0, size).dy)
      ..quadraticBezierTo(
        _pt(1180, 520, size).dx,
        _pt(1180, 520, size).dy,
        _pt(1390, 1536, size).dx,
        _pt(1390, 1536, size).dy,
      );
    canvas.drawPath(
      creekPath,
      Paint()
        ..color = const Color(0x5548CAE4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5,
    );

    final roadPaint = Paint()
      ..color = const Color(0x99A47551)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(_pt(608, 410, size), _pt(608, 1490, size), roadPaint);
    canvas.drawLine(_pt(180, 624, size), _pt(1820, 624, size), roadPaint);
    canvas.drawLine(_pt(180, 1104, size), _pt(1820, 1104, size), roadPaint);

    // 3. Orchard Gate Arch marker at (608, 1296)
    final gatePt = _pt(608, 1296, size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: gatePt, width: 22, height: 8),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFD49A5A),
    );
    _drawLabel(
      canvas,
      'ORCHARD GATE',
      gatePt + const Offset(0, 11),
      const Color(0xFFFFD166),
      fontSize: 8.5,
    );

    // 4. 11 Heritage Walnut Cultivar spots
    for (final spot in OrchardGateLayout.heritageCultivarSpots) {
      final cPt = _pt(spot.x, spot.y, size);
      final found = discoveredCultivars.contains(spot.cultivarId);
      if (found) {
        canvas.drawCircle(cPt, 4.4, Paint()..color = const Color(0xFFE9C46A));
        canvas.drawCircle(
          cPt,
          4.4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = const Color(0xFF2B180B),
        );
      } else {
        canvas.drawCircle(
          cPt,
          3.8,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3
            ..color = const Color(0xAAFFF3B0),
        );
      }
    }

    // 5. Concert Stages
    for (final s in stages) {
      if (s.id == 'pa_global_horn') continue;
      final pt = _pt(s.x, s.y, size);
      final isLive = activeStageIds.contains(s.id);
      if (isLive) {
        canvas.drawCircle(pt, 10.5, Paint()..color = const Color(0x55FFBE0B));
      }
      canvas.drawCircle(
        pt,
        5.0,
        Paint()
          ..color = isLive ? const Color(0xFFFFBE0B) : const Color(0xFF74C69D),
      );
      canvas.drawCircle(
        pt,
        5.0,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF141E15),
      );
      final shortName = s.name
          .replaceAll(' Stage', '')
          .replaceAll('The ', '')
          .trim();
      _drawLabel(
        canvas,
        isLive ? '♪ $shortName' : shortName,
        pt + const Offset(0, -10.5),
        isLive ? const Color(0xFFFFEA85) : const Color(0xFFD8F3DC),
        fontSize: 8.5,
      );
    }

    if (showDay2BlueberryShare) {
      final berryPt = _pt(1096, 496, size);
      canvas.drawCircle(berryPt, 7.0, Paint()..color = const Color(0x669D4EDD));
      canvas.drawCircle(berryPt, 3.6, Paint()..color = const Color(0xFFE0AAFF));
    }

    // 6. Tracked Quest Diamond
    if (questTarget != null) {
      final qPt = _pt(questTarget!.dx, questTarget!.dy, size);
      final diamond = Path()
        ..moveTo(qPt.dx, qPt.dy - 6.0)
        ..lineTo(qPt.dx + 6.0, qPt.dy)
        ..lineTo(qPt.dx, qPt.dy + 6.0)
        ..lineTo(qPt.dx - 6.0, qPt.dy)
        ..close();
      canvas.drawPath(diamond, Paint()..color = const Color(0xFFFFD166));
      canvas.drawPath(
        diamond,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF1B120B),
      );
    }

    // 7. Player Marker ("YOU")
    final pPt = _pt(playerX, playerY, size);
    canvas.drawCircle(pPt, 8.5, Paint()..color = const Color(0x55FF595E));
    canvas.drawCircle(pPt, 5.0, Paint()..color = const Color(0xFFFF595E));
    canvas.drawCircle(
      pPt,
      5.0,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white,
    );
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset center,
    Color color, {
    double fontSize = 8.5,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          shadows: const [
            Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 112);
    tp.paint(canvas, center - Offset(tp.width * 0.5, tp.height * 0.5));
  }

  @override
  bool shouldRepaint(covariant _ProgramMapPainter old) =>
      old.playerX != playerX ||
      old.playerY != playerY ||
      old.questTarget != questTarget ||
      old.showDay2BlueberryShare != showDay2BlueberryShare ||
      !setEquals(old.activeStageIds, activeStageIds) ||
      !setEquals(old.discoveredCultivars, discoveredCultivars);
}
