import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import 'day_night_atmosphere.dart';
import 'stage_3d_rig_component.dart';

/// Overhead catenary festoon / pennant garland span in 2D world coordinates.
class FestivalGarlandSpan {
  const FestivalGarlandSpan({
    required this.id,
    required this.start,
    required this.end,
    required this.sag,
    required this.bulbCount,
    required this.hasPennants,
    this.bulbColor = const Color(0xFFFFE599),
    this.pennantPalette = _default1969Pennants,
  });

  static const List<Color> _default1969Pennants = [
    Color(0xFFE76F51),
    Color(0xFFE9C46A),
    Color(0xFF2A9D8F),
    Color(0xFFF4A261),
    Color(0xFF9D4EDD),
  ];

  final String id;
  final Offset start;
  final Offset end;
  final double sag;
  final int bulbCount;
  final bool hasPennants;
  final Color bulbColor;
  final List<Color> pennantPalette;

  Rect get bounds => Rect.fromPoints(start, end).inflate(sag.abs() + 28.0);

  Offset sampleAt(double u, {double windSway = 0.0}) {
    final x = start.dx + (end.dx - start.dx) * u;
    final yBase = start.dy + (end.dy - start.dy) * u;
    final parabola = 4.0 * u * (1.0 - u);
    return Offset(
      x + windSway * parabola * 0.45,
      yBase + sag * parabola + windSway.abs() * parabola * 0.15,
    );
  }
}

/// Coordinates handcrafted 2.5D festival grounds scenery, animated landmarks,
/// flowing Willow Creek caustics & cedar bridge rails, Crossroads Peace Mosaic,
/// Shady Bottoms crackling campfire, Main Roots FOH Mixing Tower, Vendor Row
/// market pergolas, Andromeda ley-lines, and overhead catenary string lights.
class FestivalGroundsSceneryController {
  FestivalGroundsSceneryController({
    required this.metricsGetter,
    required this.cameraCenterGetter,
    required this.viewBoundsGetter,
    required this.timeGetter,
    required this.bassGetter,
    required this.tunedResonatorsGetter,
  }) {
    surfaceLayer = FestivalGroundsSurfaceLayer(controller: this);
    propsLayer = FestivalGroundsPropsLayer(controller: this);
    overheadLayer = FestivalGroundsOverheadLayer(controller: this);
  }

  /// Central Orchard Crossroads 1969 Peace Medallion Plaza (`tx:38, ty:54`).
  static const Offset crossroadsPlazaCenter = Offset(608.0, 864.0);

  /// Carved multi-directional wooden festival fingerpost at Crossroads edge.
  static const Offset crossroadsFingerpostPos = Offset(566.0, 846.0);

  /// Shady Bottoms Communal Campfire Hearth (`tx:67, ty:65`).
  static const Offset campgroundFireCenter = Offset(1080.0, 1048.0);

  /// Main Roots Front-of-House (FOH) Sound & Liquid-Light Mixing Tower.
  static const Offset mainRootsFohTowerCenter = Offset(776.0, 568.0);

  /// Three arched Cedar Footbridges carrying festival lanes across eastern Willow Creek.
  static const List<Offset> easternCreekBridges = [
    Offset(1476.0, 624.0), // North Stage Boulevard Bridge
    Offset(1476.0, 864.0), // Mid-Orchard Trail Bridge
    Offset(1476.0, 1104.0), // South Campground-to-Arcade Bridge
  ];

  /// Overhead Edison-bulb catenary festoons & swaying 1969 screen-printed bunting.
  static const List<FestivalGarlandSpan> garlandSpans = [
    // 1. Front Gate Welcome Promenade (2 festive catenary arches)
    FestivalGarlandSpan(
      id: 'gate_promenade_south',
      start: Offset(544.0, 1234.0),
      end: Offset(672.0, 1234.0),
      sag: 12.0,
      bulbCount: 7,
      hasPennants: true,
    ),
    FestivalGarlandSpan(
      id: 'gate_promenade_north',
      start: Offset(544.0, 1164.0),
      end: Offset(672.0, 1164.0),
      sag: 12.0,
      bulbCount: 7,
      hasPennants: true,
    ),
    // 2. Central Orchard Crossroads Peace Plaza X-canopy
    FestivalGarlandSpan(
      id: 'crossroads_nw_se',
      start: Offset(552.0, 828.0),
      end: Offset(664.0, 898.0),
      sag: 14.0,
      bulbCount: 7,
      hasPennants: true,
    ),
    FestivalGarlandSpan(
      id: 'crossroads_sw_ne',
      start: Offset(552.0, 898.0),
      end: Offset(664.0, 828.0),
      sag: 14.0,
      bulbCount: 7,
      hasPennants: false,
    ),
    // 3. Main Roots Amphitheater Rim Festoons
    FestivalGarlandSpan(
      id: 'main_roots_west_rim',
      start: Offset(452.0, 476.0),
      end: Offset(528.0, 444.0),
      sag: 10.0,
      bulbCount: 5,
      hasPennants: true,
    ),
    FestivalGarlandSpan(
      id: 'main_roots_east_rim',
      start: Offset(688.0, 444.0),
      end: Offset(768.0, 476.0),
      sag: 10.0,
      bulbCount: 5,
      hasPennants: true,
    ),
    // 4. Velvet Canopy Wisteria & Amethyst Lantern Garlands
    FestivalGarlandSpan(
      id: 'velvet_canopy_drape',
      start: Offset(116.0, 434.0),
      end: Offset(308.0, 434.0),
      sag: 15.0,
      bulbCount: 8,
      hasPennants: true,
      bulbColor: Color(0xFFF3D5FF),
      pennantPalette: [
        Color(0xFF9D4EDD),
        Color(0xFFF72585),
        Color(0xFFFFBE0B),
        Color(0xFF7209B7),
      ],
    ),
    // 5. Urbano Canopy Santurce Fiesta Papel-Picado & Warm Bulbs
    FestivalGarlandSpan(
      id: 'urbano_fiesta_north',
      start: Offset(120.0, 1066.0),
      end: Offset(344.0, 1066.0),
      sag: 14.0,
      bulbCount: 9,
      hasPennants: true,
      pennantPalette: [
        Color(0xFFFF595E),
        Color(0xFFFFCA3A),
        Color(0xFF06D6A0),
        Color(0xFF118AB2),
        Color(0xFFF72585),
      ],
    ),
    FestivalGarlandSpan(
      id: 'urbano_fiesta_south',
      start: Offset(120.0, 1156.0),
      end: Offset(344.0, 1156.0),
      sag: 13.0,
      bulbCount: 8,
      hasPennants: true,
      pennantPalette: [
        Color(0xFFFFCA3A),
        Color(0xFF06D6A0),
        Color(0xFFFF595E),
        Color(0xFF4CC9F0),
      ],
    ),
    // 6. Shady Bottoms Vendor Row Artisan Market Festoons
    FestivalGarlandSpan(
      id: 'vendor_row_north',
      start: Offset(1124.0, 952.0),
      end: Offset(1384.0, 952.0),
      sag: 14.0,
      bulbCount: 10,
      hasPennants: true,
    ),
    FestivalGarlandSpan(
      id: 'vendor_row_promenade',
      start: Offset(1124.0, 1018.0),
      end: Offset(1384.0, 1018.0),
      sag: 13.0,
      bulbCount: 9,
      hasPennants: false,
    ),
    FestivalGarlandSpan(
      id: 'vendor_row_curios',
      start: Offset(1248.0, 1176.0),
      end: Offset(1380.0, 1176.0),
      sag: 11.0,
      bulbCount: 6,
      hasPennants: true,
    ),
    // 7. Sorting Machine Arcade Carnival Entrance Valances
    FestivalGarlandSpan(
      id: 'arcade_west_marquee',
      start: Offset(1568.0, 1062.0),
      end: Offset(1568.0, 1138.0),
      sag: 8.0,
      bulbCount: 6,
      hasPennants: true,
      bulbColor: Color(0xFFFFBE0B),
      pennantPalette: [
        Color(0xFFE63946),
        Color(0xFFFFBE0B),
        Color(0xFF00F5D4),
        Color(0xFF9D4EDD),
      ],
    ),
    FestivalGarlandSpan(
      id: 'arcade_south_marquee',
      start: Offset(1688.0, 1228.0),
      end: Offset(1776.0, 1228.0),
      sag: 10.0,
      bulbCount: 6,
      hasPennants: true,
      bulbColor: Color(0xFFFFBE0B),
      pennantPalette: [
        Color(0xFFE63946),
        Color(0xFFFFBE0B),
        Color(0xFF00F5D4),
        Color(0xFF9D4EDD),
      ],
    ),
  ];

  final DayNightMetrics Function() metricsGetter;
  final Offset Function() cameraCenterGetter;
  final Rect Function() viewBoundsGetter;
  final double Function() timeGetter;
  final double Function() bassGetter;
  final Set<String> Function() tunedResonatorsGetter;

  late final FestivalGroundsSurfaceLayer surfaceLayer;
  late final FestivalGroundsPropsLayer propsLayer;
  late final FestivalGroundsOverheadLayer overheadLayer;

  Future<void> mountIntoWorld(World world) async {
    await world.add(surfaceLayer);
    await world.add(propsLayer);
    await world.add(overheadLayer);
  }

  /// Contributes warm dusk/night light pools for the Campfire Hearth, Crossroads
  /// Peace Plaza, FOH Mixing Tower, Cedar Bridges, and Catenary Festoon Spans.
  List<LightSource3D> collectVisibleLights(
    Rect bounds, {
    required double lanternStrength,
  }) {
    final out = <LightSource3D>[];
    final metrics = metricsGetter();
    final t = timeGetter();

    // Campfire glows warmly day & night, intensifying after dusk!
    final fireFlicker = 0.88 + 0.12 * math.sin(t * 9.5);
    if (bounds.inflate(96).contains(campgroundFireCenter)) {
      out.add(
        LightSource3D(
          position: campgroundFireCenter,
          radius: 86.0 * fireFlicker,
          color: const Color(0xFFFF9F1C),
          intensity: math.max(0.55, lanternStrength * 0.96) * fireFlicker,
        ),
      );
    }

    if (lanternStrength <= 0.06 && metrics.darknessFactor <= 0.06) {
      return out;
    }

    final effStrength = math.max(lanternStrength, metrics.darknessFactor * 0.9);

    if (bounds.inflate(80).contains(crossroadsPlazaCenter)) {
      out.add(
        LightSource3D(
          position: crossroadsPlazaCenter,
          radius: 78.0,
          color: const Color(0xFFFFE599),
          intensity: effStrength * 0.82,
        ),
      );
    }

    if (bounds.inflate(70).contains(mainRootsFohTowerCenter)) {
      out.add(
        LightSource3D(
          position: mainRootsFohTowerCenter,
          radius: 64.0,
          color: const Color(0xFF80FFDB),
          intensity: effStrength * 0.74,
        ),
      );
    }

    for (final bridgePt in easternCreekBridges) {
      if (bounds.inflate(64).contains(bridgePt)) {
        out.add(
          LightSource3D(
            position: bridgePt,
            radius: 58.0,
            color: const Color(0xFFFFCF56),
            intensity: effStrength * 0.78,
          ),
        );
      }
    }

    // Midpoint warm festoon light pool for each visible catenary garland
    for (final span in garlandSpans) {
      final mid = span.sampleAt(0.5);
      if (bounds.inflate(72).contains(mid)) {
        out.add(
          LightSource3D(
            position: mid,
            radius: 66.0,
            color: span.bulbColor,
            intensity: effStrength * 0.72,
          ),
        );
      }
    }

    return out;
  }
}

/// Ground-plane mosaics, amphitheater hillside terracing, stage-front rugs,
/// animated Willow Creek caustics/outflow, and Andromeda meteoric ley-lines.
class FestivalGroundsSurfaceLayer extends Component {
  FestivalGroundsSurfaceLayer({
    required this.controller,
    super.priority = -4450,
  });

  final FestivalGroundsSceneryController controller;

  @override
  void render(Canvas canvas) {
    final view = controller.viewBoundsGetter().inflate(110.0);
    final t = controller.timeGetter();
    final bass = controller.bassGetter();
    final metrics = controller.metricsGetter();

    // 1. Central Orchard Crossroads 1969 Peace Medallion Mosaic (608, 864)
    if (view.overlaps(const Rect.fromLTWH(552, 812, 112, 104))) {
      _drawCrossroadsPeaceMosaic(canvas, t, bass, metrics);
    }

    // 2. Main Roots Hillside Amphitheater Terrace Contours (456..760, 456..592)
    if (view.overlaps(const Rect.fromLTWH(452, 452, 312, 144))) {
      _drawMainRootsTerraceArcs(canvas, bass);
    }

    // 3. Velvet Canopy Bohemian Stage-Front Woven Persian Rugs (124..308, 404..560)
    if (view.overlaps(const Rect.fromLTWH(120, 400, 192, 168))) {
      _drawVelvetBohemianRugs(canvas);
    }

    // 4. Connected Willow Creek Outflow Brook & Animated Eastern Stream Shimmer
    if (view.overlaps(const Rect.fromLTWH(968, 280, 560, 1248))) {
      _drawWillowCreekBrookLinksAndShimmer(canvas, view, t);
    }

    // 5. Andromeda Pavilion Illuminated Meteoric Ley-Line Conduits
    if (view.overlaps(const Rect.fromLTWH(1552, 180, 432, 412))) {
      _drawAndromedaLeyLines(canvas, t, bass, controller.tunedResonatorsGetter());
    }

    // 6. Undergrowth Sacred Stone Mandala & Bell Glade Rings
    if (view.overlaps(const Rect.fromLTWH(1024, 104, 356, 144))) {
      _drawUndergrowthSanctumMandala(canvas, t);
    }

    // 7. Urbano Canopy Painted Santurce Sunburst Courtyard Mosaic
    if (view.overlaps(const Rect.fromLTWH(148, 1064, 176, 112))) {
      _drawUrbanoCourtyardSunburst(canvas, bass);
    }

    // 8. Sorting Machine Arcade Carnival Welcome Runners
    if (view.overlaps(const Rect.fromLTWH(1532, 1068, 256, 208))) {
      _drawArcadeCarnivalRunners(canvas);
    }
  }

  void _drawCrossroadsPeaceMosaic(
    Canvas canvas,
    double t,
    double bass,
    DayNightMetrics metrics,
  ) {
    const c = FestivalGroundsSceneryController.crossroadsPlazaCenter;
    // Outer sandstone curb ring + recessed shadow
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, 2.0), width: 92, height: 68),
      Paint()..color = const Color(0x551E140C),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 90, height: 66),
      Paint()..color = const Color(0xFF8C6D53),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 82, height: 58),
      Paint()..color = const Color(0xFFD5BDA2),
    );
    // Turquoise & terracotta 1969 pebble inlay ring
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 70, height: 48),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..color = const Color(0xFF2A9D8F),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 54, height: 37),
      Paint()..color = const Color(0xFFC89F78),
    );

    // Iconic inlaid 1969 Peace Symbol in warm golden brass & terracotta stone
    final peaceStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0
      ..color = Color.lerp(
        const Color(0xFF6F4518),
        const Color(0xFFFFD166),
        (0.28 + metrics.lanternGlowStrength * 0.45 + bass * 0.25).clamp(0.0, 1.0),
      )!;
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 42, height: 29),
      peaceStroke,
    );
    canvas.drawLine(c.translate(0, -14.5), c.translate(0, 14.5), peaceStroke);
    canvas.drawLine(c, c.translate(-14.5, 10.2), peaceStroke);
    canvas.drawLine(c, c.translate(14.5, 10.2), peaceStroke);

    // 12 perimeter mosaic petals
    for (var i = 0; i < 12; i++) {
      final a = (i / 12.0) * math.pi * 2.0;
      final pt = Offset(c.dx + math.cos(a) * 38.0, c.dy + math.sin(a) * 26.5);
      canvas.drawCircle(
        pt,
        2.0,
        Paint()
          ..color = i.isEven
              ? const Color(0xFFE76F51)
              : const Color(0xFFE9C46A),
      );
    }
  }

  void _drawMainRootsTerraceArcs(Canvas canvas, double bass) {
    const stageOrigin = Offset(608.0, 412.0);
    for (var tier = 0; tier < 3; tier++) {
      final rx = 112.0 + tier * 34.0;
      final ry = 68.0 + tier * 24.0;
      final rect = Rect.fromCenter(
        center: stageOrigin,
        width: rx * 2.0,
        height: ry * 2.0,
      );
      // Subtle 2.5D earthen/timber lawn terrace lip along the southern bowl arc
      canvas.drawArc(
        rect.shift(const Offset(0, 2.0)),
        0.22,
        math.pi - 0.44,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = const Color(0x441B2E1E),
      );
      canvas.drawArc(
        rect,
        0.22,
        math.pi - 0.44,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = Color.fromRGBO(
            198,
            154,
            98,
            0.28 + bass * 0.10,
          ),
      );
    }
  }

  void _drawVelvetBohemianRugs(Canvas canvas) {
    const rugs = <(Offset, double, double, Color, Color)>[
      (Offset(174, 468), 46, 28, Color(0xFF720026), Color(0xFFFFBE0B)),
      (Offset(252, 470), 46, 28, Color(0xFF3C096C), Color(0xFFF72585)),
      (Offset(214, 514), 56, 30, Color(0xFF590D22), Color(0xFF4CC9F0)),
    ];
    for (final (center, w, h, bodyCol, medallionCol) in rugs) {
      final r = Rect.fromCenter(center: center, width: w, height: h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.shift(const Offset(0, 1.5)), const Radius.circular(2.5)),
        Paint()..color = const Color(0x440D0614),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(2.5)),
        Paint()..color = bodyCol,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.deflate(3.0), const Radius.circular(1.5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = medallionCol.withValues(alpha: 0.85),
      );
      // Diamond Persian center medallion
      final diamond = Path()
        ..moveTo(center.dx, center.dy - h * 0.24)
        ..lineTo(center.dx + w * 0.20, center.dy)
        ..lineTo(center.dx, center.dy + h * 0.24)
        ..lineTo(center.dx - w * 0.20, center.dy)
        ..close();
      canvas.drawPath(
        diamond,
        Paint()..color = medallionCol.withValues(alpha: 0.72),
      );
      // Cream fringe tassels
      final fringe = Paint()..color = const Color(0xCCF8EDEB);
      for (var fy = r.top + 3.0; fy <= r.bottom - 3.0; fy += 4.5) {
        canvas.drawRect(Rect.fromLTWH(r.left - 2.4, fy, 2.0, 1.1), fringe);
        canvas.drawRect(Rect.fromLTWH(r.right + 0.4, fy, 2.0, 1.1), fringe);
      }
    }
  }

  void _drawWillowCreekBrookLinksAndShimmer(
    Canvas canvas,
    Rect view,
    double t,
  ) {
    // A. Upstream headwater spring brook feeding into Mellow Meadow's Creek Stage bend (1026, 408)
    if (view.overlaps(const Rect.fromLTWH(972, 288, 68, 132))) {
      final headwater = Path()
        ..moveTo(990.0, 294.0)
        ..quadraticBezierTo(1004.0, 352.0, 1026.0, 408.0);
      _strokeShallowBrook(canvas, headwater, t, seed: 1.0);
      // Mossy spring headwater basin at (990, 294)
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(990, 294), width: 26, height: 16),
        Paint()..color = const Color(0xFF264A30),
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(990, 294), width: 19, height: 11),
        Paint()..color = const Color(0xFF2EC4B6),
      );
    }

    // B. Gentle stepped meadow brook linking Creek Stage bend (1218, 536) east into main Willow Creek (1460, 588)
    // Walkable shallow stepping-stone brook so zero meadow paths are blocked!
    if (view.overlaps(const Rect.fromLTWH(1210, 526, 260, 76))) {
      final outflow = Path()
        ..moveTo(1218.0, 536.0)
        ..cubicTo(1284.0, 544.0, 1368.0, 578.0, 1458.0, 586.0);
      _strokeShallowBrook(canvas, outflow, t, seed: 2.7);
      // Walkable flat slate stepping stones across the shallow meadow brook
      for (final st in const [
        Offset(1254, 540),
        Offset(1306, 552),
        Offset(1364, 568),
        Offset(1418, 580),
      ]) {
        canvas.drawOval(
          Rect.fromCenter(center: st.translate(0, 1.0), width: 9.5, height: 5.8),
          Paint()..color = const Color(0xFF2B2D42),
        );
        canvas.drawOval(
          Rect.fromCenter(center: st, width: 8.5, height: 4.8),
          Paint()..color = const Color(0xFF98A4B8),
        );
      }
    }

    // C. Animated water caustics, drifting willow leaves & arched cedar bridge rails along Eastern Willow Creek!
    if (view.overlaps(const Rect.fromLTWH(1432, 288, 88, 1224))) {
      for (var i = 0; i < 26; i++) {
        final wy = 304.0 + ((i * 46.0 + t * 22.0) % 1188.0);
        // Skip underneath solid cedar bridge decks
        if ((wy > 590 && wy < 658) ||
            (wy > 846 && wy < 884) ||
            (wy > 1070 && wy < 1138)) {
          continue;
        }
        final tileY = wy / 16.0;
        final cx = (91.5 + math.sin(tileY * 0.14) * 1.2) * 16.0;
        final pt = Offset(cx + math.sin(t * 2.4 + i) * 5.0, wy);
        if (!view.contains(pt)) continue;

        // Specular water ripple
        canvas.drawOval(
          Rect.fromCenter(center: pt, width: 8.0, height: 2.2),
          Paint()..color = const Color(0x88CAF0F8),
        );
        // Every 4th ripple carries a drifting golden willow leaf!
        if (i % 4 == 0) {
          canvas.drawOval(
            Rect.fromCenter(
              center: pt.translate(4.0, 3.0),
              width: 4.2,
              height: 1.9,
            ),
            Paint()..color = const Color(0xCCE9C46A),
          );
        }
      }

      // 3D Cedar Footbridge Side Handrails & Corner Posts at all 3 eastern crossings
      for (final (bCenter, halfH) in const [
        (Offset(1476.0, 624.0), 34.0),
        (Offset(1476.0, 864.0), 22.0),
        (Offset(1476.0, 1104.0), 34.0),
      ]) {
        if (!view.inflate(48).contains(bCenter)) continue;
        _drawEasternBridgeRails(canvas, bCenter, halfH);
      }
    }
  }

  void _strokeShallowBrook(
    Canvas canvas,
    Path path,
    double t, {
    required double seed,
  }) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 13.0
        ..color = const Color(0xFF285238),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 8.5
        ..color = const Color(0xFF1A6B82),
    );
    final pulse = 0.55 + 0.35 * math.sin(t * 3.0 + seed);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4.2
        ..color = Color.fromRGBO(72, 202, 228, pulse),
    );
  }

  void _drawEasternBridgeRails(Canvas canvas, Offset center, double halfH) {
    const halfW = 42.0;
    final topY = center.dy - halfH;
    final botY = center.dy + halfH;

    // North & south timber handrails with brass bolt rivets
    for (final ry in [topY, botY]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(center.dx, ry + 1.5), width: halfW * 2, height: 5.0),
          const Radius.circular(2.0),
        ),
        Paint()..color = const Color(0x66081C24),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(center.dx, ry), width: halfW * 2, height: 4.5),
          const Radius.circular(2.0),
        ),
        Paint()..color = const Color(0xFF6F4518),
      );
      canvas.drawRect(
        Rect.fromCenter(center: Offset(center.dx, ry - 1.0), width: halfW * 2 - 4, height: 1.4),
        Paint()..color = const Color(0xFFC68B59),
      );
      for (final postX in [center.dx - halfW + 3, center.dx, center.dx + halfW - 3]) {
        canvas.drawCircle(Offset(postX, ry), 2.8, Paint()..color = const Color(0xFF3B2314));
        canvas.drawCircle(
          Offset(postX, ry - 0.8),
          2.0,
          Paint()..color = const Color(0xFFD4A373),
        );
      }
    }
  }

  void _drawAndromedaLeyLines(
    Canvas canvas,
    double t,
    double bass,
    Set<String> tuned,
  ) {
    const domeHub = Offset(1760.0, 352.0);
    const spires = <(String, Offset)>[
      ('resonator_nw', Offset(1584.0, 208.0)),
      ('resonator_ne', Offset(1968.0, 240.0)),
      ('resonator_se', Offset(1952.0, 576.0)),
    ];

    for (var i = 0; i < spires.length; i++) {
      final (id, spirePos) = spires[i];
      final isTuned = tuned.contains(id);
      // Etched crystal conduit groove
      canvas.drawLine(
        spirePos,
        domeHub,
        Paint()
          ..strokeWidth = isTuned ? 4.2 : 2.4
          ..strokeCap = StrokeCap.round
          ..color = isTuned
              ? Color.fromRGBO(114, 239, 221, 0.36 + bass * 0.20)
              : const Color(0x3048CAE4),
      );
      canvas.drawLine(
        spirePos,
        domeHub,
        Paint()
          ..strokeWidth = 1.2
          ..color = isTuned
              ? const Color(0xCC80FFDB)
              : const Color(0x557209B7),
      );

      // Traveling harmonic energy pulse packet along tuned ley-lines!
      if (isTuned) {
        final u = ((t * 0.45) + i * 0.33) % 1.0;
        final px = spirePos.dx + (domeHub.dx - spirePos.dx) * u;
        final py = spirePos.dy + (domeHub.dy - spirePos.dy) * u;
        canvas.drawCircle(
          Offset(px, py),
          4.2,
          Paint()..color = const Color(0x5580FFDB),
        );
        canvas.drawCircle(
          Offset(px, py),
          2.0,
          Paint()..color = const Color(0xFFFFFFFF),
        );
      }
    }
  }

  void _drawUndergrowthSanctumMandala(Canvas canvas, double t) {
    const sanctum = Offset(1208.0, 152.0);
    final pulse = 0.5 + 0.5 * math.sin(t * 2.2);
    canvas.drawOval(
      Rect.fromCenter(center: sanctum, width: 68, height: 48),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = Color.fromRGBO(128, 255, 219, 0.25 + 0.18 * pulse),
    );
    for (var i = 0; i < 8; i++) {
      final a = (i / 8.0) * math.pi * 2.0 + t * 0.12;
      final candle = Offset(
        sanctum.dx + math.cos(a) * 28.0,
        sanctum.dy + math.sin(a) * 19.0,
      );
      canvas.drawCircle(candle, 3.6, Paint()..color = const Color(0x44FFD166));
      canvas.drawCircle(candle, 1.5, Paint()..color = const Color(0xFFFFF3B0));
    }

    // Subtle harmonic moss rings at the West & East stereo bell glades
    for (final bellGlade in const [Offset(1064, 212), Offset(1336, 196)]) {
      canvas.drawOval(
        Rect.fromCenter(center: bellGlade, width: 34, height: 22),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0x4452B788),
      );
    }
  }

  void _drawUrbanoCourtyardSunburst(Canvas canvas, double bass) {
    const center = Offset(236.0, 1116.0);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 76, height: 48),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = Color.fromRGBO(255, 190, 11, 0.34 + bass * 0.18),
    );
    for (var i = 0; i < 8; i++) {
      final a = (i / 8.0) * math.pi * 2.0;
      canvas.drawLine(
        Offset(center.dx + math.cos(a) * 14.0, center.dy + math.sin(a) * 9.0),
        Offset(center.dx + math.cos(a) * 34.0, center.dy + math.sin(a) * 21.0),
        Paint()
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..color = i.isEven
              ? const Color(0x55E63946)
              : const Color(0x5506D6A0),
      );
    }
  }

  void _drawArcadeCarnivalRunners(Canvas canvas) {
    // Striped red & gold welcome mats at West (1576, 1104) & South (1736, 1228) Arcade doors
    for (final rect in const [
      Rect.fromLTWH(1556, 1084, 30, 40),
      Rect.fromLTWH(1704, 1220, 64, 26),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()..color = const Color(0xFF9B2226),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(2.5), const Radius.circular(2)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFFFFBE0B),
      );
    }
  }
}

/// Y-sorted 2.5D festival landmarks: Crossroads Directional Fingerpost,
/// Shady Bottoms Crackling Campfire & Ember Circle, Campground Tie-Dye Line,
/// Main Roots FOH Sound/Light Tower, and Vendor Row Artisan Market Pergolas.
class FestivalGroundsPropsLayer extends Component {
  FestivalGroundsPropsLayer({
    required this.controller,
    super.priority = 1290,
  });

  final FestivalGroundsSceneryController controller;

  @override
  void render(Canvas canvas) {
    final view = controller.viewBoundsGetter().inflate(100.0);
    final t = controller.timeGetter();
    final bass = controller.bassGetter();
    final metrics = controller.metricsGetter();

    // 1. Central Crossroads Carved Wooden 1969 Directional Fingerpost
    if (view.contains(FestivalGroundsSceneryController.crossroadsFingerpostPos)) {
      _drawCrossroadsFingerpost(canvas, metrics);
    }

    // 2. Main Roots FOH Sound & Liquid-Light Mixing Tower (776, 568)
    if (view.overlaps(const Rect.fromLTWH(744, 524, 68, 68))) {
      _drawMainRootsFohTower(canvas, t, bass, metrics);
    }

    // 3. Shady Bottoms Crackling Communal Campfire & Split-Log Circle (1080, 1048)
    if (view.overlaps(const Rect.fromLTWH(1036, 1012, 88, 72))) {
      _drawCampgroundFireCircle(canvas, t, metrics);
    }

    // 4. Shady Bottoms Tie-Dye Clothesline beside North Tent (984..1038, 944)
    if (view.overlaps(const Rect.fromLTWH(976, 926, 72, 36))) {
      _drawCampgroundTieDyeLine(canvas, t, metrics.windStrength);
    }

    // 5. Vendor Row Artisan Timber Pergola Awnings & Market Signage
    if (view.overlaps(const Rect.fromLTWH(1124, 932, 268, 288))) {
      _drawVendorRowMarketAwnings(canvas, t);
    }
  }

  void _drawCrossroadsFingerpost(Canvas canvas, DayNightMetrics metrics) {
    const base = FestivalGroundsSceneryController.crossroadsFingerpostPos;
    // Directional ground shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: base + metrics.shadowOffset * 0.7,
        width: 18,
        height: 6,
      ),
      Paint()..color = const Color(0x550D130F),
    );
    // Cedar post
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(base.dx - 2.2, base.dy - 28.0, 4.4, 29.0),
        const Radius.circular(1.5),
      ),
      Paint()..color = const Color(0xFF5C3A21),
    );
    // Painted directional arrow boards
    const signs = <(double, double, Color, String)>[
      (-25.0, -1.0, Color(0xFFE9C46A), '↑ MAIN ROOTS'),
      (-18.5, -6.0, Color(0xFF9D4EDD), '↖ VELVET'),
      (-12.0, 6.0, Color(0xFF52B788), 'MEADOW ↗'),
      (-5.5, 5.0, Color(0xFFE76F51), 'VENDORS ↘'),
    ];
    for (final (yOff, xShift, col, _) in signs) {
      final r = Rect.fromCenter(
        center: Offset(base.dx + xShift, base.dy + yOff),
        width: 24.0,
        height: 5.0,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(1.4)),
        Paint()..color = col,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(1.4)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..color = const Color(0xFF2B180B),
      );
    }
    // Finial brass peace sphere atop post
    canvas.drawCircle(
      Offset(base.dx, base.dy - 30.0),
      2.6,
      Paint()..color = const Color(0xFFFFD166),
    );
  }

  void _drawMainRootsFohTower(
    Canvas canvas,
    double t,
    double bass,
    DayNightMetrics metrics,
  ) {
    const c = FestivalGroundsSceneryController.mainRootsFohTowerCenter;
    // 3D ground shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c.translate(metrics.shadowOffset.dx, 6.0 + metrics.shadowOffset.dy),
          width: 44,
          height: 22,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0x5508100C),
    );

    // Timber scaffold desk & equipment rack
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: 38, height: 20),
        const Radius.circular(2.5),
      ),
      Paint()..color = const Color(0xFF4A2E1B),
    );
    canvas.drawRect(
      Rect.fromCenter(center: c.translate(0, -4.0), width: 34, height: 9),
      Paint()..color = const Color(0xFF212529),
    );

    // Twin spinning analog reel-to-reel tape spools & bouncing VU meters!
    for (final sx in [-9.0, -2.5]) {
      final reelCenter = c.translate(sx, -4.5);
      canvas.drawCircle(reelCenter, 2.7, Paint()..color = const Color(0xFFADB5BD));
      final spin = t * 4.2;
      canvas.drawLine(
        reelCenter.translate(math.cos(spin) * -2.2, math.sin(spin) * -2.2),
        reelCenter.translate(math.cos(spin) * 2.2, math.sin(spin) * 2.2),
        Paint()
          ..strokeWidth = 0.8
          ..color = const Color(0xFF212529),
      );
    }
    // Glowing green/amber analog console faders & VU meter
    for (var f = 0; f < 4; f++) {
      final level = 0.4 + 0.6 * ((math.sin(t * 7.0 + f * 1.4) * 0.5 + 0.5) * (0.5 + bass * 0.5));
      canvas.drawRect(
        Rect.fromLTWH(c.dx + 4.0 + f * 3.0, c.dy - 2.0 - level * 5.0, 2.0, level * 5.0),
        Paint()
          ..color = level > 0.78
              ? const Color(0xFFFFBE0B)
              : const Color(0xFF80FFDB),
      );
    }

    // 4 vertical corner scaffold poles + striped 1969 sun/rain canopy roof
    for (final px in [-17.0, 17.0]) {
      canvas.drawRect(
        Rect.fromLTWH(c.dx + px - 1.2, c.dy - 28.0, 2.4, 32.0),
        Paint()..color = const Color(0xFF7F5539),
      );
    }
    final roof = Rect.fromCenter(center: c.translate(0, -28.0), width: 42, height: 13);
    canvas.drawRRect(
      RRect.fromRectAndRadius(roof, const Radius.circular(2.5)),
      Paint()..color = const Color(0xFF264653),
    );
    for (var s = 0; s < 5; s++) {
      canvas.drawRect(
        Rect.fromLTWH(roof.left + 3.0 + s * 7.6, roof.top + 1.5, 4.0, roof.height - 3.0),
        Paint()
          ..color = s.isEven
              ? const Color(0xFFE9C46A)
              : const Color(0xFFE76F51),
      );
    }

    renderCenteredWorldPill(
      canvas: canvas,
      center: c.translate(0, -37.5),
      text: '🎛️ SOUND & LIGHTS',
      fontSize: 5.2,
      textColor: const Color(0xFFFFF3D6),
      backgroundColor: const Color(0xCC1B120C),
      borderColor: const Color(0xFFE9C46A),
      borderWidth: 0.7,
      horizontalPadding: 4.5,
      pillHeight: 9.5,
      minPillWidth: 48.0,
      maxPillWidth: 84.0,
      borderRadius: 4.0,
    );
  }

  void _drawCampgroundFireCircle(
    Canvas canvas,
    double t,
    DayNightMetrics metrics,
  ) {
    const c = FestivalGroundsSceneryController.campgroundFireCenter;

    // Split-cedar sitting logs arranged in a welcoming semicircle around the fire
    for (final (lx, ly, w, h) in const [
      (-20.0, -10.0, 14.0, 5.0),
      (20.0, -10.0, 14.0, 5.0),
      (0.0, 15.0, 18.0, 5.0),
    ]) {
      final logRect = Rect.fromCenter(center: c.translate(lx, ly), width: w, height: h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(logRect.shift(const Offset(0, 1.5)), const Radius.circular(2.2)),
        Paint()..color = const Color(0x550C0A08),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(logRect, const Radius.circular(2.2)),
        Paint()..color = const Color(0xFF7F4F24),
      );
      canvas.drawRect(
        Rect.fromCenter(center: c.translate(lx, ly - 1.2), width: w - 3, height: 1.2),
        Paint()..color = const Color(0xFFB08968),
      );
    }

    // Warm ground firelight halo
    final flicker = 0.85 + 0.15 * math.sin(t * 11.0);
    canvas.drawCircle(
      c,
      20.0 * flicker,
      Paint()
        ..color = Color.fromRGBO(
          255,
          159,
          28,
          (0.20 + metrics.darknessFactor * 0.28) * flicker,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Animated 3-tongue crackling campfire flames
    for (var i = 0; i < 3; i++) {
      final sway = math.sin(t * 9.5 + i * 2.1) * 1.8;
      final flameH = (8.5 + math.cos(t * 12.0 + i) * 2.2) * (i == 1 ? 1.22 : 0.92);
      final fx = c.dx + (i - 1) * 3.0 + sway * 0.4;
      final flamePath = Path()
        ..moveTo(fx - 3.2, c.dy + 1.0)
        ..quadraticBezierTo(fx - 2.0, c.dy - flameH * 0.6, fx + sway, c.dy - flameH)
        ..quadraticBezierTo(fx + 2.4, c.dy - flameH * 0.5, fx + 3.2, c.dy + 1.0)
        ..close();
      canvas.drawPath(
        flamePath,
        Paint()
          ..color = i == 1
              ? const Color(0xFFFFBE0B)
              : const Color(0xFFFB5607),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, -2.5), width: 4.5, height: 5.5),
      Paint()..color = const Color(0xFFFFF3B0),
    );

    // Rising glowing campfire embers
    for (var e = 0; e < 5; e++) {
      final p = ((t * 0.65) + e * 0.2) % 1.0;
      final ex = c.dx + math.sin(t * 3.0 + e * 1.7) * 6.0;
      final ey = c.dy - 8.0 - p * 18.0;
      canvas.drawCircle(
        Offset(ex, ey),
        1.2 * (1.0 - p * 0.5),
        Paint()..color = Color.fromRGBO(255, 209, 102, (1.0 - p) * 0.9),
      );
    }
  }

  void _drawCampgroundTieDyeLine(Canvas canvas, double t, double wind) {
    const pA = Offset(984.0, 940.0);
    const pB = Offset(1036.0, 942.0);
    for (final p in [pA, pB]) {
      canvas.drawRect(
        Rect.fromLTWH(p.dx - 1.0, p.dy - 14.0, 2.0, 15.0),
        Paint()..color = const Color(0xFF6F4518),
      );
    }
    final linePath = Path()
      ..moveTo(pA.dx, pA.dy - 13.0)
      ..quadraticBezierTo(1010.0, 932.0, pB.dx, pB.dy - 13.0);
    canvas.drawPath(
      linePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = const Color(0xFFD8C3A5),
    );
    const shirtColors = [
      Color(0xFFFF595E),
      Color(0xFFFFCA3A),
      Color(0xFF4CC9F0),
      Color(0xFF9D4EDD),
    ];
    for (var i = 0; i < 4; i++) {
      final u = 0.18 + i * 0.21;
      final x = pA.dx + (pB.dx - pA.dx) * u;
      final sway = math.sin(t * (2.6 + wind * 2.0) + i) * (1.2 + wind * 2.0);
      canvas.save();
      canvas.translate(x, 930.5 + (u * (1 - u)) * 8.0);
      canvas.rotate(sway * 0.08);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3.5, 0, 7.0, 7.5),
          const Radius.circular(1.2),
        ),
        Paint()..color = shirtColors[i],
      );
      canvas.drawCircle(
        const Offset(0, 3.8),
        1.8,
        Paint()..color = const Color(0xFFFFF3B0),
      );
      canvas.restore();
    }
  }

  void _drawVendorRowMarketAwnings(Canvas canvas, double t) {
    const stalls = <(Offset, double, Color, Color)>[
      (Offset(1152, 956), 34, Color(0xFF2A9D8F), Color(0xFFE9C46A)), // Street Food & Cider
      (Offset(1296, 954), 58, Color(0xFFE63946), Color(0xFFFFF3D6)), // Burt's Falafel Stand
      (Offset(1360, 956), 30, Color(0xFF7209B7), Color(0xFF80FFDB)), // Vocal Tea Kettle
      (Offset(1296, 1178), 58, Color(0xFFE76F51), Color(0xFFFFD166)), // Vintage Vinyl Booth
    ];
    for (final (center, width, c1, c2) in stalls) {
      final r = Rect.fromCenter(center: center, width: width, height: 10.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.shift(const Offset(0, 2.0)), const Radius.circular(2.0)),
        Paint()..color = const Color(0x44120B07),
      );
      const stripes = 6;
      final sw = width / stripes;
      for (var i = 0; i < stripes; i++) {
        canvas.drawRect(
          Rect.fromLTWH(r.left + i * sw, r.top, sw + 0.4, r.height),
          Paint()..color = i.isEven ? c1 : c2,
        );
      }
      // Scalloped awning valance
      final flutter = math.sin(t * 3.0 + center.dx * 0.05) * 0.5;
      for (var i = 0; i < stripes; i++) {
        canvas.drawCircle(
          Offset(r.left + (i + 0.5) * sw, r.bottom + flutter),
          2.2,
          Paint()..color = i.isEven ? c1 : c2,
        );
      }
    }
  }
}

/// Elevated 2.5D catenary Edison-bulb string lights & wind-swaying 1969 pennant
/// bunting across festival promenades, crossroads, stages, and Vendor Row.
class FestivalGroundsOverheadLayer extends Component {
  FestivalGroundsOverheadLayer({
    required this.controller,
    super.priority = 6250,
  });

  final FestivalGroundsSceneryController controller;

  @override
  void render(Canvas canvas) {
    final view = controller.viewBoundsGetter().inflate(120.0);
    final cam = controller.cameraCenterGetter();
    final metrics = controller.metricsGetter();
    final t = controller.timeGetter();
    final bass = controller.bassGetter();

    // Match subtle overhead canopy parallax for convincing 2.5D height!
    final parallaxX = ((cam.dx - 1024.0) * -0.009).clamp(-6.0, 6.0);
    final parallaxY = ((cam.dy - 768.0) * -0.009).clamp(-5.0, 5.0);
    final windAmp = 0.8 + metrics.windStrength * 2.6;
    final bulbsLit =
        metrics.lanternGlowStrength > 0.08 || metrics.darknessFactor > 0.08;
    final glowAlpha =
        math.max(metrics.lanternGlowStrength, metrics.darknessFactor).clamp(0.18, 1.0);

    canvas.save();
    canvas.translate(parallaxX, parallaxY);

    for (var sIdx = 0; sIdx < FestivalGroundsSceneryController.garlandSpans.length; sIdx++) {
      final span = FestivalGroundsSceneryController.garlandSpans[sIdx];
      if (!view.overlaps(span.bounds)) continue;

      final sway = math.sin(t * (1.8 + metrics.windStrength * 1.6) + sIdx * 0.9) * windAmp;

      // 1. Soft ground drop-shadow during daytime sun
      if (metrics.shadowAlpha > 0.08) {
        final shadowPath = Path()..moveTo(span.start.dx, span.start.dy + 18.0);
        final midShadow = span.sampleAt(0.5, windSway: sway).translate(
              metrics.shadowOffset.dx,
              18.0 + metrics.shadowOffset.dy,
            );
        shadowPath.quadraticBezierTo(
          midShadow.dx,
          midShadow.dy + span.sag * 0.5,
          span.end.dx,
          span.end.dy + 18.0,
        );
        canvas.drawPath(
          shadowPath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = Color.fromRGBO(10, 16, 12, metrics.shadowAlpha * 0.32),
        );
      }

      // 2. Catenary wire cord
      final cordPath = Path()..moveTo(span.start.dx, span.start.dy);
      const segments = 12;
      for (var i = 1; i <= segments; i++) {
        final pt = span.sampleAt(i / segments, windSway: sway);
        cordPath.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(
        cordPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.15
          ..color = const Color(0xFF2B1D14),
      );

      // 3. Swaying 1969 triangular cloth pennants between bulbs
      if (span.hasPennants) {
        final pennantCount = span.bulbCount + 2;
        for (var p = 1; p < pennantCount; p++) {
          final u = p / pennantCount;
          final anchor = span.sampleAt(u, windSway: sway);
          final flutter = math.sin(t * 4.2 + p * 1.3 + sIdx) * (1.1 + metrics.windStrength * 1.8);
          final col = span.pennantPalette[(p + sIdx) % span.pennantPalette.length];
          final tri = Path()
            ..moveTo(anchor.dx - 2.6, anchor.dy + 0.4)
            ..lineTo(anchor.dx + 2.6, anchor.dy + 0.4)
            ..lineTo(anchor.dx + flutter, anchor.dy + 6.4)
            ..close();
          canvas.drawPath(tri, Paint()..color = col);
        }
      }

      // 4. Warm vintage Edison bulbs (soft glass during day, golden halo at dusk/night!)
      for (var b = 1; b <= span.bulbCount; b++) {
        final u = b / (span.bulbCount + 1);
        final pt = span.sampleAt(u, windSway: sway).translate(0, 1.8);
        if (bulbsLit) {
          final pulse = 0.90 + 0.10 * math.sin(t * 6.0 + b * 1.7) + bass * 0.08;
          canvas.drawCircle(
            pt,
            7.2 * pulse,
            Paint()
              ..color = span.bulbColor.withValues(alpha: (0.24 * glowAlpha).clamp(0.0, 0.36))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5),
          );
          canvas.drawCircle(
            pt,
            1.9,
            Paint()..color = const Color(0xFFFFF9DB),
          );
        } else {
          canvas.drawCircle(
            pt,
            1.5,
            Paint()..color = const Color(0xCCFFF3D6),
          );
        }
      }
    }

    canvas.restore();
  }
}
