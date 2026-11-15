import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';

import 'stage_3d_rig_component.dart';

class CrowdBeachBall {
  CrowdBeachBall({
    required this.id,
    required this.homeCenter,
    required this.boundsRadius,
  })  : x = homeCenter.dx,
        y = homeCenter.dy;

  final String id;
  final Offset homeCenter;
  final double boundsRadius;

  double x;
  double y;
  double z = 14.0;
  double vx = 18.0;
  double vy = -12.0;
  double vz = 48.0;
  double spinAngle = 0.0;
  int rallyCount = 0;
  double playerHitCooldown = 0.0;
  double npcHitCooldown = 0.0;
}

class _SoapBubbleParticle {
  _SoapBubbleParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.maxLife,
    required this.hueShift,
  });

  double x;
  double y;
  final double vx;
  final double vy;
  final double radius;
  final double maxLife;
  final double hueShift;
  double age = 0.0;
}

class _SparkParticle {
  _SparkParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.maxLife,
    required this.color,
  });

  double x;
  double y;
  double vx;
  double vy;
  final double maxLife;
  final Color color;
  double age = 0.0;
}

class _SonicRing {
  _SonicRing({
    required this.x,
    required this.y,
    required this.color,
  });

  final double x;
  final double y;
  final Color color;
  double age = 0.0;
  static const double maxLife = 0.85;
}

class _FloatingPolaroid {
  _FloatingPolaroid({
    required this.x,
    required this.y,
    required this.caption,
  });

  final double x;
  final double y;
  final String caption;
  double age = 0.0;
  static const double maxLife = 1.9;
}

class GroundPeaceBeadSpot {
  const GroundPeaceBeadSpot({
    required this.id,
    required this.x,
    required this.y,
    this.amount = 3,
  });

  final String id;
  final double x;
  final double y;
  final int amount;
}

/// Renders and steps interactive 1969 festival ground & crowd props:
/// - Deployable Woven Picnic Blanket
/// - Glinting Lost Brass Festival Compass & dropped Peace Bead strands
/// - 3D Crowd Beach Ball Volley in Main Roots & Mellow Meadow stage bowls
/// - Soap Bubble Wand spheres, Polaroid shutter flash + rising instant photo,
///   Tambourine sonic ripples, and Encore Sparkler golden sparks
class FestivalPropsComponent extends Component {
  FestivalPropsComponent({
    required this.beachBallSprite,
    required this.compassSprite,
    required this.picnicBlanketSprite,
  }) : super(priority: 1580);

  final Image beachBallSprite;
  final Image compassSprite;
  final Image picnicBlanketSprite;

  static const List<GroundPeaceBeadSpot> peaceBeadSpots = [
    GroundPeaceBeadSpot(id: 'beads_gate_lane', x: 608.0, y: 1264.0, amount: 3),
    GroundPeaceBeadSpot(
        id: 'beads_crossroads', x: 608.0, y: 1088.0, amount: 3),
    GroundPeaceBeadSpot(
        id: 'beads_main_roots', x: 704.0, y: 512.0, amount: 3),
    GroundPeaceBeadSpot(id: 'beads_meadow', x: 1056.0, y: 624.0, amount: 4),
    GroundPeaceBeadSpot(id: 'beads_velvet', x: 288.0, y: 624.0, amount: 3),
    GroundPeaceBeadSpot(
        id: 'beads_campground', x: 1024.0, y: 1104.0, amount: 4),
  ];

  static const Offset lostCompassWorldPos = Offset(496.0, 624.0);

  final List<CrowdBeachBall> beachBalls = [
    CrowdBeachBall(
      id: 'ball_main_roots',
      homeCenter: const Offset(604.0, 484.0),
      boundsRadius: 96.0,
    ),
    CrowdBeachBall(
      id: 'ball_mellow_meadow',
      homeCenter: const Offset(1160.0, 504.0),
      boundsRadius: 92.0,
    ),
  ];

  final List<_SoapBubbleParticle> _bubbles = [];
  final List<_SparkParticle> _sparks = [];
  final List<_SonicRing> _rings = [];
  final List<_FloatingPolaroid> _polaroids = [];
  final math.Random _rng = math.Random(1969);

  double _clock = 0.0;
  double _shutterFlashAlpha = 0.0;
  Offset _shutterFlashOrigin = Offset.zero;
  double _sparkEmitAccum = 0.0;

  bool compassVisible = true;
  Set<String> collectedBeadIds = const {};
  bool picnicBlanketVisible = false;
  Offset picnicBlanketCenter = Offset.zero;

  int get activeBubbleCount => _bubbles.length;
  int get activePolaroidCount => _polaroids.length;
  int get activeRingCount => _rings.length;

  void spawnBubbleBurst(Offset origin, {bool lowGravity = false}) {
    final count = lowGravity ? 14 : 10;
    for (var i = 0; i < count; i++) {
      final ang = (i / count) * math.pi * 2.0 + (_rng.nextDouble() - 0.5) * 0.4;
      final speed = 12.0 + _rng.nextDouble() * 22.0;
      _bubbles.add(
        _SoapBubbleParticle(
          x: origin.dx + math.cos(ang) * 6.0,
          y: origin.dy - 8.0 + math.sin(ang) * 4.0,
          vx: math.cos(ang) * speed + 6.0,
          vy: math.sin(ang) * speed * 0.55 - (lowGravity ? 18.0 : 12.0),
          radius: 2.6 + _rng.nextDouble() * 3.0,
          maxLife: lowGravity ? 3.8 : 2.5,
          hueShift: i / count,
        ),
      );
    }
  }

  void spawnPolaroidFlash(Offset origin, String caption) {
    _shutterFlashAlpha = 1.0;
    _shutterFlashOrigin = origin;
    _polaroids.add(
      _FloatingPolaroid(
        x: origin.dx,
        y: origin.dy - 20.0,
        caption: caption,
      ),
    );
  }

  void spawnTambourineRipple(Offset origin, {Color? accent}) {
    final col = accent ?? const Color(0xFFFFD166);
    _rings.add(_SonicRing(x: origin.dx, y: origin.dy - 6.0, color: col));
    for (var i = 0; i < 8; i++) {
      final a = (i / 8.0) * math.pi * 2.0;
      _sparks.add(
        _SparkParticle(
          x: origin.dx + math.cos(a) * 8.0,
          y: origin.dy - 8.0 + math.sin(a) * 5.0,
          vx: math.cos(a) * 34.0,
          vy: math.sin(a) * 24.0 - 14.0,
          maxLife: 0.55,
          color: i.isEven ? const Color(0xFFFFF3B0) : col,
        ),
      );
    }
  }

  void spawnCelebrationSparks(Offset origin) {
    const palette = [
      Color(0xFFFF595E),
      Color(0xFFFFCA3A),
      Color(0xFF8AC926),
      Color(0xFF4CC9F0),
      Color(0xFFE0AAFF),
    ];
    for (var i = 0; i < 12; i++) {
      final a = (i / 12.0) * math.pi * 2.0;
      _sparks.add(
        _SparkParticle(
          x: origin.dx,
          y: origin.dy - 10.0,
          vx: math.cos(a) * (28.0 + _rng.nextDouble() * 20.0),
          vy: math.sin(a) * 24.0 - 24.0,
          maxLife: 0.70,
          color: palette[i % palette.length],
        ),
      );
    }
  }

  /// Steps beach-ball volley physics, returning `(rallyCount, ballId)` whenever the player bumps a ball!
  (int, String)? stepSimulation({
    required double dt,
    required Offset playerPos,
    required Offset playerVelocity,
    required bool playerDancing,
    required bool sparklerLit,
    required List<Offset> crowdDancerPositions,
  }) {
    _clock += dt;
    if (_shutterFlashAlpha > 0.0) {
      _shutterFlashAlpha = math.max(0.0, _shutterFlashAlpha - dt * 3.4);
    }

    if (sparklerLit) {
      _sparkEmitAccum += dt;
      while (_sparkEmitAccum >= 0.045) {
        _sparkEmitAccum -= 0.045;
        final a = _rng.nextDouble() * math.pi * 2.0;
        final spd = 14.0 + _rng.nextDouble() * 26.0;
        _sparks.add(
          _SparkParticle(
            x: playerPos.dx + 8.5,
            y: playerPos.dy - 14.0,
            vx: math.cos(a) * spd,
            vy: math.sin(a) * spd - 16.0,
            maxLife: 0.42 + _rng.nextDouble() * 0.25,
            color: _rng.nextBool()
                ? const Color(0xFFFFF3B0)
                : const Color(0xFFFF9F1C),
          ),
        );
      }
    }

    for (var i = _bubbles.length - 1; i >= 0; i--) {
      final b = _bubbles[i];
      b.age += dt;
      if (b.age >= b.maxLife) {
        _bubbles.removeAt(i);
        continue;
      }
      b.x += (b.vx + math.sin(_clock * 4.0 + i) * 8.0) * dt;
      b.y += b.vy * dt;
    }

    for (var i = _sparks.length - 1; i >= 0; i--) {
      final s = _sparks[i];
      s.age += dt;
      if (s.age >= s.maxLife) {
        _sparks.removeAt(i);
        continue;
      }
      s.vy += 58.0 * dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
    }

    for (var i = _rings.length - 1; i >= 0; i--) {
      _rings[i].age += dt;
      if (_rings[i].age >= _SonicRing.maxLife) {
        _rings.removeAt(i);
      }
    }

    for (var i = _polaroids.length - 1; i >= 0; i--) {
      _polaroids[i].age += dt;
      if (_polaroids[i].age >= _FloatingPolaroid.maxLife) {
        _polaroids.removeAt(i);
      }
    }

    (int, String)? playerHitEvent;
    for (final ball in beachBalls) {
      ball.playerHitCooldown = math.max(0.0, ball.playerHitCooldown - dt);
      ball.npcHitCooldown = math.max(0.0, ball.npcHitCooldown - dt);

      // Floaty beach-ball gravity
      ball.vz -= 68.0 * dt;
      ball.x += ball.vx * dt;
      ball.y += ball.vy * dt;
      ball.z += ball.vz * dt;
      ball.spinAngle += (ball.vx * 0.05) * dt;

      // Keep gently tethered inside stage crowd bowl
      final dxHome = ball.x - ball.homeCenter.dx;
      final dyHome = ball.y - ball.homeCenter.dy;
      final distHome = math.sqrt(dxHome * dxHome + dyHome * dyHome);
      if (distHome > ball.boundsRadius && distHome > 0.01) {
        final nx = dxHome / distHome;
        final ny = dyHome / distHome;
        ball.x = ball.homeCenter.dx + nx * ball.boundsRadius;
        ball.y = ball.homeCenter.dy + ny * ball.boundsRadius;
        ball.vx = -nx * 26.0;
        ball.vy = -ny * 22.0;
      }

      // Ground bounce resets rally streak if nobody kept it up!
      if (ball.z <= 0.0) {
        ball.z = 0.0;
        if (ball.vz.abs() > 14.0) {
          ball.vz = ball.vz.abs() * 0.66;
        } else {
          ball.vz = 42.0;
        }
        ball.vx *= 0.82;
        ball.vy *= 0.82;
        ball.rallyCount = 0;
      }

      // Player bump / dance header!
      final dxP = ball.x - playerPos.dx;
      final dyP = ball.y - playerPos.dy;
      final distP = math.sqrt(dxP * dxP + dyP * dyP);
      if (ball.playerHitCooldown <= 0.0 && distP <= 28.0 && ball.z <= 34.0) {
        ball.playerHitCooldown = 0.42;
        ball.rallyCount += 1;
        final pushX = playerVelocity.dx.abs() > 5.0
            ? playerVelocity.dx * 0.48
            : (dxP.abs() > 1.0 ? (dxP / math.max(1.0, distP)) * 38.0 : 24.0);
        final pushY = playerVelocity.dy.abs() > 5.0
            ? playerVelocity.dy * 0.48
            : (dyP.abs() > 1.0 ? (dyP / math.max(1.0, distP)) * 32.0 : -26.0);
        ball.vx = pushX.clamp(-65.0, 65.0);
        ball.vy = pushY.clamp(-55.0, 55.0);
        ball.vz = playerDancing ? 72.0 : 60.0;
        spawnCelebrationSparks(Offset(ball.x, ball.y - ball.z));
        playerHitEvent = (ball.rallyCount, ball.id);
        continue;
      }

      // Nearby crowd NPCs volley the beach ball back across the dancefloor!
      if (ball.npcHitCooldown <= 0.0 && ball.z <= 20.0 && ball.vz < 0.0) {
        for (final npcPos in crowdDancerPositions) {
          final dxN = ball.x - npcPos.dx;
          final dyN = ball.y - npcPos.dy;
          if (dxN * dxN + dyN * dyN <= 32.0 * 32.0) {
            ball.npcHitCooldown = 0.65;
            final toHomeX = ball.homeCenter.dx - ball.x;
            final toHomeY = ball.homeCenter.dy - ball.y;
            ball.vx =
                (toHomeX * 0.55 + (_rng.nextDouble() - 0.5) * 32.0).clamp(-48.0, 48.0);
            ball.vy =
                (toHomeY * 0.55 + (_rng.nextDouble() - 0.5) * 28.0).clamp(-42.0, 42.0);
            ball.vz = 56.0;
            break;
          }
        }
      }
    }
    return playerHitEvent;
  }

  @override
  void render(Canvas canvas) {
    final crispPaint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;

    // 1. Deployable Woven Picnic Blanket
    if (picnicBlanketVisible) {
      final src = Rect.fromLTWH(
        0,
        0,
        picnicBlanketSprite.width.toDouble(),
        picnicBlanketSprite.height.toDouble(),
      );
      final dst = Rect.fromCenter(
        center: Offset(picnicBlanketCenter.dx, picnicBlanketCenter.dy + 8.0),
        width: 48.0,
        height: 36.0,
      );
      canvas.drawImageRect(picnicBlanketSprite, src, dst, crispPaint);
    }

    // 2. Dropped Peace Bead Strands on Orchard Paths
    const beadCols = [
      Color(0xFFFF595E),
      Color(0xFFFFCA3A),
      Color(0xFF8AC926),
      Color(0xFF4CC9F0),
    ];
    for (final spot in peaceBeadSpots) {
      if (collectedBeadIds.contains(spot.id)) continue;
      final pulse = 0.65 + 0.35 * math.sin(_clock * 4.5 + spot.x * 0.05);
      canvas.drawCircle(
        Offset(spot.x, spot.y),
        7.0,
        Paint()..color = Color.fromRGBO(255, 209, 102, 0.22 * pulse),
      );
      for (var b = 0; b < 4; b++) {
        final a = (b / 4.0) * math.pi * 2.0 + _clock * 0.9;
        canvas.drawCircle(
          Offset(spot.x + math.cos(a) * 3.2, spot.y + math.sin(a) * 2.4),
          1.5,
          Paint()..color = beadCols[b],
        );
      }
    }

    // 3. Fern Whisper-Shell's Lost Brass Festival Compass
    if (compassVisible) {
      final bob = math.sin(_clock * 3.8) * 1.6;
      final glint = (math.sin(_clock * 6.5) * 0.5 + 0.5);
      canvas.drawCircle(
        lostCompassWorldPos,
        9.5,
        Paint()..color = Color.fromRGBO(255, 214, 102, 0.25 + 0.25 * glint),
      );
      canvas.drawImageRect(
        compassSprite,
        Rect.fromLTWH(
          0,
          0,
          compassSprite.width.toDouble(),
          compassSprite.height.toDouble(),
        ),
        Rect.fromCenter(
          center: Offset(lostCompassWorldPos.dx, lostCompassWorldPos.dy - bob),
          width: 16.0,
          height: 16.0,
        ),
        crispPaint,
      );
    }

    // 4. 3D Crowd Beach Balls (ground shadow + airborne spinning ball + rally badge)
    final ballSrc = Rect.fromLTWH(
      0,
      0,
      beachBallSprite.width.toDouble(),
      beachBallSprite.height.toDouble(),
    );
    for (final ball in beachBalls) {
      final shadowScale = (1.0 - (ball.z / 95.0)).clamp(0.38, 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(ball.x, ball.y + 8.0),
          width: 18.0 * shadowScale,
          height: 7.0 * shadowScale,
        ),
        Paint()..color = Color.fromRGBO(0, 0, 0, 0.34 * shadowScale),
      );

      final drawY = ball.y - ball.z;
      canvas.save();
      canvas.translate(ball.x, drawY);
      canvas.rotate(ball.spinAngle);
      canvas.drawImageRect(
        beachBallSprite,
        ballSrc,
        Rect.fromCenter(center: Offset.zero, width: 22.0, height: 22.0),
        crispPaint,
      );
      canvas.restore();

      if (ball.rallyCount >= 2) {
        renderCenteredWorldPill(
          canvas: canvas,
          center: Offset(ball.x, drawY - 15.0),
          text: 'x${ball.rallyCount}',
          fontSize: 6.2,
          textColor: const Color(0xFFFFF3B0),
          backgroundColor: const Color(0xCC3A0CA3),
          horizontalPadding: 4.5,
          pillHeight: 11.0,
          minPillWidth: 18.0,
          maxPillWidth: 44.0,
          borderRadius: 5.0,
        );
      }
    }

    // 5. Tambourine Sonic Ripples
    for (final ring in _rings) {
      final t = (ring.age / _SonicRing.maxLife).clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(ring.x, ring.y),
          width: 16.0 + t * 56.0,
          height: 8.0 + t * 26.0,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 * (1.0 - t)
          ..color = ring.color.withValues(alpha: (0.85 * (1.0 - t)).clamp(0.0, 0.9)),
      );
    }

    // 6. Iridescent Soap Bubbles
    const rimPalette = [
      Color(0xCC80FFDB),
      Color(0xCCFFAFCC),
      Color(0xCCFFD166),
      Color(0xCCBDB2FF),
    ];
    for (var i = 0; i < _bubbles.length; i++) {
      final b = _bubbles[i];
      final fade = (1.0 - (b.age / b.maxLife)).clamp(0.0, 1.0);
      final rim = rimPalette[i % rimPalette.length]
          .withValues(alpha: (0.78 * fade).clamp(0.0, 0.85));
      canvas.drawCircle(
        Offset(b.x, b.y),
        b.radius,
        Paint()..color = Color.fromRGBO(224, 251, 252, 0.18 * fade),
      );
      canvas.drawCircle(
        Offset(b.x, b.y),
        b.radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = rim,
      );
      canvas.drawCircle(
        Offset(b.x - b.radius * 0.35, b.y - b.radius * 0.35),
        b.radius * 0.25,
        Paint()..color = Color.fromRGBO(255, 255, 255, 0.85 * fade),
      );
    }

    // 7. Sparkler & Celebration Sparks
    for (final s in _sparks) {
      final fade = (1.0 - (s.age / s.maxLife)).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(s.x, s.y),
        1.4 * fade + 0.4,
        Paint()..color = s.color.withValues(alpha: fade),
      );
    }

    // 8. Polaroid Shutter Flash & Rising Snapshot Card
    if (_shutterFlashAlpha > 0.0) {
      canvas.drawCircle(
        _shutterFlashOrigin,
        46.0 * (1.2 - _shutterFlashAlpha * 0.4),
        Paint()
          ..color = Color.fromRGBO(255, 250, 235, 0.55 * _shutterFlashAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    for (final p in _polaroids) {
      final t = (p.age / _FloatingPolaroid.maxLife).clamp(0.0, 1.0);
      final fade = t < 0.75 ? 1.0 : ((1.0 - t) / 0.25).clamp(0.0, 1.0);
      final cy = p.y - t * 22.0;
      final cardRect =
          Rect.fromCenter(center: Offset(p.x, cy), width: 22.0, height: 25.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(cardRect, const Radius.circular(2.0)),
        Paint()..color = Color.fromRGBO(252, 249, 240, 0.95 * fade),
      );
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset(p.x, cy - 2.2), width: 17.6, height: 15.6),
        Paint()..color = Color.fromRGBO(114, 9, 183, 0.90 * fade),
      );
      canvas.drawCircle(
        Offset(p.x, cy - 2.2),
        4.2,
        Paint()..color = Color.fromRGBO(255, 209, 102, 0.92 * fade),
      );
    }
  }
}
