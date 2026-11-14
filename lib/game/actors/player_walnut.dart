import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';

import '../world/concert_light_show.dart';
import '../world/day_night_atmosphere.dart';
import '../world/tiled_map_parser.dart';
import 'stage_performer_director.dart';
import 'wardrobe_outfit_renderer.dart';

class PlayerWalnut extends PositionComponent {
  PlayerWalnut({
    required this.map,
    required this.spriteSheet,
    required Vector2 initialPosition,
    this.metricsGetter,
  }) : super(
          position: initialPosition,
          size: Vector2.all(32),
          anchor: Anchor.center,
        );

  final OrchardMapData map;
  Image spriteSheet;
  final DayNightMetrics Function()? metricsGetter;

  // Facing row in 96x128 sheet: 0=down, 1=left, 2=right, 3=up
  int _facingRow = 0;
  double _animClock = 0.0;
  double _stepSfxCooldown = 0.0;
  double _bellySlideTimer = 0.0;
  double _bellySlideCooldown = 0.0;
  final Vector2 _velocity = Vector2.zero();
  final Vector2 _slideDir = Vector2(0, 1);
  final List<(double, double)> _autoWalkPath = [];

  bool isSwaying = false;
  bool isDancing = false;
  int danceStyle = 0;
  StageShowFrame? activeMusicShow;
  double musicBass = 0.0;
  double musicMid = 0.0;
  double musicEnergy = 0.0;

  double crowdAura = 0.0;
  double mudSplatter = 0.0;
  bool lowGravityEnhanced = false;
  String equippedWardrobeId = 'tie_dye_tee';

  double _lastDanceBounceY = 0.0;
  int _lastRenderedFrameCol = 0;

  bool get hasActiveTapPath => _autoWalkPath.isNotEmpty;
  bool get isBellySliding => _bellySlideTimer > 0.0;
  Vector2 get velocity => _velocity;
  int get facingRow => _facingRow;
  double get lastDanceBounceY => _lastDanceBounceY;
  int get lastRenderedFrameCol => _lastRenderedFrameCol;

  Vector2 get facingUnitVector => switch (_facingRow) {
        1 => Vector2(-1, 0),
        2 => Vector2(1, 0),
        3 => Vector2(0, -1),
        _ => Vector2(0, 1),
      };

  bool _isNearSlipperyMud() {
    for (final (ox, oy) in const [
      (0.0, 0.0),
      (14.0, 0.0),
      (-14.0, 0.0),
      (0.0, 14.0),
      (0.0, -14.0),
    ]) {
      if (map.isSlipperyAtWorld(position.x + ox, position.y + oy)) {
        return true;
      }
    }
    return false;
  }

  /// Launches a joyful Woodstock Belly-Slide across muddy lanes & the Mud Pit Meadow!
  bool triggerMudSlide({
    Vector2? overrideDir,
    bool allowWetTurf = false,
  }) {
    if (_bellySlideCooldown > 0.0) return false;
    final onOrNearMud = _isNearSlipperyMud();
    if (!onOrNearMud && !allowWetTurf) return false;

    Vector2 dir;
    if (overrideDir != null && overrideDir.length2 > 0.01) {
      dir = overrideDir.normalized();
    } else if (_velocity.length2 > 16.0) {
      dir = _velocity.normalized();
    } else {
      dir = facingUnitVector;
    }

    _autoWalkPath.clear();
    isSwaying = false;
    _slideDir.setFrom(dir);
    _bellySlideTimer = onOrNearMud ? 0.74 : 0.48;
    _bellySlideCooldown = 0.50;
    final burstSpeed = onOrNearMud ? 218.0 : 170.0;
    _velocity.setFrom(dir * burstSpeed);
    mudSplatter = (mudSplatter + 0.38).clamp(0.0, 1.0);

    if (dir.x.abs() > dir.y.abs()) {
      _facingRow = dir.x < 0 ? 1 : 2;
    } else {
      _facingRow = dir.y < 0 ? 3 : 0;
    }
    return true;
  }

  void receiveMudSplat([double amount = 0.45]) {
    mudSplatter = (mudSplatter + amount).clamp(0.0, 1.0);
  }

  void updateSheet(Image nextSheet) {
    spriteSheet = nextSheet;
  }

  void setTapPath(List<(double, double)> path) {
    _autoWalkPath
      ..clear()
      ..addAll(path);
  }

  void clearTapPath() => _autoWalkPath.clear();

  /// Updates movement with surface physics (mud sliding, low-gravity dome bob) and returns step surface if SFX triggered.
  String? stepPhysics({
    required double dt,
    required Vector2 manualInput,
    required bool inputBlocked,
  }) {
    _animClock += dt;
    _bellySlideCooldown = math.max(0.0, _bellySlideCooldown - dt);
    final rainWash = (metricsGetter?.call().rainIntensity ?? 0.0) > 0.4;
    if (mudSplatter > 0.0 && !isBellySliding) {
      mudSplatter =
          math.max(0.0, mudSplatter - dt * (rainWash ? 0.16 : 0.018));
    }

    var desiredDir = Vector2.zero();
    if (!inputBlocked) {
      if (manualInput.length2 > 0.01) {
        _autoWalkPath.clear();
        desiredDir = manualInput.normalized();
      } else if (_autoWalkPath.isNotEmpty) {
        final (tx, ty) = _autoWalkPath.first;
        final toTarget = Vector2(tx - position.x, ty - position.y);
        if (toTarget.length < 6.0) {
          _autoWalkPath.removeAt(0);
        } else {
          desiredDir = toTarget.normalized();
        }
      }
    } else {
      _autoWalkPath.clear();
    }

    final onSlipperyMud = map.isSlipperyAtWorld(position.x, position.y);
    final inLowGravity = map.isLowGravityAtWorld(position.x, position.y);
    final baseSpeed = inLowGravity ? 84.0 : (onSlipperyMud ? 122.0 : 94.0);

    if (_bellySlideTimer > 0.0) {
      _bellySlideTimer = math.max(0.0, _bellySlideTimer - dt);
      if (desiredDir.length2 > 0.01) {
        _velocity.x += desiredDir.x * 74.0 * dt;
        _velocity.y += desiredDir.y * 74.0 * dt;
      }
      final drag = math.pow(onSlipperyMud ? 0.44 : 0.18, dt).toDouble();
      _velocity.scale(drag);
    } else if (onSlipperyMud) {
      // Woodstock mud-pit momentum drift: snappy push-off + buttery low-friction coasting!
      final targetVel = desiredDir * baseSpeed;
      final accelRate = desiredDir.length2 > 0.01 ? 3.5 : 1.55;
      final blend = (dt * accelRate).clamp(0.0, 1.0);
      _velocity.x += (targetVel.x - _velocity.x) * blend;
      _velocity.y += (targetVel.y - _velocity.y) * blend;
      if (desiredDir.length2 < 0.01 && _velocity.length < 6.0) {
        _velocity.setZero();
      }
    } else {
      _velocity.setFrom(desiredDir * baseSpeed);
    }

    var moving = _velocity.length2 > 4.0;
    if (moving) {
      isSwaying = false;
      if (_velocity.x.abs() > _velocity.y.abs()) {
        _facingRow = _velocity.x < 0 ? 1 : 2;
      } else {
        _facingRow = _velocity.y < 0 ? 3 : 0;
      }

      final nextX =
          (position.x + _velocity.x * dt).clamp(20.0, map.pixelWidth - 20.0);
      final nextY =
          (position.y + _velocity.y * dt).clamp(20.0, map.pixelHeight - 20.0);

      // Axis-separated collision resolution for crisp corner sliding
      if (!_collidesFootprint(nextX, position.y)) {
        position.x = nextX;
      } else {
        _velocity.x = 0;
      }
      if (!_collidesFootprint(position.x, nextY)) {
        position.y = nextY;
      } else {
        _velocity.y = 0;
      }
      moving = _velocity.length2 > 4.0;
    }

    // Y-sort priority across actors & props
    priority = position.y.round();

    if (moving) {
      _stepSfxCooldown -= dt;
      if (_stepSfxCooldown <= 0.0) {
        _stepSfxCooldown = onSlipperyMud ? 0.28 : 0.33;
        return map.surfaceAtWorld(position.x, position.y);
      }
    } else {
      _stepSfxCooldown = 0.05;
    }
    return null;
  }

  bool _collidesFootprint(double cx, double cy) {
    const halfW = 6.0;
    const footOffsetY = 6.0;
    return map.isPointBlocked(cx - halfW, cy + footOffsetY) ||
        map.isPointBlocked(cx + halfW, cy + footOffsetY) ||
        map.isPointBlocked(cx, cy + footOffsetY + 3.0);
  }

  @override
  void render(Canvas canvas) {
    final metrics = metricsGetter?.call() ?? DayNightMetrics.middayDefault;
    final inLowGravity = map.isLowGravityAtWorld(position.x, position.y);
    final onSlipperyMud = map.isSlipperyAtWorld(position.x, position.y);
    final moving = _velocity.length2 > 4.0;
    final show = activeMusicShow;

    // Beat-sync parameters locked to the active stage/turntable lightshow or 112 BPM groove!
    final double beatFloat;
    final int beatIdx;
    final double beatPhase;
    final double beatPulse;
    final int barBeat;
    final double effBass;
    final double effMid;
    final bool highEnergySection;
    if (show != null) {
      beatIdx = show.beatIndex;
      beatPhase = show.beatPhase;
      beatFloat = beatIdx + beatPhase;
      beatPulse = show.beatPulse;
      barBeat = show.barBeat;
      effBass = math.max(show.bass, musicBass);
      effMid = math.max(show.mid, musicMid);
      highEnergySection = show.kickDrop ||
          show.sectionMode == LightShowSectionMode.chorusAnthemy ||
          show.sectionMode == LightShowSectionMode.soloShred ||
          show.sectionMode == LightShowSectionMode.climaxPrism;
    } else {
      beatFloat = _animClock * (112.0 / 60.0);
      beatIdx = beatFloat.floor();
      beatPhase = beatFloat - beatIdx;
      beatPulse = math.pow(1.0 - beatPhase, 2.2).toDouble();
      barBeat = beatIdx % 4;
      effBass = math.max(0.32, musicBass);
      effMid = math.max(0.28, musicMid);
      highEnergySection = musicEnergy > 0.55 || barBeat == 0;
    }

    double danceBounceY = 0.0;
    double danceOffsetX = 0.0;
    double danceTilt = 0.0;
    double danceScaleX = 1.0;
    double danceScaleY = 1.0;
    int renderFacingRow = _facingRow;
    int? danceFrameCol;

    if (isDancing && !isBellySliding) {
      final style = danceStyle % 4;
      if (moving) {
        // Groovy beat-synced strut while repositioning on the dancefloor!
        danceBounceY = (1.6 + effBass * 2.0) * beatPulse;
        danceTilt = math.sin(beatFloat * math.pi) * 0.08;
      } else {
        switch (style) {
          case 0: // Boogie Bounce
            danceFrameCol = const [1, 0, 2, 0][beatIdx % 4];
            danceBounceY = (2.5 + effBass * 3.6) * beatPulse;
            danceOffsetX =
                math.sin(beatFloat * math.pi * 0.5) * (2.6 + effMid * 1.3);
            danceTilt = math.sin(beatFloat * math.pi * 0.5) * 0.14;
            danceScaleX = 1.0 + 0.07 * (1.0 - beatPulse) - 0.04 * beatPulse;
            danceScaleY = 1.0 + 0.07 * beatPulse - 0.05 * (1.0 - beatPulse);
            break;
          case 1: // Chubby Walnut Twist
            final halfStep = (beatFloat * 2.0).floor();
            danceFrameCol = halfStep.isEven ? 1 : 2;
            danceBounceY =
                (1.8 + effBass * 2.5) * math.sin(beatPhase * math.pi);
            danceOffsetX = math.sin(beatFloat * math.pi) * 3.0;
            danceTilt = -math.sin(beatFloat * math.pi) * 0.18;
            danceScaleX = 1.06;
            danceScaleY = 0.96 + 0.06 * beatPulse;
            if (_facingRow == 0) {
              renderFacingRow = const [0, 1, 0, 2][halfStep % 4];
            }
            break;
          case 2: // Santurce / Meadow Two-Step Shuffle
            final goingRight = barBeat >= 2;
            final stepProgress = ((barBeat % 2) + beatPhase) * 0.5;
            final sideCurve = math.sin(stepProgress * math.pi);
            danceOffsetX = (goingRight ? 1.0 : -1.0) * (1.2 + 2.8 * sideCurve);
            danceBounceY = (2.2 + effBass * 3.2) *
                (barBeat.isOdd ? beatPulse * 1.25 : beatPulse * 0.85);
            danceTilt = (goingRight ? 0.12 : -0.12) * sideCurve;
            danceFrameCol = beatPhase < 0.5 ? (goingRight ? 2 : 1) : 0;
            break;
          default: // Cosmic 360° Groove Spin
            const spinOrder = [0, 1, 3, 2];
            final spinRate = highEnergySection ? 2.0 : 1.0;
            renderFacingRow =
                spinOrder[(beatFloat * spinRate).floor() % spinOrder.length];
            danceFrameCol = const [1, 2, 1, 0][beatIdx % 4];
            danceBounceY = (3.0 + effBass * 4.0) * beatPulse +
                (barBeat == 3 ? 1.5 * math.sin(beatPhase * math.pi) : 0.0);
            danceOffsetX = math.cos(beatFloat * math.pi * 0.5) * 2.2;
            danceTilt = math.sin(beatFloat * math.pi) * 0.15;
            danceScaleY = 1.0 + 0.08 * beatPulse;
            break;
        }
      }
    }
    _lastDanceBounceY = danceBounceY;

    final strideHop =
        moving ? (math.sin(_animClock * 15.0).abs() * 1.3) : 0.0;
    final floatBob = (inLowGravity
            ? math.sin(_animClock * 3.2) * (lowGravityEnhanced ? 5.5 : 3.2)
            : 0.0) +
        strideHop +
        danceBounceY;
    final swayX =
        (isSwaying ? math.sin(_animClock * 4.5) * 2.5 : 0.0) + danceOffsetX;

    final primaryRingCol = show?.primaryColor ?? const Color(0xFFFFD166);
    final secondaryRingCol = show?.secondaryColor ?? const Color(0xFFFB5607);

    // 1. Dynamic solar/lunar 3D cast shadow beneath boots (+ beat spotlight rim when dancing!)
    renderActor3dShadow(
      canvas: canvas,
      metrics: metrics,
      centerX: 16.0 + swayX * 0.4,
      footY: 28.5,
      spotlightColor: isDancing ? primaryRingCol : null,
      haloIntensity: isDancing ? (0.28 + 0.42 * beatPulse) : 0.25,
    );

    // 1b. Beat-synced rhythm floor ring when Player Dance is active!
    if (isDancing && !isBellySliding) {
      final ringW = 19.0 + beatPulse * 9.0 + effBass * 5.0;
      final ringH = 6.8 + beatPulse * 3.2 + effBass * 1.8;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(16.0 + swayX * 0.45, 28.4),
          width: ringW,
          height: ringH,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3 + beatPulse * 0.9
          ..color = primaryRingCol.withValues(
            alpha: (0.42 + 0.45 * beatPulse).clamp(0.0, 0.92),
          ),
      );
      if (beatPulse > 0.35) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(16.0 + swayX * 0.45, 28.4),
            width: ringW * 0.68,
            height: ringH * 0.68,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = secondaryRingCol.withValues(
              alpha: (beatPulse * 0.65).clamp(0.0, 0.75),
            ),
        );
      }
    }

    // 2. Mud-pit splash droplets & Woodstock Belly-Slide bow spray!
    if (isBellySliding) {
      final wakePaint = Paint()..color = const Color(0xCC5C3A21);
      final highlightPaint = Paint()..color = const Color(0xBB9C6644);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(16, 27.5), width: 24, height: 8),
        wakePaint,
      );
      for (var i = 0; i < 6; i++) {
        final phase = (_animClock * 14.0 + i * 0.17) % 1.0;
        final side = (i.isEven ? -1.0 : 1.0);
        final sx = 16.0 + side * (8.0 + 9.0 * phase) - _velocity.x * 0.025;
        final sy = 26.5 - math.sin(phase * math.pi) * 6.5;
        canvas.drawCircle(
          Offset(sx, sy),
          1.9 * (1.0 - phase * 0.45),
          i.isEven ? wakePaint : highlightPaint,
        );
      }
    } else if (onSlipperyMud && moving) {
      final splashPaint = Paint()..color = const Color(0xBB7F5539);
      for (var i = 0; i < 4; i++) {
        final phase = (_animClock * 9.5 + i * 0.25) % 1.0;
        final sx = 16.0 - (_velocity.x * 0.06) + (i - 1.5) * 4.2 * phase;
        final sy = 27.5 - math.sin(phase * math.pi) * 4.6;
        canvas.drawCircle(
            Offset(sx, sy), 1.4 * (1.0 - phase * 0.5), splashPaint);
      }
    }

    // 3. Crowd Resonance / Slow-Wave Sway / Dance glowing aura + golden spore bursts!
    if (isSwaying || isDancing || crowdAura > 0.08) {
      final auraStrength = isDancing ? math.max(crowdAura, 0.36) : crowdAura;
      final radius =
          15.0 + auraStrength * 10.0 + math.sin(_animClock * 5.0) * 1.5;
      canvas.drawCircle(
        Offset(16 + swayX, 18 - floatBob),
        radius,
        Paint()
          ..color = (isDancing ? primaryRingCol : const Color(0xFFFFD166))
              .withValues(
            alpha: (0.14 + 0.30 * auraStrength + (isDancing ? 0.10 * beatPulse : 0.0))
                .clamp(0.0, 0.55),
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      if (crowdAura > 0.65) {
        final sporePaint = Paint()..color = const Color(0xDDFFD166);
        for (var i = 0; i < 6; i++) {
          final ang = _animClock * 2.2 + (i * math.pi / 3.0);
          final orbitR = 14.0 + 7.0 * ((_animClock * 1.3 + i * 0.27) % 1.0);
          final sx = 16 + swayX + math.cos(ang) * orbitR;
          final sy = 15 - floatBob + math.sin(ang) * (orbitR * 0.7) - 3.0;
          canvas.drawCircle(Offset(sx, sy), 1.6, sporePaint);
        }
      }
    }

    if (inLowGravity) {
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(16, 29), width: 16, height: 6),
        Paint()..color = const Color(0x6664DFDF),
      );
    }

    final frameCol = moving
        ? (1 + ((_animClock * 8.0).floor() % 2))
        : (danceFrameCol ?? 0);
    _lastRenderedFrameCol = frameCol;
    final src = Rect.fromLTWH(
      frameCol * 32.0,
      renderFacingRow * 32.0,
      32.0,
      32.0,
    );

    canvas.save();
    if (isBellySliding) {
      // Forward belly-surf dive pose!
      final tilt = (_slideDir.x * 0.28).clamp(-0.30, 0.30);
      canvas.translate(16.0 + swayX, 23.5);
      canvas.rotate(tilt);
      canvas.scale(1.14, 0.80);
      canvas.translate(-(16.0 + swayX), -23.5);
    } else if (isDancing &&
        (danceTilt.abs() > 0.005 ||
            (danceScaleX - 1.0).abs() > 0.005 ||
            (danceScaleY - 1.0).abs() > 0.005)) {
      final pivotX = 16.0 + swayX;
      final pivotY = 26.0 - floatBob * 0.25;
      canvas.translate(pivotX, pivotY);
      canvas.rotate(danceTilt);
      canvas.scale(danceScaleX, danceScaleY);
      canvas.translate(-pivotX, -pivotY);
    }

    final dst = Rect.fromLTWH(
      swayX,
      isBellySliding ? 2.5 : -floatBob,
      32.0,
      32.0,
    );
    canvas.drawImageRect(
      spriteSheet,
      src,
      dst,
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );

    // Render equipped 1969 Woodstock outfit across all 16 starter + quest items!
    renderWalnutWardrobeOutfit(
      canvas,
      wardrobeId: equippedWardrobeId,
      facingRow: renderFacingRow,
      offsetX: swayX,
      liftY: isBellySliding ? -2.5 : floatBob,
      animClock: _animClock,
    );

    // Raised cheering groove hands on big downbeats & choruses!
    if (isDancing && !moving && !isBellySliding && highEnergySection && beatPulse > 0.32) {
      final handFill = Paint()..color = const Color(0xFFD99E5B);
      final handOutline = Paint()..color = const Color(0xFF1C110A);
      final handLift = floatBob + 2.5 * beatPulse;
      for (final hx in [7.2 + swayX, 24.8 + swayX]) {
        canvas.drawCircle(Offset(hx, 13.5 - handLift), 2.3, handOutline);
        canvas.drawCircle(Offset(hx, 13.5 - handLift), 1.6, handFill);
      }
    }

    // Render glossy cocoa mud-fight splatter flecks on shell when muddied!
    if (mudSplatter > 0.06) {
      final fleckAlpha = (mudSplatter * 0.88).clamp(0.18, 0.88);
      final mudDark = Paint()..color = Color.fromRGBO(74, 44, 24, fleckAlpha);
      final mudSpec =
          Paint()..color = Color.fromRGBO(156, 102, 68, fleckAlpha * 0.85);
      final lift = isBellySliding ? -2.5 : floatBob;
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(12.5 + swayX, 19.5 - lift), width: 4.2, height: 2.8),
        mudDark,
      );
      canvas.drawCircle(Offset(12.0 + swayX, 19.0 - lift), 0.9, mudSpec);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(19.5 + swayX, 16.5 - lift), width: 3.6, height: 2.5),
        mudDark,
      );
      if (mudSplatter > 0.45) {
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(15.5 + swayX, 22.5 - lift),
              width: 4.8,
              height: 2.6),
          mudDark,
        );
        canvas.drawCircle(Offset(19.2 + swayX, 16.1 - lift), 0.8, mudSpec);
      }
    }
    canvas.restore();

    // Floating beat-synced music notes rising from the dancing player!
    if (isDancing && !isBellySliding) {
      for (var n = 0; n < 2; n++) {
        final notePhase = ((beatFloat * 0.5) + n * 0.5) % 1.0;
        final alpha = (1.0 - notePhase).clamp(0.0, 1.0);
        final nx = 16.0 +
            swayX +
            (n == 0 ? -9.5 : 9.5) +
            math.sin(notePhase * math.pi * 2.0 + n) * 2.2;
        final ny = 8.0 - floatBob - notePhase * 11.5;
        final col = (n == 0 ? primaryRingCol : secondaryRingCol)
            .withValues(alpha: (0.88 * alpha).clamp(0.0, 0.92));
        _drawMusicNoteGlyph(canvas, Offset(nx, ny), col);
      }
    }
  }

  static void _drawMusicNoteGlyph(Canvas canvas, Offset pos, Color color) {
    final p = Paint()..color = color;
    canvas.drawOval(
      Rect.fromCenter(center: pos, width: 3.2, height: 2.4),
      p,
    );
    canvas.drawRect(
      Rect.fromLTWH(pos.dx + 0.9, pos.dy - 4.4, 1.0, 4.4),
      p,
    );
    canvas.drawRect(
      Rect.fromLTWH(pos.dx + 1.0, pos.dy - 4.4, 2.4, 1.1),
      p,
    );
  }
}
