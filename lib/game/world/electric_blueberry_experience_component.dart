import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../actors/player_walnut.dart';
import '../actors/stage_performer_director.dart';
import 'day_night_atmosphere.dart';
import 'stage_3d_rig_component.dart';

class _RainbowStepRing {
  _RainbowStepRing({
    required this.pos,
    required this.hueOffset,
  });

  final Offset pos;
  final double hueOffset;
  double age = 0.0;
  static const double maxAge = 2.4;
}

class _FloatingBerrySparkle {
  _FloatingBerrySparkle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.hue,
  });

  double x;
  double y;
  final double vx;
  final double vy;
  final double hue;
  double age = 0.0;
  static const double maxAge = 1.6;
}

/// Joyful creekside festivalgoer walnut sharing Electric Purple Blueberries on Day 2!
class BlueberrySharerComponent extends PositionComponent {
  BlueberrySharerComponent({
    required this.id,
    required this.displayName,
    required this.spriteSheet,
    required this.homePos,
    required this.facingRight,
    required this.metricsGetter,
    required this.callouts,
    required double phaseOffset,
  })  : _animClock = phaseOffset,
        super(
          position: Vector2(homePos.dx, homePos.dy),
          size: Vector2.all(32),
          anchor: Anchor.center,
        );

  final String id;
  final String displayName;
  final Image spriteSheet;
  final Offset homePos;
  final bool facingRight;
  final DayNightMetrics Function() metricsGetter;
  final List<String> callouts;

  double _animClock;
  double _celebrateTimer = 0.0;

  void celebrateShare() {
    _celebrateTimer = 1.8;
  }

  void stepSharer(double dt) {
    _animClock += dt;
    if (_celebrateTimer > 0.0) {
      _celebrateTimer = math.max(0.0, _celebrateTimer - dt);
    }
    final swayX = math.sin(_animClock * 2.1) * 1.6;
    final swayY = math.cos(_animClock * 1.5) * 0.8;
    position.setValues(homePos.dx + swayX, homePos.dy + swayY);
    priority = position.y.round();
  }

  @override
  void render(Canvas canvas) {
    final metrics = metricsGetter();
    final hop = _celebrateTimer > 0.0
        ? math.sin(_animClock * 14.0).abs() * 3.8
        : math.sin(_animClock * 3.2).abs() * 1.2;

    renderActor3dShadow(
      canvas: canvas,
      metrics: metrics,
      centerX: 16.0,
      footY: 28.5,
    );

    final facingRow = facingRight ? 2 : 1;
    final frameCol = ((_animClock * 3.0).floor() % 2 == 0) ? 0 : 1;
    final src = Rect.fromLTWH(frameCol * 32.0, facingRow * 32.0, 32.0, 32.0);

    canvas.save();
    final tilt = math.sin(_animClock * 2.6) * 0.06;
    canvas.translate(16.0, 24.0);
    canvas.rotate(tilt);
    canvas.translate(-16.0, -24.0);

    canvas.drawImageRect(
      spriteSheet,
      src,
      Rect.fromLTWH(0, -hop, 32.0, 32.0),
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );

    // Electric-purple tie-dye headband
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10.0, 7.5 - hop, 12.0, 2.4),
        const Radius.circular(1.2),
      ),
      Paint()..color = const Color(0xFF9D4EDD),
    );
    canvas.drawRect(
      Rect.fromLTWH(13.0, 7.5 - hop, 3.5, 2.4),
      Paint()..color = const Color(0xFF00F5D4),
    );

    // Small wooden bowl of glowing Electric Purple Blueberries held toward the basket
    final bowlX = facingRight ? 22.5 : 9.5;
    final bowlY = 20.5 - hop;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bowlX, bowlY + 1.2), width: 7.5, height: 4.0),
      Paint()..color = const Color(0xFF6C462C),
    );
    for (final bOff in const [Offset(-1.5, -0.6), Offset(1.4, -0.7), Offset(0.0, -1.6)]) {
      canvas.drawCircle(
        Offset(bowlX + bOff.dx, bowlY + bOff.dy),
        1.5,
        Paint()..color = const Color(0xFF9D4EDD),
      );
      canvas.drawCircle(
        Offset(bowlX + bOff.dx - 0.4, bowlY + bOff.dy - 0.4),
        0.55,
        Paint()..color = const Color(0xFFE0AAFF),
      );
    }
    canvas.restore();

    // Friendly rotating creekside berry-sharing callout pill
    final text = _celebrateTimer > 0.0
        ? '🌈 Enjoy 2 rainbow sets!'
        : callouts[((_animClock * 0.28).floor()) % callouts.length];
    renderCenteredWorldPill(
      canvas: canvas,
      center: Offset(16.0, -5.5 - hop),
      text: text,
      fontSize: 5.8,
      textColor: const Color(0xFFF3D5FF),
      backgroundColor: const Color(0xD9240E38),
      borderColor: const Color(0xFFE0AAFF),
      borderWidth: 0.85,
      horizontalPadding: 6.5,
      pillHeight: 12.2,
      minPillWidth: 68.0,
      maxPillWidth: 132.0,
      borderRadius: 5.5,
    );
  }
}

/// Coordinates the 3D Willow Creek beside the Creek Stage, the Day 2 Start
/// Electric Purple Blueberries Sharing Circle, and the 2-set Wavy Rainbow trail!
class ElectricBlueberryExperienceController {
  ElectricBlueberryExperienceController({
    required this.characterSheets,
    required this.metricsGetter,
    required this.cameraCenterGetter,
    required this.timeGetter,
    this.viewBoundsGetter,
  }) {
    groundLayer =
        _WillowCreekAndBerryGroundLayer(controller: this, priority: -4350);
    airborneLayer =
        _RainbowBerryAirborneLayer(controller: this, priority: 7250);
  }

  /// Walkable meadow spot right beside the Willow Creek & Meadow Stage (`1152, 448`).
  static const Offset basketWorldPos = Offset(1096.0, 496.0);

  /// Centerline control points of the 3D Willow Creek winding past the Creek Stage.
  static const List<Offset> creekSpine = <Offset>[
    Offset(1026.0, 408.0),
    Offset(1044.0, 452.0),
    Offset(1068.0, 492.0),
    Offset(1108.0, 522.0),
    Offset(1164.0, 532.0),
    Offset(1218.0, 536.0),
  ];

  final Map<String, Image> characterSheets;
  final DayNightMetrics Function() metricsGetter;
  final Offset Function() cameraCenterGetter;
  final Rect Function()? viewBoundsGetter;
  final double Function() timeGetter;

  late final Component groundLayer;
  late final Component airborneLayer;

  final List<BlueberrySharerComponent> _sharers = [];
  final List<_RainbowStepRing> _stepRings = [];
  final List<_FloatingBerrySparkle> _sparkles = [];

  bool _sharingActive = false;
  bool _rainbowActive = false;
  bool _playerWasInWalkoverZone = false;
  double _walkoverCooldown = 0.0;
  double _sparkleTimer = 0.0;
  Offset? _lastRingPos;

  bool get isSharingActive => _sharingActive;
  bool get isRainbowActive => _rainbowActive;
  int get activeSharerCount => _sharers.length;
  int get rainbowTrailCount => _stepRings.length;
  List<BlueberrySharerComponent> get sharers => _sharers;

  bool isPlayerNearBasket(Vector2 pos, {double maxRadius = 46.0}) {
    final dx = pos.x - basketWorldPos.dx;
    final dy = pos.y - basketWorldPos.dy;
    return (dx * dx + dy * dy) <= maxRadius * maxRadius;
  }

  bool shouldAutoShareOnWalkover(
    Vector2 pos, {
    required bool alreadyInFirstSet,
  }) {
    final dx = pos.x - basketWorldPos.dx;
    final dy = pos.y - basketWorldPos.dy;
    final insideNow = (dx * dx + dy * dy) <= 23.0 * 23.0;
    final enteredNow = insideNow && !_playerWasInWalkoverZone;
    _playerWasInWalkoverZone = insideNow;

    if (!_sharingActive || !enteredNow || alreadyInFirstSet) {
      return false;
    }
    if (_rainbowActive && _walkoverCooldown > 0.0) {
      return false;
    }
    return true;
  }

  void recordBerrySharedBurst() {
    _walkoverCooldown = 5.0;
    for (final s in _sharers) {
      s.celebrateShare();
    }
    for (var i = 0; i < 14; i++) {
      final ang = (i / 14.0) * math.pi * 2.0;
      final spd = 18.0 + (i % 4) * 7.0;
      _sparkles.add(
        _FloatingBerrySparkle(
          x: basketWorldPos.dx,
          y: basketWorldPos.dy - 6.0,
          vx: math.cos(ang) * spd,
          vy: math.sin(ang) * spd * 0.6 - 14.0,
          hue: i / 14.0,
        ),
      );
    }
  }

  void update({
    required double dt,
    required World world,
    required bool sharingActive,
    required bool rainbowActive,
    required PlayerWalnut player,
  }) {
    _sharingActive = sharingActive;
    _rainbowActive = rainbowActive;
    if (_walkoverCooldown > 0.0) {
      _walkoverCooldown = math.max(0.0, _walkoverCooldown - dt);
    }

    _syncSharers(world, sharingActive);
    for (final s in _sharers) {
      s.stepSharer(dt);
    }

    // Emit rainbow ripple footsteps & floating prismatic sparkles during the 2-set trip!
    if (rainbowActive) {
      final pPos = Offset(player.position.x, player.position.y);
      final prev = _lastRingPos;
      if (prev == null || (pPos - prev).distance >= 14.0) {
        if (_stepRings.length >= 28) {
          _stepRings.removeAt(0);
        }
        _stepRings.add(
          _RainbowStepRing(
            pos: pPos.translate(0, 6.0),
            hueOffset: timeGetter() * 0.45,
          ),
        );
        _lastRingPos = pPos;
      }

      _sparkleTimer -= dt;
      if (_sparkleTimer <= 0.0) {
        _sparkleTimer = 0.14;
        if (_sparkles.length < 36) {
          final t = timeGetter();
          final ang = (t * 5.7) % (math.pi * 2.0);
          _sparkles.add(
            _FloatingBerrySparkle(
              x: pPos.dx + math.cos(ang) * 14.0,
              y: pPos.dy - 4.0 + math.sin(ang) * 8.0,
              vx: math.cos(ang * 1.7) * 8.0,
              vy: -16.0 - (t * 10 % 8),
              hue: (t * 0.35) % 1.0,
            ),
          );
        }
      }
    } else {
      _lastRingPos = null;
    }

    for (var i = _stepRings.length - 1; i >= 0; i--) {
      _stepRings[i].age += dt;
      if (_stepRings[i].age >= _RainbowStepRing.maxAge) {
        _stepRings.removeAt(i);
      }
    }
    for (var i = _sparkles.length - 1; i >= 0; i--) {
      final sp = _sparkles[i];
      sp.age += dt;
      sp.x += sp.vx * dt;
      sp.y += sp.vy * dt;
      if (sp.age >= _FloatingBerrySparkle.maxAge) {
        _sparkles.removeAt(i);
      }
    }
  }

  void _syncSharers(World world, bool shouldHaveSharers) {
    if (!shouldHaveSharers) {
      if (_sharers.isNotEmpty) {
        for (final s in _sharers) {
          s.removeFromParent();
        }
        _sharers.clear();
      }
      return;
    }
    if (_sharers.isNotEmpty || characterSheets.isEmpty) return;

    final fallback = characterSheets.values.first;
    final west = BlueberrySharerComponent(
      id: 'berry_sharer_west',
      displayName: 'Clover Creek-Shell',
      spriteSheet:
          characterSheets['npc_festivalgoer_a'] ?? characterSheets['chandler'] ?? fallback,
      homePos: const Offset(1074.0, 494.0),
      facingRight: true,
      metricsGetter: metricsGetter,
      callouts: const [
        '🫐 Free Electric Blueberries!',
        '🌈 Fresh off Willow Creek!',
        '✨ Share a handful, friend!',
      ],
      phaseOffset: 0.0,
    );
    final east = BlueberrySharerComponent(
      id: 'berry_sharer_east',
      displayName: 'Indigo Berry-Bud',
      spriteSheet:
          characterSheets['npc_festivalgoer_b'] ?? characterSheets['franquette'] ?? fallback,
      homePos: const Offset(1118.0, 498.0),
      facingRight: false,
      metricsGetter: metricsGetter,
      callouts: const [
        '🌈 Wavy rainbow for 2 sets!',
        '🫐 Day 2 Sunrise Creek Share!',
        '✌️ Taste the purple magic!',
      ],
      phaseOffset: 1.7,
    );
    _sharers.addAll([west, east]);
    world.add(west);
    world.add(east);
  }

  static Color spectrumColor(double phase, {double alpha = 1.0}) {
    final r = (0.52 + 0.48 * math.cos(6.28318 * phase)).clamp(0.0, 1.0);
    final g = (0.52 + 0.48 * math.cos(6.28318 * (phase + 0.33))).clamp(0.0, 1.0);
    final b = (0.55 + 0.45 * math.cos(6.28318 * (phase + 0.67))).clamp(0.0, 1.0);
    return Color.fromRGBO(
      (r * 255).round(),
      (g * 255).round(),
      (b * 255).round(),
      alpha.clamp(0.0, 1.0),
    );
  }
}

class _WillowCreekAndBerryGroundLayer extends Component {
  _WillowCreekAndBerryGroundLayer({
    required this.controller,
    super.priority,
  });

  final ElectricBlueberryExperienceController controller;

  @override
  void render(Canvas canvas) {
    final cam = controller.cameraCenterGetter();
    final view = controller.viewBoundsGetter?.call().inflate(60.0) ??
        Rect.fromCenter(center: cam, width: 720, height: 680);
    final t = controller.timeGetter();
    final rainbow = controller.isRainbowActive;

    // 1. Render 3D Willow Creek, wild blueberry bushes & Cedar Footbridge near Creek Stage
    if (view.overlaps(const Rect.fromLTWH(1010, 396, 224, 156))) {
      _drawWillowCreek3D(canvas, t, rainbow);
      _drawCreekBlueberryBushes(canvas, t);
      _drawCedarFootbridge3D(canvas);
      if (controller.isSharingActive) {
        _drawSharingBlanketAndBasket3D(canvas, t);
      }
    }

    // 2. Render expanding world-space rainbow ripple trails behind player footsteps
    for (final ring in controller._stepRings) {
      if (!view.inflate(24).contains(ring.pos)) continue;
      final p = (ring.age / _RainbowStepRing.maxAge).clamp(0.0, 1.0);
      final fade = (1.0 - p) * 0.70;
      final col = ElectricBlueberryExperienceController.spectrumColor(
        ring.hueOffset + p * 0.6,
        alpha: fade,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: ring.pos,
          width: 10.0 + p * 26.0,
          height: 5.0 + p * 12.0,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 * (1.0 - p * 0.5)
          ..color = col,
      );
    }
  }

  void _drawWillowCreek3D(Canvas canvas, double t, bool rainbow) {
    final spine = ElectricBlueberryExperienceController.creekSpine;
    final path = Path()..moveTo(spine.first.dx, spine.first.dy);
    for (var i = 1; i < spine.length; i++) {
      final prev = spine[i - 1];
      final cur = spine[i];
      final mid = Offset((prev.dx + cur.dx) * 0.5, (prev.dy + cur.dy) * 0.5);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    path.lineTo(spine.last.dx, spine.last.dy);

    // Outer mossy creek bank bevel
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 22.0
        ..color = const Color(0xFF264A30),
    );
    // Sunken 3D earth shadow lip on north bank
    canvas.save();
    canvas.translate(0.0, -1.8);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 17.5
        ..color = const Color(0xFF162C1E),
    );
    canvas.restore();

    // Deep creek bed water
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 15.0
        ..color = rainbow
            ? ElectricBlueberryExperienceController.spectrumColor(
                t * 0.22,
                alpha: 0.88,
              )
            : const Color(0xFF165B75),
    );

    // Mid-stream turquoise flow
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 9.5
        ..color = rainbow
            ? ElectricBlueberryExperienceController.spectrumColor(
                t * 0.22 + 0.35,
                alpha: 0.90,
              )
            : const Color(0xFF2EC4B6),
    );

    // Animated flowing specular water ripples along the creek
    for (var i = 0; i < 14; i++) {
      final u = ((i / 14.0) + t * 0.14) % 1.0;
      final pt = _sampleSpine(u);
      final wobble = math.sin(t * 3.5 + i * 1.3) * 2.2;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(pt.dx + wobble, pt.dy + wobble * 0.4),
          width: 6.5,
          height: 2.2,
        ),
        Paint()
          ..color = rainbow
              ? const Color(0xCCFFF3B0)
              : const Color(0x99CBF3F0),
      );
    }

    // 3D smooth river cobbles along creek edges
    const cobbles = <Offset>[
      Offset(1033, 424),
      Offset(1053, 470),
      Offset(1092, 518),
      Offset(1138, 535),
      Offset(1188, 528),
    ];
    for (final c in cobbles) {
      canvas.drawOval(
        Rect.fromCenter(center: c.translate(0, 1.0), width: 6.0, height: 3.8),
        Paint()..color = const Color(0xFF2B3A42),
      );
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 5.4, height: 3.2),
        Paint()..color = const Color(0xFF778DA9),
      );
    }
  }

  Offset _sampleSpine(double u) {
    const spine = ElectricBlueberryExperienceController.creekSpine;
    final scaled = (u.clamp(0.0, 0.9999)) * (spine.length - 1);
    final idx = scaled.floor();
    final frac = scaled - idx;
    final a = spine[idx];
    final b = spine[idx + 1];
    return Offset(a.dx + (b.dx - a.dx) * frac, a.dy + (b.dy - a.dy) * frac);
  }

  void _drawCreekBlueberryBushes(Canvas canvas, double t) {
    const bushes = <Offset>[
      Offset(1036, 438),
      Offset(1054, 504),
      Offset(1126, 538),
      Offset(1178, 542),
    ];
    final pulse = 0.5 + 0.5 * math.sin(t * 3.4);
    for (final b in bushes) {
      // 3D ground shadow
      canvas.drawOval(
        Rect.fromCenter(center: b.translate(1.0, 4.5), width: 15, height: 6),
        Paint()..color = const Color(0x5508140C),
      );
      // Leafy emerald bush clusters
      canvas.drawCircle(b.translate(-3.5, 0.5), 5.2, Paint()..color = const Color(0xFF1B4332));
      canvas.drawCircle(b.translate(3.5, 0.8), 5.0, Paint()..color = const Color(0xFF2D6A4F));
      canvas.drawCircle(b.translate(0.0, -2.0), 5.6, Paint()..color = const Color(0xFF40916C));
      // Glowing wild Electric Purple Blueberries!
      for (final off in const [
        Offset(-3.2, -0.5),
        Offset(0.5, -3.0),
        Offset(3.4, -0.2),
        Offset(-0.8, 1.4),
      ]) {
        final bp = b + off;
        canvas.drawCircle(
          bp,
          2.6,
          Paint()..color = Color.fromRGBO(157, 78, 221, 0.25 + 0.25 * pulse),
        );
        canvas.drawCircle(bp, 1.5, Paint()..color = const Color(0xFF7B2CBF));
        canvas.drawCircle(
          bp.translate(-0.4, -0.4),
          0.55,
          Paint()..color = const Color(0xFFE0AAFF),
        );
      }
    }
  }

  void _drawCedarFootbridge3D(Canvas canvas) {
    // Spanning the creek bend at (1068, 492) toward the sharing blanket (1096, 496)
    canvas.save();
    canvas.translate(1068.0, 492.0);
    canvas.rotate(-0.52);

    // Bridge drop shadow over water
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-14, -7, 28, 16),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0x66061A24),
    );
    // Side stringer beams
    canvas.drawRect(
      const Rect.fromLTWH(-14, -8, 28, 14),
      Paint()..color = const Color(0xFF4A2E1B),
    );
    // 5 3D cedar planks
    for (var i = 0; i < 5; i++) {
      final px = -12.5 + i * 5.2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(px, -7.5, 4.3, 13.0),
          const Radius.circular(1),
        ),
        Paint()..color = i.isEven ? const Color(0xFF8C5A36) : const Color(0xFF7A4B2A),
      );
    }
    // Corner cedar posts
    for (final post in const [
      Offset(-12, -8),
      Offset(12, -8),
      Offset(-12, 6),
      Offset(12, 6),
    ]) {
      canvas.drawCircle(post, 2.1, Paint()..color = const Color(0xFF3B2314));
      canvas.drawCircle(
        post.translate(0, -1.0),
        1.7,
        Paint()..color = const Color(0xFFB07D4F),
      );
    }
    canvas.restore();
  }

  void _drawSharingBlanketAndBasket3D(Canvas canvas, double t) {
    const c = ElectricBlueberryExperienceController.basketWorldPos;
    final pulse = 0.5 + 0.5 * math.sin(t * 3.8);

    // Outer electric-purple ground aura
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 54 + pulse * 6, height: 30 + pulse * 3),
      Paint()..color = Color.fromRGBO(157, 78, 221, 0.16 + 0.10 * pulse),
    );

    // 3D Woven Tie-Dye Picnic Blanket
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, 1.5), width: 44, height: 24),
      Paint()..color = const Color(0xFF3C096C),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 42, height: 22),
      Paint()..color = const Color(0xFF7B2CBF),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 32, height: 16),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = const Color(0xFF00F5D4),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 22, height: 10),
      Paint()..color = const Color(0xFFFF9E00),
    );

    // Overflowing 3D Wicker Basket of Electric Purple Blueberries at center!
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, 2.5), width: 17, height: 7.5),
      Paint()..color = const Color(0x660D0618),
    );
    // Basket weave base
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c.translate(0, -0.5), width: 15.0, height: 8.5),
        const Radius.circular(3.5),
      ),
      Paint()..color = const Color(0xFF8C5A36),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c.translate(0, -3.2), width: 16.5, height: 4.0),
        const Radius.circular(2.0),
      ),
      Paint()..color = const Color(0xFFB07D4F),
    );

    // Heap of 3D glossy Electric Purple Blueberries!
    const berryOffsets = <Offset>[
      Offset(-4.5, -4.5),
      Offset(-1.5, -5.2),
      Offset(1.8, -5.0),
      Offset(4.5, -4.3),
      Offset(-3.0, -6.8),
      Offset(0.2, -7.4),
      Offset(3.0, -6.6),
      Offset(-0.8, -9.0),
      Offset(1.6, -8.7),
    ];
    for (final bo in berryOffsets) {
      final bp = c + bo;
      canvas.drawCircle(bp, 2.3, Paint()..color = const Color(0xFF5A189A));
      canvas.drawCircle(
        bp.translate(-0.2, -0.3),
        1.8,
        Paint()..color = const Color(0xFF9D4EDD),
      );
      canvas.drawCircle(
        bp.translate(-0.6, -0.7),
        0.65,
        Paint()..color = const Color(0xFFE0AAFF),
      );
    }

    // Wicker handle arch over top
    canvas.drawArc(
      Rect.fromCenter(center: c.translate(0, -5.0), width: 14.0, height: 14.0),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFFD4A373),
    );

    // Rising electric-purple & cyan dawn spores above the basket
    for (var i = 0; i < 5; i++) {
      final p = ((t * 0.75) + i * 0.2) % 1.0;
      final sx = c.dx + math.sin(t * 2.5 + i * 1.4) * 8.5;
      final sy = c.dy - 8.0 - p * 16.0;
      canvas.drawCircle(
        Offset(sx, sy),
        1.4 * (1.0 - p * 0.4),
        Paint()
          ..color = (i.isEven
                  ? const Color(0xFFE0AAFF)
                  : const Color(0xFF80FFDB))
              .withValues(alpha: (1.0 - p) * 0.85),
      );
    }
  }
}

class _RainbowBerryAirborneLayer extends Component {
  _RainbowBerryAirborneLayer({
    required this.controller,
    super.priority,
  });

  final ElectricBlueberryExperienceController controller;

  @override
  void render(Canvas canvas) {
    if (controller._sparkles.isEmpty) return;
    final cam = controller.cameraCenterGetter();
    final view = controller.viewBoundsGetter?.call().inflate(60.0) ??
        Rect.fromCenter(center: cam, width: 720, height: 680);

    for (final sp in controller._sparkles) {
      final pt = Offset(sp.x, sp.y);
      if (!view.contains(pt)) continue;
      final p = (sp.age / _FloatingBerrySparkle.maxAge).clamp(0.0, 1.0);
      final fade = (1.0 - p);
      final col = ElectricBlueberryExperienceController.spectrumColor(
        sp.hue + p * 0.35,
        alpha: fade * 0.88,
      );
      final r = 2.4 * (1.0 - p * 0.35);
      canvas.drawCircle(pt, r + 1.4, Paint()..color = col.withValues(alpha: fade * 0.28));
      canvas.drawCircle(pt, r, Paint()..color = col);
      canvas.drawCircle(
        pt.translate(-0.5, -0.5),
        r * 0.38,
        Paint()..color = Color.fromRGBO(255, 255, 255, fade * 0.85),
      );
    }
  }
}
