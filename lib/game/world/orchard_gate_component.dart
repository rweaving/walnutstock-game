import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/models.dart';
import 'day_night_atmosphere.dart';
import 'stage_3d_rig_component.dart';

class HeritageCultivarTreeSpot {
  const HeritageCultivarTreeSpot({
    required this.cultivarId,
    required this.x,
    required this.y,
    required this.groveLabel,
  });

  final String cultivarId;
  final double x;
  final double y;
  final String groveLabel;

  Offset get position => Offset(x, y);
}

class OrchardGateLayout {
  const OrchardGateLayout._();

  static const Offset archCenter = Offset(608.0, 1296.0);
  static const Offset lineupKioskPos = Offset(536.0, 1320.0);
  static const Offset cultivarBoothPos = Offset(680.0, 1320.0);
  static const Offset northHintPos = Offset(608.0, 1284.0);

  /// 11 verified walkable Heritage Walnut Cultivar locations across the orchard.
  static const List<HeritageCultivarTreeSpot> heritageCultivarSpots = [
    HeritageCultivarTreeSpot(
      cultivarId: 'chandler',
      x: 520.0,
      y: 1248.0,
      groveLabel: 'South Gate Welcome Grove',
    ),
    HeritageCultivarTreeSpot(
      cultivarId: 'hartley',
      x: 744.0,
      y: 520.0,
      groveLabel: 'Main Roots East Terrace',
    ),
    HeritageCultivarTreeSpot(
      cultivarId: 'howard',
      x: 472.0,
      y: 488.0,
      groveLabel: 'Main Roots West Lawn',
    ),
    HeritageCultivarTreeSpot(
      cultivarId: 'tulare',
      x: 312.0,
      y: 472.0,
      groveLabel: 'Velvet Canopy Footpath',
    ),
    HeritageCultivarTreeSpot(
      cultivarId: 'franquette',
      x: 1032.0,
      y: 520.0,
      groveLabel: 'Mellow Meadow Approach',
    ),
    HeritageCultivarTreeSpot(
      cultivarId: 'juglans_hindsii',
      x: 1272.0,
      y: 512.0,
      groveLabel: 'Old Oak Creekside Bank',
    ),
    HeritageCultivarTreeSpot(
      cultivarId: 'wen_wan',
      x: 336.0,
      y: 1088.0,
      groveLabel: 'Urbano Canopy Courtyard',
    ),
    HeritageCultivarTreeSpot(
      cultivarId: 'red_livermore',
      x: 928.0,
      y: 1032.0,
      groveLabel: 'Shady Bottoms West Glade',
    ),
    HeritageCultivarTreeSpot(
      cultivarId: 'serr',
      x: 1648.0,
      y: 544.0,
      groveLabel: 'Andromeda South Lawn',
    ),
    HeritageCultivarTreeSpot(
      cultivarId: 'japonica_heartnut',
      x: 1424.0,
      y: 920.0,
      groveLabel: 'Vendor Row East Path',
    ),
    HeritageCultivarTreeSpot(
      cultivarId: 'cinerea_butternut',
      x: 1520.0,
      y: 1120.0,
      groveLabel: 'Sorting Arcade Grove',
    ),
  ];
}

/// Renders the Orchard Gate flanking timber pillars, Chalkboard Lineup Kiosk (left),
/// Ticket & Cultivar Booth (right), and the 11 Heritage Walnut Cultivar shrines.
class OrchardGatePropsComponent extends Component {
  OrchardGatePropsComponent({
    required this.cultivarsById,
    required this.discoveredIdsGetter,
    required this.cameraCenterGetter,
    required this.timeGetter,
    required this.bassGetter,
    this.viewBoundsGetter,
    super.priority = 1295,
  });

  final Map<String, CultivarSpec> cultivarsById;
  final Set<String> Function() discoveredIdsGetter;
  final Offset Function() cameraCenterGetter;
  final double Function() timeGetter;
  final double Function() bassGetter;
  final Rect Function()? viewBoundsGetter;

  @override
  void render(Canvas canvas) {
    final cam = cameraCenterGetter();
    final view = viewBoundsGetter?.call().inflate(96.0) ??
        Rect.fromCenter(center: cam, width: 760, height: 720);
    final t = timeGetter();
    final bass = bassGetter();

    // 1. Orchard Gate Pillars & Diegetic Flanking Menus
    if (view.overlaps(const Rect.fromLTWH(496, 1240, 224, 120))) {
      _drawArchPillarsAndCarpet(canvas, t, bass);
      _drawChalkboardLineupKiosk(canvas, t);
      _drawTicketAndCultivarBooth(canvas, t);
    }

    // 2. 11 Heritage Walnut Cultivar Shrines across the Orchard
    final discovered = discoveredIdsGetter();
    for (final spot in OrchardGateLayout.heritageCultivarSpots) {
      if (!view.contains(spot.position)) continue;
      final spec = cultivarsById[spot.cultivarId];
      _drawHeritageCultivarPedestal(
        canvas,
        spot: spot,
        spec: spec,
        discovered: discovered.contains(spot.cultivarId),
        time: t,
      );
    }
  }

  void _drawArchPillarsAndCarpet(Canvas canvas, double t, double bass) {
    // Warm welcome lantern glow pools along the center entrance path
    final roadGlow = Paint()
      ..color = Color.fromRGBO(255, 198, 92, 0.14 + 0.06 * bass)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(608, 1300),
        width: 84,
        height: 44,
      ),
      roadGlow,
    );

    // Subtle woven hemp & marigold threshold runner between the pillars
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(580, 1292, 56, 8),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0x886F3D1B),
    );
    canvas.drawLine(
      const Offset(584, 1296),
      const Offset(632, 1296),
      Paint()
        ..color = const Color(0xAAFFD166)
        ..strokeWidth = 1.1,
    );

    // Left (x=564) & Right (x=652) hand-hewn redwood arch pillars (88px clear road between!)
    for (final px in const [564.0, 652.0]) {
      // Contact shadow
      canvas.drawOval(
        Rect.fromCenter(center: Offset(px, 1301), width: 18, height: 7),
        Paint()..color = const Color(0x66080504),
      );
      // Stone footing
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(px, 1298), width: 14, height: 8),
          const Radius.circular(2.5),
        ),
        Paint()..color = const Color(0xFF4A3B32),
      );
      // Redwood vertical timber post rising up to the overhead arch
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(px - 5.0, 1254.0, 10.0, 44.0),
          const Radius.circular(2.0),
        ),
        Paint()..color = const Color(0xFF5A3219),
      );
      canvas.drawRect(
        Rect.fromLTWH(px - 2.0, 1256.0, 2.0, 40.0),
        Paint()..color = const Color(0xFF8C532B),
      );
      // Climbing daisy & ivy wrap
      for (var v = 0; v < 3; v++) {
        final vy = 1264.0 + v * 10.0;
        final vx = px + (v.isEven ? -3.2 : 3.2);
        canvas.drawCircle(
          Offset(vx, vy),
          2.4,
          Paint()..color = const Color(0xFF52B788),
        );
        if (v == 1) {
          canvas.drawCircle(
            Offset(vx, vy),
            1.4,
            Paint()..color = const Color(0xFFFFD166),
          );
        }
      }
      // Warm hanging brass lantern on each pillar
      final lanternX = px + (px < 608 ? 7.5 : -7.5);
      final pulse = 0.86 + 0.14 * math.sin(t * 3.4 + px);
      canvas.drawCircle(
        Offset(lanternX, 1270.0),
        7.5 * pulse,
        Paint()
          ..color = const Color(0x55FFBE0B)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(
        Offset(lanternX, 1270.0),
        2.3,
        Paint()..color = const Color(0xFFFFF3B0),
      );
    }
  }

  void _drawChalkboardLineupKiosk(Canvas canvas, double t) {
    const c = OrchardGateLayout.lineupKioskPos;
    // Shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy + 9.0),
        width: 30,
        height: 9,
      ),
      Paint()..color = const Color(0x66090604),
    );
    // Warm lantern pool
    canvas.drawCircle(
      Offset(c.dx, c.dy - 4.0),
      19.0,
      Paint()
        ..color = const Color(0x33FFD166)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    // Cedar A-frame legs
    final legPaint = Paint()
      ..color = const Color(0xFF6F3D1B)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(c.dx - 10, c.dy + 8),
      Offset(c.dx - 7, c.dy - 14),
      legPaint,
    );
    canvas.drawLine(
      Offset(c.dx + 10, c.dy + 8),
      Offset(c.dx + 7, c.dy - 14),
      legPaint,
    );
    // Slate chalkboard face
    final boardRect = Rect.fromCenter(
      center: Offset(c.dx, c.dy - 4.0),
      width: 24.0,
      height: 19.0,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(2.5)),
      Paint()..color = const Color(0xFF1F2D24),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(2.5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xFFC68B59),
    );
    // Chalk schedule bars (5 stage color stripes!)
    const chalkCols = [
      Color(0xFFFFD166),
      Color(0xFF80FFDB),
      Color(0xFFFF8FAB),
      Color(0xFF9EF01A),
    ];
    for (var i = 0; i < chalkCols.length; i++) {
      final ly = boardRect.top + 4.2 + i * 3.4;
      canvas.drawLine(
        Offset(boardRect.left + 3.5, ly),
        Offset(boardRect.right - 4.0 - (i.isOdd ? 3.0 : 0.0), ly),
        Paint()
          ..color = chalkCols[i]
          ..strokeWidth = 1.25
          ..strokeCap = StrokeCap.round,
      );
    }
    // Corner Edison bulb
    final glow = 0.8 + 0.2 * math.sin(t * 4.0);
    canvas.drawCircle(
      Offset(boardRect.right - 1.0, boardRect.top - 1.5),
      2.1 * glow,
      Paint()..color = const Color(0xFFFFF3B0),
    );
  }

  void _drawTicketAndCultivarBooth(Canvas canvas, double t) {
    const c = OrchardGateLayout.cultivarBoothPos;
    // Shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy + 10.0),
        width: 36,
        height: 10,
      ),
      Paint()..color = const Color(0x66090604),
    );
    // Warm booth lantern pool
    canvas.drawCircle(
      Offset(c.dx, c.dy - 4.0),
      21.0,
      Paint()
        ..color = const Color(0x36FF9F1C)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    // Rustic wooden counter base
    final counterRect = Rect.fromCenter(
      center: Offset(c.dx, c.dy + 2.5),
      width: 28.0,
      height: 13.0,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(counterRect, const Radius.circular(2.5)),
      Paint()..color = const Color(0xFF6B3E26),
    );
    canvas.drawLine(
      Offset(counterRect.left + 1, counterRect.top + 1.5),
      Offset(counterRect.right - 1, counterRect.top + 1.5),
      Paint()
        ..color = const Color(0xFFD4A373)
        ..strokeWidth = 1.5,
    );
    // Upright awning posts
    final postPaint = Paint()
      ..color = const Color(0xFF4A2810)
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(c.dx - 12, c.dy - 3),
      Offset(c.dx - 12, c.dy - 15),
      postPaint,
    );
    canvas.drawLine(
      Offset(c.dx + 12, c.dy - 3),
      Offset(c.dx + 12, c.dy - 15),
      postPaint,
    );
    // Striped 1969 marigold & crimson festival awning
    const stripes = 5;
    const awningLeft = 680.0 - 15.0;
    const stripeW = 30.0 / stripes;
    for (var s = 0; s < stripes; s++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(awningLeft + s * stripeW, c.dy - 18.0, stripeW + 0.4, 6.5),
          const Radius.circular(1.5),
        ),
        Paint()
          ..color = s.isEven
              ? const Color(0xFFFFBE0B)
              : const Color(0xFFD62828),
      );
    }
    // Display row of 3 golden walnut shells + rotary mix dial on counter
    for (var w = -1; w <= 1; w++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(c.dx + w * 6.5, c.dy - 3.5),
          width: 4.4,
          height: 5.0,
        ),
        Paint()..color = const Color(0xFFC98A4B),
      );
    }
    final pulse = 0.82 + 0.18 * math.cos(t * 3.8);
    canvas.drawCircle(
      Offset(c.dx, c.dy - 10.5),
      2.0 * pulse,
      Paint()..color = const Color(0xFFFFF3B0),
    );
  }

  void _drawHeritageCultivarPedestal(
    Canvas canvas, {
    required HeritageCultivarTreeSpot spot,
    required CultivarSpec? spec,
    required bool discovered,
    required double time,
  }) {
    final c = spot.position;
    final accent = _parseHexColor(spec?.accentHex) ?? const Color(0xFFFFD166);
    final bob = math.sin(time * 2.8 + spot.x * 0.05) * 1.4;

    // Ground moss & stone ring
    canvas.drawOval(
      Rect.fromCenter(center: Offset(c.dx, c.dy + 5.0), width: 22, height: 9),
      Paint()..color = const Color(0x661B4332),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(c.dx, c.dy + 5.0), width: 18, height: 7),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = accent.withValues(alpha: discovered ? 0.55 : 0.85),
    );

    // Carved heartwood botanical marker stump
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(c.dx, c.dy + 0.5), width: 11, height: 10),
        const Radius.circular(2.5),
      ),
      Paint()..color = const Color(0xFF5C3419),
    );

    // Undiscovered cultivars shimmer with a warm golden-accent aura!
    if (!discovered) {
      final pulse = 0.65 + 0.35 * math.sin(time * 4.2 + spot.y * 0.03);
      canvas.drawCircle(
        Offset(c.dx, c.dy - 6.0 + bob),
        9.0 * pulse,
        Paint()
          ..color = accent.withValues(alpha: 0.34)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    // Sculpted heritage walnut shell emblem floating/resting above marker
    final shellCenter = Offset(c.dx, c.dy - 6.0 + (discovered ? 0.0 : bob));
    canvas.drawOval(
      Rect.fromCenter(center: shellCenter, width: 8.2, height: 9.4),
      Paint()..color = const Color(0xFFC98A4B),
    );
    canvas.drawOval(
      Rect.fromCenter(center: shellCenter, width: 8.2, height: 9.4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15
        ..color = discovered ? accent : const Color(0xFFFFF3B0),
    );
    canvas.drawLine(
      Offset(shellCenter.dx, shellCenter.dy - 4.0),
      Offset(shellCenter.dx, shellCenter.dy + 4.0),
      Paint()
        ..color = const Color(0xFF5A3219)
        ..strokeWidth = 1.0,
    );
  }

  static Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length != 6) return null;
    final val = int.tryParse('FF$cleaned', radix: 16);
    return val != null ? Color(val) : null;
  }
}

/// Renders overhead swaying concert searchlights, the glowing wooden WALNUTSTOCK arch,
/// and the disappearing center-path world hint.
class OrchardGateOverheadArchComponent extends Component {
  OrchardGateOverheadArchComponent({
    required this.metricsGetter,
    required this.cameraCenterGetter,
    required this.playerPositionGetter,
    required this.timeGetter,
    required this.bassGetter,
    this.viewBoundsGetter,
    super.priority = 6450,
  });

  final DayNightMetrics Function() metricsGetter;
  final Offset Function() cameraCenterGetter;
  final Offset Function() playerPositionGetter;
  final double Function() timeGetter;
  final double Function() bassGetter;
  final Rect Function()? viewBoundsGetter;

  @override
  void render(Canvas canvas) {
    final cam = cameraCenterGetter();
    final view = viewBoundsGetter?.call().inflate(120.0) ??
        Rect.fromCenter(center: cam, width: 780, height: 740);
    if (!view.overlaps(const Rect.fromLTWH(470, 1140, 280, 210))) {
      return;
    }

    final t = timeGetter();
    final bass = bassGetter();
    final playerPos = playerPositionGetter();

    // 1. Swaying distant concert stage beams rising north of the arch
    _drawDistantStageBeams(canvas, t, bass);

    // 2. Curved wooden WALNUTSTOCK arch beam & Edison festoon lights
    _drawWoodenArchSpan(canvas, t, bass);

    // 3. Disappearing world-space center path hint ("Drag or Tap North to Enter")
    final southSpan = ((playerPos.dy - 1278.0) / 38.0).clamp(0.0, 1.0);
    final horizNear = (1.0 - ((playerPos.dx - 608.0).abs() / 130.0)).clamp(0.0, 1.0);
    final hintAlpha = (southSpan * horizNear).clamp(0.0, 1.0);
    if (hintAlpha > 0.04) {
      final bob = math.sin(t * 3.1) * 1.6;
      renderCenteredWorldPill(
        canvas: canvas,
        center: Offset(
          OrchardGateLayout.northHintPos.dx,
          OrchardGateLayout.northHintPos.dy + bob,
        ),
        text: '↑ Drag or Tap North to Enter the Orchard',
        fontSize: 6.8,
        textColor: Color.fromRGBO(255, 248, 228, 0.96 * hintAlpha),
        backgroundColor: Color.fromRGBO(22, 14, 10, 0.80 * hintAlpha),
        borderColor: Color.fromRGBO(255, 209, 102, 0.78 * hintAlpha),
        borderWidth: 0.95,
        horizontalPadding: 8.0,
        pillHeight: 14.5,
        minPillWidth: 112.0,
        maxPillWidth: 196.0,
        borderRadius: 7.5,
      );
    }
  }

  void _drawDistantStageBeams(Canvas canvas, double t, double bass) {
    const beamConfigs = <(double, Color, double, double)>[
      (584.0, Color(0xFFFFBE0B), -0.22, 1.0),
      (608.0, Color(0xFF06D6A0), 0.04, 1.25),
      (632.0, Color(0xFFFF006E), 0.22, 0.9),
    ];
    canvas.save();
    for (var i = 0; i < beamConfigs.length; i++) {
      final (originX, col, baseAngle, speed) = beamConfigs[i];
      final sway = baseAngle + math.sin(t * speed + i * 1.4) * 0.14;
      final alpha = (0.11 + 0.06 * bass).clamp(0.08, 0.22);
      canvas.save();
      canvas.translate(originX, 1252.0);
      canvas.rotate(sway);
      final cone = Path()
        ..moveTo(-5.0, 0.0)
        ..lineTo(-28.0, -108.0)
        ..lineTo(28.0, -108.0)
        ..lineTo(5.0, 0.0)
        ..close();
      canvas.drawPath(
        cone,
        Paint()
          ..shader = Gradient.linear(
            const Offset(0, 0),
            const Offset(0, -108),
            [
              col.withValues(alpha: alpha),
              col.withValues(alpha: 0.0),
            ],
          )
          ..blendMode = BlendMode.plus,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  void _drawWoodenArchSpan(Canvas canvas, double t, double bass) {
    // Warm golden halo behind the WALNUTSTOCK arch sign
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(608.0, 1250.0),
        width: 122.0,
        height: 30.0,
      ),
      Paint()
        ..color = Color.fromRGBO(255, 188, 56, 0.26 + 0.10 * bass)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Curved timber crossbeam connecting x=560 .. x=656
    final archBeam = Path()
      ..moveTo(558.0, 1258.0)
      ..quadraticBezierTo(608.0, 1236.0, 658.0, 1258.0)
      ..lineTo(658.0, 1265.0)
      ..quadraticBezierTo(608.0, 1244.0, 558.0, 1265.0)
      ..close();
    canvas.drawPath(archBeam, Paint()..color = const Color(0xFF4A2812));
    canvas.drawPath(
      archBeam,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFC68B59),
    );

    // Hanging Edison festoon string lights beneath the arch
    const bulbCount = 7;
    for (var b = 0; b < bulbCount; b++) {
      final frac = b / (bulbCount - 1);
      final bx = 568.0 + frac * 80.0;
      final curveY = 1262.0 - math.sin(frac * math.pi) * 9.5;
      final twinkle = 0.80 + 0.20 * math.sin(t * 4.5 + b * 1.1);
      final bulbCol = b.isOdd
          ? const Color(0xFFFFD166)
          : const Color(0xFFFFF3B0);
      canvas.drawCircle(
        Offset(bx, curveY + 2.2),
        4.2 * twinkle,
        Paint()
          ..color = bulbCol.withValues(alpha: 0.34)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        Offset(bx, curveY + 2.2),
        1.45,
        Paint()..color = bulbCol,
      );
    }

    // Carved wooden WALNUTSTOCK 1969 marquee plaque centered on the arch crown
    renderCenteredWorldPill(
      canvas: canvas,
      center: const Offset(608.0, 1249.0),
      text: '★ WALNUTSTOCK · 1969 ★',
      fontSize: 7.6,
      textColor: const Color(0xFFFFD166),
      backgroundColor: const Color(0xF228150B),
      borderColor: const Color(0xFFE9C46A),
      borderWidth: 1.25,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.65,
      horizontalPadding: 9.5,
      pillHeight: 15.5,
      minPillWidth: 96.0,
      maxPillWidth: 164.0,
      borderRadius: 6.0,
    );
  }
}
