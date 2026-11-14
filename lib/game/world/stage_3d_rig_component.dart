import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/models.dart';
import 'concert_light_show.dart';
import 'day_night_atmosphere.dart';

/// Snapshot of which stages currently have active sets for 3D stage lighting & signage.
class LiveStageVisualState {
  const LiveStageVisualState({
    required this.stageId,
    required this.track,
    required this.primaryColor,
    required this.secondaryColor,
    required this.show,
    this.soloFocusPos,
  });

  final String stageId;
  final ScheduledTrack track;
  final Color primaryColor;
  final Color secondaryColor;
  final StageShowFrame show;
  final Offset? soloFocusPos;
}

/// Renders 2.5D/3D stage deck fascia, steps, rugs, amps, crystal dais, and liquid-light floor gobos beneath actors.
class StageDeckRiserComponent extends Component {
  StageDeckRiserComponent({
    required this.liveStagesGetter,
    required this.cameraCenterGetter,
    required this.timeGetter,
    required this.bassGetter,
    this.viewBoundsGetter,
    super.priority = -4400,
  });

  final Map<String, LiveStageVisualState> Function() liveStagesGetter;
  final Offset Function() cameraCenterGetter;
  final double Function() timeGetter;
  final double Function() bassGetter;
  final Rect Function()? viewBoundsGetter;

  @override
  void render(Canvas canvas) {
    final cam = cameraCenterGetter();
    final view = viewBoundsGetter?.call().inflate(120.0) ??
        Rect.fromCenter(center: cam, width: 780, height: 740);
    final t = timeGetter();
    final bass = bassGetter();
    final live = liveStagesGetter();

    // 1. Main Roots Stage (480..736, 336..448)
    if (view.overlaps(const Rect.fromLTWH(468, 330, 280, 140))) {
      _drawMainRootsDeck(canvas, t, bass, live['main_roots_stage']);
    }

    // 2. High-Branch PA Booth (752..816, 320..400)
    if (view.overlaps(const Rect.fromLTWH(744, 316, 80, 108))) {
      _drawPaBoothPlatform(canvas, live['pa_global_horn']);
    }

    // 3. Velvet Canopy Stage (128..304, 320..400)
    if (view.overlaps(const Rect.fromLTWH(120, 316, 196, 104))) {
      _drawVelvetCanopyDeck(canvas, t, bass, live['velvet_canopy_stage']);
    }

    // 4. Mellow Meadow Acoustic Blanket (1096..1204, 408..448)
    if (view.overlaps(const Rect.fromLTWH(1090, 402, 124, 56))) {
      _drawMeadowAcousticRug(canvas, t, live['mellow_meadow_stage']);
    }

    // 5. Andromeda Geodesic Crystal Dais (1616..1904, 272..496)
    if (view.overlaps(const Rect.fromLTWH(1620, 260, 280, 230))) {
      _drawAndromedaCrystalDais(
          canvas, t, bass, live['andromeda_pavilion_stage']);
    }

    // 6. Urbano 1969 Produce-Truck Flatbed Stage (128..320, 976..1036)
    if (view.overlaps(const Rect.fromLTWH(124, 970, 204, 76))) {
      _drawUrbanoFlatbedDeck(canvas, t, bass, live['urbano_canopy_stage']);
    }

    // 7. Sorting Machine Arcade Stage Riser (1712..1780, 976..1024)
    if (view.overlaps(const Rect.fromLTWH(1706, 970, 82, 62))) {
      _drawSortingArcadeDeck(canvas, t, bass, live['sorting_arcade_stage']);
    }
  }

  void _drawMainRootsDeck(
    Canvas canvas,
    double t,
    double bass,
    LiveStageVisualState? liveState,
  ) {
    final isLive = liveState != null;
    final show = liveState?.show;
    // Ground contact shadow beneath 3D wooden stage riser
    canvas.drawRect(
      const Rect.fromLTWH(482, 452, 254, 7),
      Paint()..color = const Color(0x55090E0B),
    );
    // 3D vertical mahogany front riser cliff
    canvas.drawRect(
      const Rect.fromLTWH(480, 444, 256, 10),
      Paint()..color = const Color(0xFF432818),
    );
    canvas.drawRect(
      const Rect.fromLTWH(480, 443, 256, 2),
      Paint()..color = const Color(0xFFBB9457),
    );
    for (var x = 488.0; x < 732.0; x += 16.0) {
      canvas.drawRect(
        Rect.fromLTWH(x, 445, 2, 8),
        Paint()..color = const Color(0xFF2B180E),
      );
    }

    // Center 3D timber front steps
    for (var step = 0; step < 3; step++) {
      final sy = 445.0 + step * 4.0;
      final sw = 38.0 - step * 3.0;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(608, sy + 2), width: sw, height: 3.5),
        Paint()
          ..color = step.isEven
              ? const Color(0xFF7F5539)
              : const Color(0xFF583101),
      );
    }

    // Beat-chasing brass footlight shells along stage front apron!
    var idx = 0;
    for (var fx = 504.0; fx <= 712.0; fx += 34.0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(fx, 442), width: 7, height: 4),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF2D231E),
      );
      Color bulbCol = const Color(0xFF9C7A3C);
      var bulbR = 1.7;
      if (liveState != null && show != null) {
        final activeChase = (idx + show.beatIndex) % 2 == 0 ||
            show.blinderBurst > 0.25 ||
            show.sectionMode == LightShowSectionMode.climaxPrism;
        final baseC =
            idx.isEven ? liveState.primaryColor : liveState.secondaryColor;
        bulbCol = activeChase
            ? Color.lerp(baseC, const Color(0xFFFFFFFF),
                (show.beatPulse * 0.45 + show.blinderBurst * 0.55).clamp(0.0, 1.0))!
            : baseC.withValues(alpha: 0.45);
        bulbR = activeChase ? (2.1 + show.beatPulse * 0.8) : 1.5;
      }
      canvas.drawCircle(Offset(fx, 441.5), bulbR, Paint()..color = bulbCol);
      idx++;
    }

    // Woven 1969 Woodstock mandala rug under lead center mic (608, 382)
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(608, 384), width: 66, height: 32),
      Paint()..color = const Color(0xFF6F1D1B),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(608, 384), width: 52, height: 24),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFFE9C46A),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(608, 384), width: 32, height: 14),
      Paint()..color = const Color(0xFF2A9D8F),
    );

    // 3D drum riser platform at rear-center (608, 354)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(584, 344, 48, 22),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF3B2314),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(584, 341, 48, 20),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF6C462C),
    );

    // Dual 3D vintage tube-amp stacks on left & right wings (cones excursion-locked to scanned bass!)
    final effBass = show != null ? show.bass : bass;
    final conePulse = isLive ? (effBass * 1.35 + (show?.beatPulse ?? 0.0) * 0.45) : 0.0;
    for (final ax in const [518.0, 698.0]) {
      canvas.drawRect(
        Rect.fromLTWH(ax - 11, 344, 22, 24),
        Paint()..color = const Color(0xFF1B1918),
      );
      canvas.drawRect(
        Rect.fromLTWH(ax - 11, 341, 22, 4),
        Paint()..color = const Color(0xFFD4A373),
      );
      canvas.drawRect(
        Rect.fromLTWH(ax - 9, 347, 18, 18),
        Paint()..color = const Color(0xFF332E2C),
      );
      for (final cx in [ax - 4.5, ax + 4.5]) {
        for (final cy in [351.5, 360.0]) {
          canvas.drawCircle(
            Offset(cx, cy),
            3.2 + conePulse * 0.55,
            Paint()..color = const Color(0xFF8D8278),
          );
          canvas.drawCircle(
            Offset(cx, cy),
            1.3,
            Paint()..color = const Color(0xFFD9C5A0),
          );
        }
      }
    }

    // Projected 1969 liquid-light stage gobo mandala & sub-bass shockwave rings!
    if (liveState != null && show != null) {
      renderStageFloorLightShow(
        canvas: canvas,
        center: const Offset(608, 382),
        radiusX: 78.0,
        radiusY: 32.0,
        show: show,
        primaryColor: liveState.primaryColor,
        secondaryColor: liveState.secondaryColor,
        soloFocusPos: liveState.soloFocusPos,
      );
    }
  }

  void _drawPaBoothPlatform(Canvas canvas, LiveStageVisualState? liveState) {
    canvas.drawRect(
      const Rect.fromLTWH(754, 400, 60, 12),
      Paint()..color = const Color(0x55080D0A),
    );
    for (final sx in const [758.0, 782.0, 806.0]) {
      canvas.drawRect(
        Rect.fromLTWH(sx, 396, 5, 16),
        Paint()..color = const Color(0xFF4A2C18),
      );
    }
    canvas.drawRect(
      const Rect.fromLTWH(752, 396, 64, 5),
      Paint()..color = const Color(0xFF6F4518),
    );
    canvas.drawRect(
      const Rect.fromLTWH(752, 395, 64, 1.5),
      Paint()..color = const Color(0xFFD4A373),
    );
    if (liveState != null) {
      final v = (liveState.show.mid * 0.45 + liveState.show.highMid * 0.55)
          .clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(776, 356), width: 32, height: 14),
        Paint()
          ..blendMode = BlendMode.plus
          ..color = Color.fromRGBO(255, 209, 102, 0.16 + v * 0.24),
      );
    }
  }

  void _drawVelvetCanopyDeck(
    Canvas canvas,
    double t,
    double bass,
    LiveStageVisualState? liveState,
  ) {
    canvas.drawRect(
      const Rect.fromLTWH(128, 398, 176, 8),
      Paint()..color = const Color(0xFF3B2416),
    );
    canvas.drawRect(
      const Rect.fromLTWH(128, 397, 176, 2),
      Paint()..color = const Color(0xFFC9A227),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(168, 344, 96, 44),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF641220),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(173, 348, 86, 36),
        const Radius.circular(3),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFFE09F3E),
    );
    canvas.drawRect(
      const Rect.fromLTWH(242, 342, 24, 16),
      Paint()..color = const Color(0xFF4E2A14),
    );
    canvas.drawRect(
      const Rect.fromLTWH(244, 347, 20, 4),
      Paint()..color = const Color(0xFFF8F9FA),
    );
    if (liveState != null) {
      final show = liveState.show;
      for (var i = 0; i < 5; i++) {
        final fx = 152.0 + i * 32.0;
        final lit = (i + show.beatIndex) % 2 == 0 || show.blinderBurst > 0.2;
        canvas.drawCircle(
          Offset(fx, 396.5),
          lit ? 2.1 + show.beatPulse * 0.7 : 1.4,
          Paint()
            ..color = lit
                ? (i.isEven ? liveState.primaryColor : liveState.secondaryColor)
                : const Color(0x66C9A227),
        );
      }
      renderStageFloorLightShow(
        canvas: canvas,
        center: const Offset(216, 366),
        radiusX: 54.0,
        radiusY: 24.0,
        show: show,
        primaryColor: liveState.primaryColor,
        secondaryColor: liveState.secondaryColor,
        soloFocusPos: liveState.soloFocusPos,
      );
    }
  }

  void _drawMeadowAcousticRug(
    Canvas canvas,
    double t,
    LiveStageVisualState? liveState,
  ) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1102, 416, 98, 30),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF3A5A40),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1106, 419, 90, 24),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFBC4749),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1112, 422, 78, 18),
        const Radius.circular(3),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFFF2E8CF),
    );
    if (liveState != null) {
      renderStageFloorLightShow(
        canvas: canvas,
        center: const Offset(1151, 431),
        radiusX: 46.0,
        radiusY: 16.0,
        show: liveState.show,
        primaryColor: liveState.primaryColor,
        secondaryColor: liveState.secondaryColor,
        soloFocusPos: liveState.soloFocusPos,
      );
    }
  }

  void _drawAndromedaCrystalDais(
    Canvas canvas,
    double t,
    double bass,
    LiveStageVisualState? liveState,
  ) {
    const center = Offset(1760, 346);
    final show = liveState?.show;
    final pulse = show != null
        ? (0.55 + 0.45 * show.bass + 0.25 * show.beatPulse).clamp(0.0, 1.0)
        : (0.35 + 0.15 * math.sin(t * 2.0));
    final rotBase = show != null ? show.trackTimeSec * 0.45 : t * 0.10;
    for (var ring = 3; ring >= 1; ring--) {
      final r = ring * 18.0 + (show != null ? show.beatPulse * 2.5 : 0.0);
      final path = Path();
      for (var i = 0; i < 8; i++) {
        final ang =
            i * math.pi / 4.0 + (ring.isEven ? rotBase : -rotBase * 0.8);
        final pt = Offset(
          center.dx + math.cos(ang) * r,
          center.dy + math.sin(ang) * r * 0.68,
        );
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring == 1 ? 1.9 : 1.2
          ..color = Color.lerp(
            const Color(0xFF48CAE4),
            const Color(0xFFC77DFF),
            ring / 3.0,
          )!
              .withValues(alpha: (0.32 + 0.48 * pulse).clamp(0.0, 0.92)),
      );
    }
    if (liveState != null && show != null) {
      renderStageFloorLightShow(
        canvas: canvas,
        center: center,
        radiusX: 58.0,
        radiusY: 36.0,
        show: show,
        primaryColor: liveState.primaryColor,
        secondaryColor: liveState.secondaryColor,
        soloFocusPos: liveState.soloFocusPos,
      );
    }
  }

  void _drawUrbanoFlatbedDeck(
    Canvas canvas,
    double t,
    double bass,
    LiveStageVisualState? liveState,
  ) {
    canvas.drawRect(
      const Rect.fromLTWH(172, 1029, 112, 6),
      Paint()..color = const Color(0xFF241710),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(170, 1005, 116, 25),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF5C3A21),
    );
    canvas.drawRect(
      const Rect.fromLTWH(172, 1027, 112, 2.5),
      Paint()..color = const Color(0xFFFFD166),
    );
    canvas.drawRect(
      const Rect.fromLTWH(172, 1006, 112, 2.0),
      Paint()..color = const Color(0xFFE63946),
    );
    if (liveState != null) {
      final show = liveState.show;
      final r = 7.0 + show.bass * 11.0 + show.beatPhase * 9.0;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.35
        ..color = Color.fromRGBO(
          255,
          209,
          102,
          (0.68 - show.beatPhase * 0.45).clamp(0.12, 0.68),
        );
      canvas.drawCircle(const Offset(144, 1008), r * 0.62, p);
      canvas.drawCircle(const Offset(304, 1008), r * 0.62, p);
      renderStageFloorLightShow(
        canvas: canvas,
        center: const Offset(228, 1017),
        radiusX: 52.0,
        radiusY: 14.0,
        show: show,
        primaryColor: liveState.primaryColor,
        secondaryColor: liveState.secondaryColor,
        soloFocusPos: liveState.soloFocusPos,
      );
    }
  }

  void _drawSortingArcadeDeck(
    Canvas canvas,
    double t,
    double bass,
    LiveStageVisualState? liveState,
  ) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1722, 984, 48, 34),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF2B2D42),
    );
    canvas.drawRect(
      const Rect.fromLTWH(1722, 1015, 48, 5),
      Paint()..color = const Color(0xFF141622),
    );
    final show = liveState?.show;
    final trimCol = show != null
        ? Color.lerp(
            liveState!.primaryColor,
            liveState.secondaryColor,
            show.barBeat.isEven ? show.beatPulse : (1.0 - show.beatPulse),
          )!
        : const Color(0xFF8D99AE);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1724, 986, 44, 29),
        const Radius.circular(2),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = show != null ? 1.6 + show.beatPulse * 0.6 : 1.4
        ..color = trimCol,
    );
    if (liveState != null && show != null) {
      renderStageFloorLightShow(
        canvas: canvas,
        center: const Offset(1746, 1000),
        radiusX: 26.0,
        radiusY: 16.0,
        show: show,
        primaryColor: liveState.primaryColor,
        secondaryColor: liveState.secondaryColor,
        soloFocusPos: liveState.soloFocusPos,
      );
    }
  }
}

/// Renders elevated 3D proscenium arches, concert lighting trusses, geodesic dome struts,
/// 1969 truck roof/headlights, and sweeping volumetric spotlight cones with 2.5D parallax.
class StageOverheadTrussComponent extends Component {
  StageOverheadTrussComponent({
    required this.liveStagesGetter,
    required this.metricsGetter,
    required this.cameraCenterGetter,
    required this.timeGetter,
    required this.bassGetter,
    required this.midGetter,
    this.viewBoundsGetter,
    super.priority = 6300,
  });

  final Map<String, LiveStageVisualState> Function() liveStagesGetter;
  final DayNightMetrics Function() metricsGetter;
  final Offset Function() cameraCenterGetter;
  final double Function() timeGetter;
  final double Function() bassGetter;
  final double Function() midGetter;
  final Rect Function()? viewBoundsGetter;

  Offset _parallaxFor(Offset anchor, Offset cam, {double height = 0.032}) {
    return Offset(
      ((anchor.dx - cam.dx) * height).clamp(-10.0, 10.0),
      ((anchor.dy - cam.dy) * height).clamp(-8.0, 8.0),
    );
  }

  @override
  void render(Canvas canvas) {
    final cam = cameraCenterGetter();
    final view = viewBoundsGetter?.call().inflate(140.0) ??
        Rect.fromCenter(center: cam, width: 820, height: 760);
    final t = timeGetter();
    final bass = bassGetter();
    final mid = midGetter();
    final metrics = metricsGetter();
    final live = liveStagesGetter();

    // 1. Main Roots Proscenium Arch + Concert Lighting Truss
    if (view.overlaps(const Rect.fromLTWH(468, 300, 280, 160))) {
      final pOff = _parallaxFor(const Offset(608, 332), cam);
      _drawMainRootsOverhead(
        canvas,
        pOff,
        t,
        bass,
        mid,
        live['main_roots_stage'],
      );
    }

    // 2. High-Branch PA Booth Gable Roof & Brass Megaphone Horns
    if (view.overlaps(const Rect.fromLTWH(740, 300, 92, 110))) {
      final pOff = _parallaxFor(const Offset(784, 330), cam);
      _drawPaBoothOverhead(canvas, pOff, t, live['pa_global_horn']);
    }

    // 3. Velvet Canopy Swag Valence & Amethyst Tassels
    if (view.overlaps(const Rect.fromLTWH(120, 296, 196, 115))) {
      final pOff = _parallaxFor(const Offset(216, 320), cam);
      _drawVelvetCanopyOverhead(
          canvas, pOff, t, bass, live['velvet_canopy_stage']);
    }

    // 4. Mellow Meadow Bent-Willow Floral Arch & Mason-Jar Lights
    if (view.overlaps(const Rect.fromLTWH(1090, 384, 124, 72))) {
      final pOff = _parallaxFor(const Offset(1150, 404), cam, height: 0.022);
      _drawMeadowArchOverhead(
          canvas, pOff, t, metrics, live['mellow_meadow_stage']);
    }

    // 5. Andromeda 3D Projected Geodesic Crystal Dome Hemisphere
    if (view.overlaps(const Rect.fromLTWH(1600, 220, 320, 290))) {
      final pOff = _parallaxFor(const Offset(1760, 360), cam, height: 0.055);
      _drawAndromedaGeodesicDome(
        canvas,
        pOff,
        t,
        bass,
        live['andromeda_pavilion_stage'],
      );
    }

    // 6. Urbano 1969 Produce-Truck 3D Cab, Canopy Awning & Night Headlights
    if (view.overlaps(const Rect.fromLTWH(130, 946, 200, 110))) {
      final pOff = _parallaxFor(const Offset(224, 984), cam, height: 0.028);
      _drawUrbanoTruckOverhead(
        canvas,
        pOff,
        t,
        bass,
        metrics,
        live['urbano_canopy_stage'],
      );
    }

    // 7. Sorting Machine Arcade Chasing-Bulb Marquee Arch
    if (view.overlaps(const Rect.fromLTWH(1704, 944, 88, 90))) {
      final pOff = _parallaxFor(const Offset(1746, 968), cam, height: 0.026);
      _drawSortingArcadeMarquee(
        canvas,
        pOff,
        t,
        bass,
        metrics,
        live['sorting_arcade_stage'],
      );
    }
  }

  void _drawSpotlightCone(
    Canvas canvas, {
    required Offset origin,
    required Offset target,
    required double targetHalfWidth,
    required Color color,
    required double alpha,
  }) {
    final path = Path()
      ..moveTo(origin.dx - 2.5, origin.dy)
      ..lineTo(origin.dx + 2.5, origin.dy)
      ..lineTo(target.dx + targetHalfWidth, target.dy)
      ..lineTo(target.dx - targetHalfWidth, target.dy)
      ..close();
    final grad = Gradient.linear(
      origin,
      target,
      <Color>[
        color.withValues(alpha: (alpha * 1.15).clamp(0.0, 0.52)),
        color.withValues(alpha: (alpha * 0.42).clamp(0.0, 0.24)),
        color.withValues(alpha: 0.0),
      ],
      const <double>[0.0, 0.65, 1.0],
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = grad
        ..blendMode = BlendMode.plus,
    );
  }

  void _drawMainRootsOverhead(
    Canvas canvas,
    Offset pOff,
    double t,
    double bass,
    double mid,
    LiveStageVisualState? liveState,
  ) {
    const canXs = <double>[516.0, 546.0, 577.0, 608.0, 639.0, 670.0, 700.0];
    canvas.save();
    canvas.translate(pOff.dx, pOff.dy);

    // Sculpted 3D overarching living walnut-root proscenium arch
    final archPath = Path()
      ..moveTo(486, 340)
      ..quadraticBezierTo(608, 304, 730, 340)
      ..lineTo(724, 346)
      ..quadraticBezierTo(608, 314, 492, 346)
      ..close();
    canvas.drawPath(archPath, Paint()..color = const Color(0xFF4A2C18));
    canvas.drawPath(
      archPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF9C6644),
    );

    // Steel concert truss bar & 7 PAR spotlight cans
    canvas.drawLine(
      const Offset(502, 330),
      const Offset(714, 330),
      Paint()
        ..color = const Color(0xFF343A40)
        ..strokeWidth = 3.2,
    );
    for (final lx in canXs) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(lx, 332), width: 6, height: 5),
        Paint()..color = const Color(0xFF212529),
      );
    }
    canvas.restore();

    // Scanned music-synced 7-fixture concert light show when Main Roots Stage is LIVE!
    if (liveState != null) {
      renderConcertOverheadLightShow(
        canvas: canvas,
        fixtureOrigins: [
          for (final lx in canXs) Offset(lx + pOff.dx, 334 + pOff.dy),
        ],
        stageDeckCenter: const Offset(608, 384),
        deckWidth: 236.0,
        show: liveState.show,
        primaryColor: liveState.primaryColor,
        secondaryColor: liveState.secondaryColor,
        soloFocusPos: liveState.soloFocusPos,
      );
    }
  }

  void _drawPaBoothOverhead(
    Canvas canvas,
    Offset pOff,
    double t,
    LiveStageVisualState? liveState,
  ) {
    canvas.save();
    canvas.translate(pOff.dx, pOff.dy);
    // 3D cedar gable roof peak over High-Branch PA Booth
    final roof = Path()
      ..moveTo(748, 328)
      ..lineTo(784, 308)
      ..lineTo(820, 328)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFF582F0E));
    canvas.drawPath(
      roof,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFFB08968),
    );

    // Dual flared 3D brass PA megaphone horns
    for (final side in const [-1.0, 1.0]) {
      final hx = 784.0 + side * 26.0;
      final horn = Path()
        ..moveTo(hx - side * 4, 325)
        ..lineTo(hx + side * 9, 319)
        ..lineTo(hx + side * 9, 331)
        ..close();
      canvas.drawPath(horn, Paint()..color = const Color(0xFFE9C46A));
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(hx + side * 9, 325), width: 3.5, height: 11),
        Paint()..color = const Color(0xFF9C6644),
      );
    }
    canvas.restore();

    // Syllable-synced acoustic soundwaves & warm booth spot during Patchouli Pete PA broadcasts!
    if (liveState != null) {
      final show = liveState.show;
      final syllable = (show.mid * 0.45 + show.highMid * 0.55).clamp(0.0, 1.0);
      _drawSpotlightCone(
        canvas,
        origin: Offset(784 + pOff.dx, 326 + pOff.dy),
        target: const Offset(776, 348),
        targetHalfWidth: 16.0 + syllable * 6.0,
        color: const Color(0xFFFFE599),
        alpha: 0.16 + syllable * 0.22,
      );
      for (var i = 0; i < 3; i++) {
        final prog = ((show.trackTimeSec * 1.65 + i * 0.33) % 1.0);
        final r = 8.0 + prog * (26.0 + syllable * 18.0);
        final a = ((1.0 - prog) * (0.24 + syllable * 0.58 + show.accentFlash * 0.2))
            .clamp(0.0, 0.85);
        final wavePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1 + syllable * 0.85
          ..color = Color.fromRGBO(255, 214, 102, a);
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(752 + pOff.dx, 326 + pOff.dy),
              width: r,
              height: r),
          math.pi * 0.65,
          math.pi * 0.7,
          false,
          wavePaint,
        );
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(816 + pOff.dx, 326 + pOff.dy),
              width: r,
              height: r),
          -math.pi * 0.35,
          math.pi * 0.7,
          false,
          wavePaint,
        );
      }
    }
  }

  void _drawVelvetCanopyOverhead(
    Canvas canvas,
    Offset pOff,
    double t,
    double bass,
    LiveStageVisualState? liveState,
  ) {
    const canXs = <double>[152.0, 184.0, 216.0, 248.0, 280.0];
    canvas.save();
    canvas.translate(pOff.dx, pOff.dy);
    // Billowing 3D crushed-burgundy velvet valence scallops + gold tassels
    for (var sx = 132.0; sx < 296.0; sx += 28.0) {
      canvas.drawArc(
        Rect.fromLTWH(sx, 308, 28, 18),
        0,
        math.pi,
        true,
        Paint()..color = const Color(0xFF800F2F),
      );
      canvas.drawArc(
        Rect.fromLTWH(sx, 308, 28, 18),
        0,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = const Color(0xFFFFB703),
      );
      canvas.drawCircle(
        Offset(sx + 14, 327),
        2.0,
        Paint()..color = const Color(0xFFFF70A6),
      );
    }
    canvas.restore();

    if (liveState != null) {
      renderConcertOverheadLightShow(
        canvas: canvas,
        fixtureOrigins: [
          for (final lx in canXs) Offset(lx + pOff.dx, 324 + pOff.dy),
        ],
        stageDeckCenter: const Offset(216, 366),
        deckWidth: 156.0,
        show: liveState.show,
        primaryColor: liveState.primaryColor,
        secondaryColor: liveState.secondaryColor,
        soloFocusPos: liveState.soloFocusPos,
      );
    }
  }

  void _drawMeadowArchOverhead(
    Canvas canvas,
    Offset pOff,
    double t,
    DayNightMetrics metrics,
    LiveStageVisualState? liveState,
  ) {
    final show = liveState?.show;
    canvas.save();
    canvas.translate(pOff.dx, pOff.dy);
    final arch = Path()
      ..moveTo(1106, 420)
      ..quadraticBezierTo(1150, 390, 1194, 420);
    canvas.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..color = const Color(0xFF606C38),
    );
    // Hanging warm mason-jar string bulbs (beat-chasing when live!)
    final lit = liveState != null || metrics.lanternGlowStrength > 0.1;
    for (var i = 0; i <= 6; i++) {
      final u = i / 6.0;
      final bx = 1108.0 + u * 84.0;
      final by = 418.0 - math.sin(u * math.pi) * 14.0;
      final beatChase = show != null && ((i + show.beatIndex) % 2 == 0);
      final r = show != null
          ? (beatChase ? 2.4 + show.beatPulse * 0.9 : 1.7)
          : (lit ? 2.1 : 1.5);
      final col = show != null
          ? (beatChase ? liveState!.primaryColor : liveState!.secondaryColor)
          : (lit ? const Color(0xFFFFE169) : const Color(0xFFD4A373));
      canvas.drawCircle(Offset(bx, by), r, Paint()..color = col);
    }
    canvas.restore();

    if (liveState != null && show != null) {
      renderConcertOverheadLightShow(
        canvas: canvas,
        fixtureOrigins: [
          Offset(1120 + pOff.dx, 412 + pOff.dy),
          Offset(1150 + pOff.dx, 404 + pOff.dy),
          Offset(1180 + pOff.dx, 412 + pOff.dy),
        ],
        stageDeckCenter: const Offset(1150, 434),
        deckWidth: 96.0,
        show: show,
        primaryColor: liveState.primaryColor,
        secondaryColor: liveState.secondaryColor,
        soloFocusPos: liveState.soloFocusPos,
      );
    }
  }

  void _drawAndromedaGeodesicDome(
    Canvas canvas,
    Offset pOff,
    double t,
    double bass,
    LiveStageVisualState? liveState,
  ) {
    final show = liveState?.show;
    const baseCenter = Offset(1760, 366);
    const rx = 128.0;
    const ry = 88.0;
    final apex = Offset(
        baseCenter.dx + pOff.dx * 1.4, baseCenter.dy - 44.0 + pOff.dy * 1.4);

    final strutAlpha = show != null
        ? (0.38 + show.bass * 0.24 + show.beatPulse * 0.20 + show.blinderBurst * 0.2)
        : 0.26;
    final baseStrutColor = show != null &&
            (show.sectionMode == LightShowSectionMode.climaxPrism ||
                show.sectionMode == LightShowSectionMode.chorusAnthemy)
        ? Color.lerp(
            liveState!.primaryColor,
            liveState.secondaryColor,
            0.5 + 0.5 * math.sin(show.trackTimeSec * 3.0),
          )!
        : const Color(0xFF72EFDD);
    final strutPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = show != null ? 1.15 + show.beatPulse * 0.55 : 1.15
      ..color = baseStrutColor.withValues(alpha: strutAlpha.clamp(0.0, 0.82));

    // True 3D geodesic meridian ribs converging from ground perimeter to parallax-shifted apex!
    const ribs = 10;
    final ringMid = <Offset>[];
    for (var i = 0; i < ribs; i++) {
      final ang = (i / ribs) * math.pi * 2.0 + t * 0.04;
      final rimPt = Offset(
        baseCenter.dx + math.cos(ang) * rx,
        baseCenter.dy + math.sin(ang) * ry,
      );
      final midPt = Offset(
        lerpDouble(rimPt.dx, apex.dx, 0.54)!,
        lerpDouble(rimPt.dy, apex.dy, 0.54)! - 10.0,
      );
      ringMid.add(midPt);
      final ribPath = Path()
        ..moveTo(rimPt.dx, rimPt.dy)
        ..quadraticBezierTo(midPt.dx, midPt.dy, apex.dx, apex.dy);
      canvas.drawPath(ribPath, strutPaint);
    }

    // Geodesic latitude triangulation ring
    for (var i = 0; i < ringMid.length; i++) {
      canvas.drawLine(
          ringMid[i], ringMid[(i + 1) % ringMid.length], strutPaint);
    }

    // Glowing apex star-crystal node
    canvas.drawCircle(
      apex,
      show != null
          ? 4.8 + show.bass * 2.8 + show.blinderBurst * 3.5
          : 3.5,
      Paint()
        ..color = show != null && show.blinderBurst > 0.2
            ? const Color(0xEEFFFFFF)
            : const Color(0xCC80FFDB),
    );

    if (liveState != null && show != null) {
      renderConcertOverheadLightShow(
        canvas: canvas,
        fixtureOrigins: [
          ringMid[1],
          ringMid[3],
          apex,
          ringMid[6],
          ringMid[8],
        ],
        stageDeckCenter: const Offset(1760, 346),
        deckWidth: 168.0,
        show: show,
        primaryColor: liveState.primaryColor,
        secondaryColor: liveState.secondaryColor,
        soloFocusPos: liveState.soloFocusPos,
      );
    }
  }

  void _drawUrbanoTruckOverhead(
    Canvas canvas,
    Offset pOff,
    double t,
    double bass,
    DayNightMetrics metrics,
    LiveStageVisualState? liveState,
  ) {
    final show = liveState?.show;
    canvas.save();
    canvas.translate(pOff.dx * 0.65, pOff.dy * 0.65);

    // 3D elevated 1969 scarlet-and-gold truck cab roof & striped Santurce stage awning
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(164, 974, 38, 22),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFD62828),
    );
    // Specular glass windshield
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(168, 988, 30, 6),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF90E0EF),
    );
    // Striped bodega canvas awning over flatbed stage
    for (var i = 0; i < 6; i++) {
      canvas.drawRect(
        Rect.fromLTWH(204.0 + i * 14.0, 976, 14, 14),
        Paint()
          ..color =
              i.isEven ? const Color(0xFFE63946) : const Color(0xFFFFD166),
      );
    }
    canvas.restore();

    // Twin warm 1969 truck headlight beams (beat-strobing on dem-bow kicks when LIVE!)
    if (liveState != null || metrics.lanternGlowStrength > 0.15) {
      final beamAlpha = show != null
          ? (0.20 + show.bass * 0.16 + show.beatPulse * 0.16)
          : 0.18;
      _drawSpotlightCone(
        canvas,
        origin: const Offset(172, 1002),
        target: const Offset(164, 1044),
        targetHalfWidth: show != null ? 15 + show.beatPulse * 5 : 16,
        color: const Color(0xFFFFE599),
        alpha: beamAlpha,
      );
      _drawSpotlightCone(
        canvas,
        origin: const Offset(194, 1002),
        target: const Offset(202, 1044),
        targetHalfWidth: show != null ? 15 + show.beatPulse * 5 : 16,
        color: const Color(0xFFFFE599),
        alpha: beamAlpha,
      );
    }
    if (liveState != null && show != null) {
      renderConcertOverheadLightShow(
        canvas: canvas,
        fixtureOrigins: [
          for (final lx in const [208.0, 232.0, 256.0, 280.0])
            Offset(lx + pOff.dx * 0.65, 988 + pOff.dy * 0.65),
        ],
        stageDeckCenter: const Offset(232, 1016),
        deckWidth: 104.0,
        show: show,
        primaryColor: liveState.primaryColor,
        secondaryColor: liveState.secondaryColor,
        soloFocusPos: liveState.soloFocusPos,
      );
    }
  }

  void _drawSortingArcadeMarquee(
    Canvas canvas,
    Offset pOff,
    double t,
    double bass,
    DayNightMetrics metrics,
    LiveStageVisualState? liveState,
  ) {
    final show = liveState?.show;
    canvas.save();
    canvas.translate(pOff.dx, pOff.dy);
    // 3D carnival arcade marquee header
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1716, 962, 60, 14),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF3A0CA3),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1716, 962, 60, 14),
        const Radius.circular(4),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFFFFBE0B),
    );
    final chaseIdx = show != null ? show.beatIndex : (t * 8.0).floor();
    for (var i = 0; i < 7; i++) {
      final activeBulb = (i + chaseIdx) % 2 == 0;
      canvas.drawCircle(
        Offset(1722.0 + i * 8.0, 969),
        activeBulb ? (show != null ? 1.9 + show.beatPulse * 0.6 : 1.8) : 1.2,
        Paint()
          ..color = activeBulb
              ? const Color(0xFFFFF3B0)
              : const Color(0xFF9D4EDD),
      );
    }
    canvas.restore();

    if (liveState != null && show != null) {
      renderConcertOverheadLightShow(
        canvas: canvas,
        fixtureOrigins: [
          Offset(1726 + pOff.dx, 974 + pOff.dy),
          Offset(1746 + pOff.dx, 974 + pOff.dy),
          Offset(1766 + pOff.dx, 974 + pOff.dy),
        ],
        stageDeckCenter: const Offset(1746, 1002),
        deckWidth: 54.0,
        show: show,
        primaryColor: liveState.primaryColor,
        secondaryColor: liveState.secondaryColor,
        soloFocusPos: liveState.soloFocusPos,
      );
    }
  }
}

/// Exact sub-pixel horizontal & baseline-anchored vertical layout for a floating world pill.
class CenteredPillLayout {
  const CenteredPillLayout({
    required this.pillRect,
    required this.paragraph,
    required this.paragraphTopLeft,
    required this.glyphWidth,
    required this.baselineY,
    required this.leadingIconLeftX,
  });

  final RRect pillRect;
  final Paragraph paragraph;
  final Offset paragraphTopLeft;
  final double glyphWidth;
  final double baselineY;
  final double leadingIconLeftX;
}

/// Computes a perfectly centered single-line pill rect and paragraph draw offset.
///
/// Anchors vertical alignment directly to [LineMetrics.baseline] (`center.dy + fontSize * 0.25 - line.baseline`)
/// so OS symbol/emoji fallback font ascents never push Latin artist names down toward the bottom border.
CenteredPillLayout computeCenteredWorldPill({
  required Offset center,
  required String text,
  required double fontSize,
  required Color textColor,
  FontWeight fontWeight = FontWeight.w700,
  double letterSpacing = 0.2,
  double horizontalPadding = 8.5,
  double pillHeight = 15.5,
  double minPillWidth = 44.0,
  double maxPillWidth = 310.0,
  double borderRadius = 7.5,
  double leadingIconSlotWidth = 0.0,
}) {
  final maxTextWidth = math.max(
    24.0,
    maxPillWidth - horizontalPadding * 2.0 - leadingIconSlotWidth,
  );
  final pb = ParagraphBuilder(
    ParagraphStyle(
      textAlign: TextAlign.left,
      maxLines: 1,
      ellipsis: '…',
      fontSize: fontSize,
      fontWeight: fontWeight,
    ),
  )
    ..pushStyle(
      TextStyle(
        color: textColor,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
      ),
    )
    ..addText(text);

  final paragraph = pb.build()
    ..layout(ParagraphConstraints(width: maxTextWidth));
  final lines = paragraph.computeLineMetrics();

  double glyphWidth;
  double lineLeft;
  double paraTopY;
  double baselineY;

  final targetBaselineY = center.dy + fontSize * 0.25;
  if (lines.isNotEmpty) {
    final line = lines.first;
    glyphWidth = line.width.clamp(0.0, maxTextWidth);
    lineLeft = line.left;
    baselineY = targetBaselineY;
    paraTopY = targetBaselineY - line.baseline;
  } else {
    glyphWidth = paragraph.maxIntrinsicWidth.clamp(0.0, maxTextWidth);
    lineLeft = 0.0;
    baselineY = targetBaselineY;
    paraTopY = center.dy - fontSize * 0.58;
  }

  final totalContentW = leadingIconSlotWidth + glyphWidth;
  final pillWidth = (totalContentW + horizontalPadding * 2.0)
      .clamp(minPillWidth, maxPillWidth);
  final contentLeftX = center.dx - totalContentW * 0.5;
  final paraLeftX = contentLeftX + leadingIconSlotWidth - lineLeft;

  final pillRect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: center,
      width: pillWidth,
      height: pillHeight,
    ),
    Radius.circular(borderRadius),
  );

  return CenteredPillLayout(
    pillRect: pillRect,
    paragraph: paragraph,
    paragraphTopLeft: Offset(paraLeftX, paraTopY),
    glyphWidth: glyphWidth,
    baselineY: baselineY,
    leadingIconLeftX: contentLeftX,
  );
}

/// Renders a floating world pill with baseline-centered typography and optional stroke border.
CenteredPillLayout renderCenteredWorldPill({
  required Canvas canvas,
  required Offset center,
  required String text,
  required double fontSize,
  required Color textColor,
  required Color backgroundColor,
  Color? borderColor,
  double borderWidth = 1.0,
  FontWeight fontWeight = FontWeight.w700,
  double letterSpacing = 0.2,
  double horizontalPadding = 8.0,
  double pillHeight = 13.5,
  double minPillWidth = 44.0,
  double maxPillWidth = 310.0,
  double borderRadius = 6.0,
  double leadingIconSlotWidth = 0.0,
}) {
  final layout = computeCenteredWorldPill(
    center: center,
    text: text,
    fontSize: fontSize,
    textColor: textColor,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    horizontalPadding: horizontalPadding,
    pillHeight: pillHeight,
    minPillWidth: minPillWidth,
    maxPillWidth: maxPillWidth,
    borderRadius: borderRadius,
    leadingIconSlotWidth: leadingIconSlotWidth,
  );

  canvas.drawRRect(
    layout.pillRect,
    Paint()..color = backgroundColor,
  );
  if (borderColor != null && borderWidth > 0.0) {
    canvas.drawRRect(
      layout.pillRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..color = borderColor,
    );
  }
  canvas.drawParagraph(layout.paragraph, layout.paragraphTopLeft);
  return layout;
}

/// Renders a crisp floating marquee pill above any active stage in view (above darkness veil).
class StageLiveBannerComponent extends Component {
  StageLiveBannerComponent({
    required this.liveStagesGetter,
    required this.stagesCatalog,
    required this.cameraCenterGetter,
    required this.timeGetter,
    this.viewBoundsGetter,
    super.priority = 9600,
  });

  final Map<String, LiveStageVisualState> Function() liveStagesGetter;
  final Map<String, StageInfo> stagesCatalog;
  final Offset Function() cameraCenterGetter;
  final double Function() timeGetter;
  final Rect Function()? viewBoundsGetter;

  static const Map<String, Offset> bannerWorldAnchors = {
    'main_roots_stage': Offset(608, 312),
    'pa_global_horn': Offset(784, 296),
    'velvet_canopy_stage': Offset(216, 296),
    'mellow_meadow_stage': Offset(1150, 390),
    'andromeda_pavilion_stage': Offset(1760, 268),
    'urbano_canopy_stage': Offset(228, 960),
    'sorting_arcade_stage': Offset(1746, 948),
  };

  @override
  void render(Canvas canvas) {
    final live = liveStagesGetter();
    if (live.isEmpty) return;

    final cam = cameraCenterGetter();
    final view = viewBoundsGetter?.call().inflate(100.0) ??
        Rect.fromCenter(center: cam, width: 760, height: 720);
    final t = timeGetter();

    for (final entry in live.entries) {
      final anchor = bannerWorldAnchors[entry.key] ??
          Offset(
            stagesCatalog[entry.key]?.x ?? 608,
            (stagesCatalog[entry.key]?.y ?? 368) - 56,
          );
      if (!view.contains(anchor)) continue;

      final show = entry.value.show;
      final bob = math.sin(t * 2.4) * 0.9 - show.beatPulse * 0.75;
      final center = Offset(anchor.dx, anchor.dy + bob);
      final label =
          '${entry.value.track.artist}  ·  ${show.sectionMode.displayBadge}';

      final accentBorder = Color.lerp(
        entry.value.primaryColor,
        const Color(0xFFFFFFFF),
        (show.blinderBurst * 0.65).clamp(0.0, 0.65),
      )!
          .withValues(alpha: 0.94);

      final layout = renderCenteredWorldPill(
        canvas: canvas,
        center: center,
        text: label,
        fontSize: 7.4,
        textColor: const Color(0xFFFFF8E7),
        backgroundColor: const Color(0xDE16100C),
        borderColor: accentBorder,
        borderWidth: 1.05 + show.beatPulse * 0.7,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.25,
        horizontalPadding: 9.0,
        pillHeight: 16.0,
        minPillWidth: 84.0,
        maxPillWidth: 316.0,
        borderRadius: 8.0,
        leadingIconSlotWidth: 11.0,
      );

      // Beat-synced 3-bar concert equalizer icon vertically centered on pill midline!
      final eqLeft = layout.leadingIconLeftX;
      final heights = <double>[
        (2.8 + show.bass * 5.2 + show.beatPulse * 1.4).clamp(2.5, 8.6),
        (3.4 + show.mid * 5.0 + 1.2 * math.sin(t * 9.0).abs()).clamp(2.8, 9.0),
        (2.6 + show.highMid * 5.0 + 1.2 * math.cos(t * 11.0).abs())
            .clamp(2.4, 8.4),
      ];
      for (var i = 0; i < 3; i++) {
        final barH = heights[i];
        final bx = eqLeft + i * 2.5 + 0.9;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(bx, center.dy),
              width: 1.7,
              height: barH,
            ),
            const Radius.circular(0.85),
          ),
          Paint()
            ..color = i == 1
                ? entry.value.secondaryColor
                : entry.value.primaryColor,
        );
      }
    }
  }
}
