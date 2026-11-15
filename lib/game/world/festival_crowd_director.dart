import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/models.dart';
import '../../state/festival_clock.dart';
import '../../state/world_flags.dart';
import '../actors/npc_actor.dart';
import '../actors/stage_performer_director.dart';
import '../actors/wardrobe_outfit_renderer.dart';
import 'astar_pathfinder.dart';
import 'concert_light_show.dart';
import 'day_night_atmosphere.dart';
import 'stage_3d_rig_component.dart';
import 'tiled_map_parser.dart';

enum FestivalCrowdActivity {
  wanderingToStage,
  dancingAtStage,
  sittingOnBlanket,
  walkingToFoodLine,
  queuingInFoodLine,
  strollingOrchard,
}

class FestivalBlanketSpot {
  const FestivalBlanketSpot({
    required this.id,
    required this.zoneLabel,
    required this.center,
    required this.seats,
    required this.minDay,
    required this.trimColor,
    required this.propKind,
    this.preferredStageId,
    this.isPlayerBlanket = false,
  });

  final String id;
  final String zoneLabel;
  final Offset center;
  final List<Offset> seats;
  final int minDay;
  final Color trimColor;
  final String propKind; // 'thermos' | 'basket' | 'songbook' | 'tea'
  final String? preferredStageId;
  final bool isPlayerBlanket;
}

class FoodStallSpec {
  const FoodStallSpec({
    required this.id,
    required this.displayName,
    required this.counterPos,
    required this.queueSlots,
    required this.menuTreats,
  });

  final String id;
  final String displayName;
  final Offset counterPos;
  final List<Offset> queueSlots;
  final List<(String, String)> menuTreats;
}

class FoodStallQueueState {
  FoodStallQueueState(this.spec);

  final FoodStallSpec spec;
  final List<String> memberKeys = [];
  double serviceTimerSec = 0.0;
  int servedCount = 0;

  int get length => memberKeys.length;
  bool get isFull => memberKeys.length >= spec.queueSlots.length;

  int indexOf(String key) => memberKeys.indexOf(key);

  Offset slotPositionFor(int slotIndex) {
    final clamped = slotIndex.clamp(0, spec.queueSlots.length - 1);
    return spec.queueSlots[clamped];
  }
}

class FestivalGoerSpec {
  const FestivalGoerSpec({
    required this.id,
    required this.name,
    required this.title,
    required this.cultivarId,
    required this.voicePitch,
    required this.minDay,
    required this.homePos,
    required this.day1WardrobeId,
    required this.day2WardrobeId,
    required this.day3WardrobeId,
    required this.favoriteStageId,
    required this.personalityTag,
  });

  final String id;
  final String name;
  final String title;
  final String cultivarId;
  final String voicePitch;
  final int minDay;
  final Offset homePos;
  final String day1WardrobeId;
  final String day2WardrobeId;
  final String day3WardrobeId;
  final String favoriteStageId;
  final String personalityTag;

  String get portraitAsset =>
      'assets/images/characters/cultivar_${cultivarId}_portrait.png';

  String wardrobeForDay(int day) {
    if (day <= 1) return day1WardrobeId;
    if (day == 2) return day2WardrobeId;
    return day3WardrobeId;
  }
}

/// Ground-level woven festival blankets unrolled progressively across Days 1, 2, and 3.
class FestivalBlanketsGroundComponent extends Component {
  FestivalBlanketsGroundComponent({
    required this.director,
    required this.picnicBlanketSprite,
    required this.metricsGetter,
    required this.viewBoundsGetter,
    required this.timeGetter,
    super.priority = -4100,
  });

  final FestivalCrowdDirector director;
  final Image picnicBlanketSprite;
  final DayNightMetrics Function() metricsGetter;
  final Rect Function() viewBoundsGetter;
  final double Function() timeGetter;

  @override
  void render(Canvas canvas) {
    final view = viewBoundsGetter().inflate(96.0);
    final metrics = metricsGetter();
    final t = timeGetter();
    final src = Rect.fromLTWH(
      0,
      0,
      picnicBlanketSprite.width.toDouble(),
      picnicBlanketSprite.height.toDouble(),
    );
    final crispPaint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;

    for (final spot in director.activeBlanketSpots) {
      // Player's own deployable blanket is already rendered by FestivalPropsComponent
      if (spot.isPlayerBlanket) continue;
      if (!view.contains(spot.center)) continue;

      final dst = Rect.fromCenter(
        center: spot.center.translate(0.0, 4.0),
        width: 46.0,
        height: 34.0,
      );

      // Soft ground shadow beneath woven blanket
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          dst.shift(Offset(metrics.shadowOffset.dx * 0.25, 2.0)),
          const Radius.circular(3.0),
        ),
        Paint()..color = const Color(0x40090E0B),
      );

      // Woven color border trim
      canvas.drawRRect(
        RRect.fromRectAndRadius(dst.inflate(1.6), const Radius.circular(3.0)),
        Paint()..color = spot.trimColor.withValues(alpha: 0.82),
      );

      canvas.drawImageRect(picnicBlanketSprite, src, dst, crispPaint);

      // Fringe tassels on left & right edges
      final fringePaint = Paint()..color = const Color(0xEDEFE5DC);
      for (var fy = dst.top + 3.0; fy <= dst.bottom - 3.0; fy += 5.0) {
        canvas.drawRect(Rect.fromLTWH(dst.left - 3.0, fy, 2.2, 1.3), fringePaint);
        canvas.drawRect(
            Rect.fromLTWH(dst.right + 0.8, fy, 2.2, 1.3), fringePaint);
      }

      // Cozy 1969 blanket center prop when dry
      if (metrics.rainIntensity < 0.55) {
        final px = spot.center.dx;
        final py = spot.center.dy + 3.0;
        switch (spot.propKind) {
          case 'thermos':
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(px, py), width: 4.5, height: 7.5),
                const Radius.circular(1.4),
              ),
              Paint()..color = const Color(0xFFE63946),
            );
            canvas.drawRect(
              Rect.fromCenter(
                  center: Offset(px, py - 3.2), width: 4.2, height: 1.8),
              Paint()..color = const Color(0xFFE9ECEF),
            );
            break;
          case 'basket':
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(px, py), width: 8.5, height: 6.0),
                const Radius.circular(1.6),
              ),
              Paint()..color = const Color(0xFFC68B59),
            );
            canvas.drawRect(
              Rect.fromCenter(
                  center: Offset(px, py - 1.2), width: 7.5, height: 1.4),
              Paint()..color = const Color(0xFFFFF8E7),
            );
            break;
          case 'tea':
            final steam = math.sin(t * 3.2 + px) * 1.1;
            canvas.drawCircle(
              Offset(px, py),
              2.8,
              Paint()..color = const Color(0xFF48CAE4),
            );
            canvas.drawCircle(
              Offset(px + steam * 0.5, py - 4.0),
              1.1,
              Paint()..color = const Color(0x66FFFFFF),
            );
            break;
          default:
            // Acoustic songbook / vinyl sleeve
            canvas.drawRect(
              Rect.fromCenter(center: Offset(px, py), width: 7.5, height: 6.5),
              Paint()..color = const Color(0xFFFFBE0B),
            );
            canvas.drawCircle(
              Offset(px, py),
              1.8,
              Paint()..color = const Color(0xFF1C110A),
            );
            break;
        }
      } else {
        // Damp rain sheen when storming
        canvas.drawRRect(
          RRect.fromRectAndRadius(dst, const Radius.circular(2.5)),
          Paint()..color = const Color(0x381D3557),
        );
      }
    }
  }
}

/// Autonomous 1969 Woodstock festivalgoer actor that wanders between stages,
/// lounges on blankets, queues for Vendor Row street food, dances, and chats!
class FestivalGoerActor extends PositionComponent {
  FestivalGoerActor({
    required this.spec,
    required this.map,
    required this.spriteSheet,
    required this.metricsGetter,
  }) : super(
          position: Vector2(spec.homePos.dx, spec.homePos.dy),
          size: Vector2.all(32),
          anchor: Anchor.center,
        );

  final FestivalGoerSpec spec;
  final OrchardMapData map;
  final Image spriteSheet;
  final DayNightMetrics Function() metricsGetter;

  bool isPresentToday = true;
  String activeWardrobeId = 'none';
  FestivalCrowdActivity activity = FestivalCrowdActivity.strollingOrchard;
  Offset? targetPoint;
  int? facingOverride;
  String? targetStageId;
  String? targetBlanketId;
  int? blanketSeatIndex;
  String? targetFoodStallId;
  int? foodQueueSlot;

  StageShowFrame? nearbyStageShow;
  Offset? nearbyStagePos;
  CrowdReactionKind performanceReaction = CrowdReactionKind.none;
  bool holdingConcertLighter = false;
  double mudPatina = 0.0;

  String? heldTreatEmoji;
  double _heldTreatTimer = 0.0;
  String? reactionCalloutText;
  double _reactionCalloutTimer = 0.0;
  double _reactionCalloutDuration = 2.2;

  double _animClock = 0.0;
  int _facingRow = 0;
  bool _moving = false;
  bool _grooving = false;
  double _bassLevel = 0.0;
  Offset? _plannedGoal;
  final List<(double, double)> _path = [];

  double stateHoldTimerSec = 0.0;

  bool get isMoving => _moving;
  bool get isDancingNearStage => isPresentToday && _grooving;
  bool get isSittingOnBlanket =>
      isPresentToday &&
      activity == FestivalCrowdActivity.sittingOnBlanket &&
      !_moving;
  bool get isQueuingForFood =>
      isPresentToday &&
      activity == FestivalCrowdActivity.queuingInFoodLine &&
      !_moving;

  void assignGoal({
    required FestivalCrowdActivity nextActivity,
    required Offset goal,
    int? nextFacingOverride,
    String? stageId,
    String? blanketId,
    int? seatIdx,
    String? foodStallId,
    int? queueSlot,
    double holdSeconds = 24.0,
    bool snapImmediately = false,
  }) {
    activity = nextActivity;
    facingOverride = nextFacingOverride;
    targetStageId = stageId;
    targetBlanketId = blanketId;
    blanketSeatIndex = seatIdx;
    targetFoodStallId = foodStallId;
    foodQueueSlot = queueSlot;
    stateHoldTimerSec = holdSeconds;

    if (snapImmediately && !map.isPointBlocked(goal.dx, goal.dy)) {
      position.setValues(goal.dx, goal.dy);
      targetPoint = goal;
      _plannedGoal = goal;
      _path.clear();
      _moving = false;
      if (nextFacingOverride != null) {
        _facingRow = nextFacingOverride;
      }
      priority = position.y.round();
      return;
    }

    if (_plannedGoal == null || (_plannedGoal! - goal).distance > 6.0) {
      _path.clear();
      _plannedGoal = goal;
    }
    targetPoint = goal;
  }

  void triggerCallout(String text, {double duration = 2.2}) {
    if (_reactionCalloutTimer > 0.2) return;
    reactionCalloutText = text;
    _reactionCalloutDuration = duration;
    _reactionCalloutTimer = duration;
  }

  void grantServedTreat(String emoji, String callout) {
    heldTreatEmoji = emoji;
    _heldTreatTimer = 44.0;
    reactionCalloutText = callout;
    _reactionCalloutDuration = 2.4;
    _reactionCalloutTimer = 2.4;
  }

  void stepSimulation({
    required double dt,
    required double playerDistance,
    required bool playerDancingNearby,
    required double bassLevel,
  }) {
    if (!isPresentToday) {
      _moving = false;
      _grooving = false;
      priority = -9999;
      return;
    }

    _animClock += dt;
    _bassLevel = bassLevel;
    _grooving = false;
    if (stateHoldTimerSec > 0.0) {
      stateHoldTimerSec = math.max(0.0, stateHoldTimerSec - dt);
    }
    if (_reactionCalloutTimer > 0.0) {
      _reactionCalloutTimer = math.max(0.0, _reactionCalloutTimer - dt);
    }
    if (_heldTreatTimer > 0.0) {
      _heldTreatTimer = math.max(0.0, _heldTreatTimer - dt);
      if (_heldTreatTimer <= 0.0) {
        heldTreatEmoji = null;
      }
    }

    double? stageDistSq;
    if (nearbyStagePos != null) {
      final dx = nearbyStagePos!.dx - position.x;
      final dy = nearbyStagePos!.dy - position.y;
      stageDistSq = dx * dx + dy * dy;
    }
    final inStageBowl = stageDistSq != null && stageDistSq <= 330.0 * 330.0;
    final dancingWithPlayer = playerDancingNearby && playerDistance <= 150.0;

    // Pause footsteps politely if chatting up close with the player!
    if (playerDistance < 28.0 &&
        activity != FestivalCrowdActivity.queuingInFoodLine &&
        activity != FestivalCrowdActivity.sittingOnBlanket) {
      _moving = false;
      if (inStageBowl || dancingWithPlayer) {
        _grooving = true;
      }
      priority = position.y.round();
      return;
    }

    final goal = targetPoint;
    if (goal != null) {
      final spd = switch (activity) {
        FestivalCrowdActivity.queuingInFoodLine => 36.0,
        FestivalCrowdActivity.strollingOrchard => 42.0,
        FestivalCrowdActivity.wanderingToStage => 54.0,
        _ => 48.0,
      };
      final reached = _stepTowardGoal(goal.dx, goal.dy, speed: spd, dt: dt);
      if (reached) {
        if (activity == FestivalCrowdActivity.wanderingToStage) {
          activity = FestivalCrowdActivity.dancingAtStage;
        } else if (activity == FestivalCrowdActivity.walkingToFoodLine) {
          activity = FestivalCrowdActivity.queuingInFoodLine;
        }
        if (facingOverride != null) {
          _facingRow = facingOverride!;
        } else if (nearbyStagePos != null && inStageBowl) {
          _updateFacing(
            nearbyStagePos!.dx - position.x,
            nearbyStagePos!.dy - position.y,
          );
        }
      }
    } else {
      _moving = false;
    }

    if (!_moving) {
      if (activity == FestivalCrowdActivity.dancingAtStage ||
          (activity == FestivalCrowdActivity.strollingOrchard && inStageBowl) ||
          dancingWithPlayer ||
          performanceReaction == CrowdReactionKind.encoreOvation) {
        if (nearbyStagePos != null && inStageBowl) {
          _updateFacing(
            nearbyStagePos!.dx - position.x,
            nearbyStagePos!.dy - position.y,
          );
        }
        _grooving = activity != FestivalCrowdActivity.sittingOnBlanket &&
            activity != FestivalCrowdActivity.queuingInFoodLine;
      }
    }

    priority = position.y.round();
  }

  bool _stepTowardGoal(
    double goalX,
    double goalY, {
    required double speed,
    required double dt,
  }) {
    final dxGoal = goalX - position.x;
    final dyGoal = goalY - position.y;
    if (dxGoal * dxGoal + dyGoal * dyGoal <= 20.0) {
      if (!map.isPointBlocked(goalX, goalY)) {
        position.setValues(goalX, goalY);
      }
      _path.clear();
      _moving = false;
      return true;
    }

    final directClear = dxGoal * dxGoal + dyGoal * dyGoal <= 34.0 * 34.0 &&
        !map.isPointBlocked(
          position.x + dxGoal * 0.5,
          position.y + dyGoal * 0.5,
        );
    if (directClear && _path.isEmpty) {
      return _moveDirectly(goalX, goalY, speed: speed, dt: dt);
    }

    if (_path.isEmpty) {
      final planned = AStarPathfinder(map).findWorldPath(
        startX: position.x,
        startY: position.y,
        goalX: goalX,
        goalY: goalY,
      );
      if (planned.isEmpty) {
        return _moveDirectly(goalX, goalY, speed: speed, dt: dt);
      }
      _path.addAll(planned);
      if (!map.isPointBlocked(goalX, goalY)) {
        _path.add((goalX, goalY));
      }
    }

    final (tx, ty) = _path.first;
    if (_moveDirectly(tx, ty, speed: speed, dt: dt)) {
      _path.removeAt(0);
    }
    return false;
  }

  bool _moveDirectly(
    double tx,
    double ty, {
    required double speed,
    required double dt,
  }) {
    final dx = tx - position.x;
    final dy = ty - position.y;
    final dist = math.sqrt(dx * dx + dy * dy);
    final step = speed * dt;
    if (dist < 2.2 || step >= dist) {
      if (!map.isPointBlocked(tx, ty)) {
        position.setValues(tx, ty);
      }
      _moving = false;
      return true;
    }
    final vx = (dx / dist) * speed;
    final vy = (dy / dist) * speed;
    _updateFacing(vx, vy);
    final nx = position.x + vx * dt;
    final ny = position.y + vy * dt;
    if (!map.isPointBlocked(nx, ny)) {
      position.setValues(nx, ny);
      _moving = true;
      return false;
    }
    if (vx.abs() > 0.01 && !map.isPointBlocked(nx, position.y)) {
      position.setValues(nx, position.y);
      _moving = true;
      return false;
    }
    if (vy.abs() > 0.01 && !map.isPointBlocked(position.x, ny)) {
      position.setValues(position.x, ny);
      _moving = true;
      return false;
    }
    _moving = false;
    return true;
  }

  void _updateFacing(double vx, double vy) {
    if (vx.abs() > vy.abs()) {
      _facingRow = vx < 0 ? 1 : 2;
    } else {
      _facingRow = vy < 0 ? 3 : 0;
    }
  }

  @override
  void render(Canvas canvas) {
    if (!isPresentToday) return;
    final metrics = metricsGetter();
    final inLowGravity = map.isLowGravityAtWorld(position.x, position.y);
    final audShow = nearbyStageShow;
    final seated = isSittingOnBlanket;
    final phaseIdx = spec.id.hashCode.abs() % 4;
    final danceStyle = (spec.id.hashCode.abs() ~/ 5) % 4;

    final floatBob = inLowGravity ? math.sin(_animClock * 2.8 + phaseIdx) * 3.8 : 0.0;
    final audBeatFloat = audShow != null
        ? audShow.beatIndex + audShow.beatPhase
        : _animClock * (114.0 / 60.0);
    final audBeatIdx = audShow?.beatIndex ?? audBeatFloat.floor();
    final audBeatPulse = audShow?.beatPulse ??
        math.pow(1.0 - (audBeatFloat - audBeatIdx), 2.1).toDouble();
    final audBass = audShow?.bass ?? math.max(0.26, _bassLevel);
    final audHighEnergy = audShow != null &&
        (audShow.kickDrop ||
            audShow.sectionMode == LightShowSectionMode.chorusAnthemy ||
            audShow.sectionMode == LightShowSectionMode.soloShred ||
            audShow.sectionMode == LightShowSectionMode.climaxPrism);

    double bounceY = 0.0;
    double swayX = 0.0;
    double stepDownY = 0.0;
    double bodyTilt = 0.0;
    int? danceFrameCol;
    int renderRow = _facingRow;

    if (seated) {
      bounceY = audShow != null ? audBeatPulse * 1.1 : 0.0;
      swayX = math.sin(_animClock * 2.0 + phaseIdx * 0.9) * 1.1;
      stepDownY = 3.6;
      bodyTilt = math.sin(_animClock * 2.0 + phaseIdx * 0.9) * 0.06;
    } else if (_grooving && performanceReaction == CrowdReactionKind.hushSway) {
      bounceY = audBeatPulse * 0.7;
      swayX = math.sin(_animClock * 2.25 + phaseIdx * 0.7) * 3.4;
      bodyTilt = math.sin(_animClock * 2.25 + phaseIdx * 0.7) * 0.13;
    } else if (_grooving &&
        performanceReaction == CrowdReactionKind.encoreOvation) {
      bounceY = math.sin(_animClock * 11.2 + phaseIdx).abs() * 2.3;
      swayX = math.sin(_animClock * 3.5 + phaseIdx) * 1.2;
    } else if (_grooving) {
      final soloBoost = performanceReaction == CrowdReactionKind.soloOrDrop ||
              performanceReaction == CrowdReactionKind.setKickoff
          ? 1.32
          : 1.0;
      danceFrameCol = const [1, 0, 2, 0][(audBeatIdx + phaseIdx) % 4];
      switch (danceStyle) {
        case 0:
          bounceY = audBeatPulse * (2.0 + audBass * 2.7) * soloBoost;
          swayX =
              math.sin((audBeatFloat + phaseIdx * 0.5) * math.pi * 0.5) * 2.3;
          bodyTilt =
              math.sin((audBeatFloat + phaseIdx * 0.5) * math.pi * 0.5) * 0.11;
          break;
        case 1:
          bounceY = (1.5 + audBass * 2.1) *
              soloBoost *
              math.sin((audBeatFloat - audBeatIdx) * math.pi);
          swayX = math.sin((audBeatFloat + phaseIdx) * math.pi) * 2.6;
          bodyTilt = -math.sin((audBeatFloat + phaseIdx) * math.pi) * 0.13;
          break;
        case 2:
          final barPhase = ((audBeatFloat + phaseIdx) % 4.0) / 4.0;
          swayX = math.sin(barPhase * math.pi * 2.0) * 3.0;
          bounceY = audBeatPulse * (1.9 + audBass * 2.5) * soloBoost;
          bodyTilt = math.sin(barPhase * math.pi * 2.0) * 0.10;
          break;
        default:
          bounceY = audBeatPulse * (2.3 + audBass * 2.9) * soloBoost;
          swayX = math.cos((audBeatFloat + phaseIdx) * math.pi * 0.5) * 2.1;
          bodyTilt = math.sin((audBeatFloat + phaseIdx) * math.pi) * 0.11;
          if (!_moving && (audHighEnergy || soloBoost > 1.1)) {
            const spinRows = [0, 1, 3, 2];
            renderRow = spinRows[(audBeatIdx + phaseIdx) % 4];
          }
          break;
      }
    } else if (isQueuingForFood) {
      bounceY = math.sin(_animClock * 3.0 + phaseIdx).abs() * 0.55;
      swayX = math.sin(_animClock * 1.6 + phaseIdx) * 0.65;
    }

    final totalLiftY = floatBob + bounceY;

    renderActor3dShadow(
      canvas: canvas,
      metrics: metrics,
      centerX: 16.0 + swayX * 0.35,
      footY: seated ? 26.8 : (28.5 + stepDownY),
      spotlightColor: _grooving ? audShow?.primaryColor : null,
      haloIntensity: _grooving ? (0.16 + 0.24 * audBeatPulse) : 0.20,
    );

    final int frameCol;
    if (_moving) {
      frameCol = 1 + ((_animClock * 6.4).floor() % 2);
    } else if (seated) {
      frameCol = 0;
    } else if (_grooving && danceFrameCol != null) {
      frameCol = danceFrameCol;
    } else {
      frameCol = 0;
    }

    final src = Rect.fromLTWH(frameCol * 32.0, renderRow * 32.0, 32.0, 32.0);
    final dst = seated
        ? Rect.fromLTWH(swayX, stepDownY - totalLiftY, 32.0, 28.5)
        : Rect.fromLTWH(swayX, stepDownY - totalLiftY, 32.0, 32.0);

    canvas.save();
    if (bodyTilt.abs() > 0.005) {
      final pivotX = 16.0 + swayX;
      final pivotY = 22.0 + stepDownY - totalLiftY;
      canvas.translate(pivotX, pivotY);
      canvas.rotate(bodyTilt);
      canvas.translate(-pivotX, -pivotY);
    }
    canvas.drawImageRect(
      spriteSheet,
      src,
      dst,
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
    renderWalnutWardrobeOutfit(
      canvas,
      wardrobeId: activeWardrobeId,
      facingRow: renderRow,
      offsetX: swayX,
      liftY: totalLiftY - (seated ? 2.4 : 0.0),
      animClock: _animClock,
    );
    canvas.restore();

    if (seated) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(16.0 + swayX, 27.6 - totalLiftY * 0.4),
          width: 14.2,
          height: 4.0,
        ),
        Paint()..color = const Color(0x521C110A),
      );
    }

    // Weekend post-rain Woodstock mud flecks on Day 2/3 shells!
    if (mudPatina > 0.08) {
      final alpha = (mudPatina * 0.80).clamp(0.16, 0.78);
      final mudPaint = Paint()..color = Color.fromRGBO(82, 49, 27, alpha);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(12.2 + swayX, 21.5 + stepDownY - totalLiftY),
          width: 3.6,
          height: 2.2,
        ),
        mudPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(19.8 + swayX, 22.2 + stepDownY - totalLiftY),
          width: 3.2,
          height: 2.0,
        ),
        mudPaint,
      );
    }

    // Performance hands, applause & floating music notes!
    if (_grooving && !_moving) {
      final isOvation = performanceReaction == CrowdReactionKind.encoreOvation;
      final isSolo = performanceReaction == CrowdReactionKind.soloOrDrop ||
          performanceReaction == CrowdReactionKind.setKickoff;
      if (isOvation) {
        final clapGap =
            1.5 + math.sin(_animClock * 20.0 + phaseIdx * 1.3).abs() * 3.8;
        final handCol = Paint()..color = const Color(0xFFD4A373);
        final outline = Paint()..color = const Color(0xFF1C110A);
        for (final hx in [16.0 + swayX - clapGap, 16.0 + swayX + clapGap]) {
          canvas.drawCircle(Offset(hx, 15.0 - totalLiftY), 1.9, outline);
          canvas.drawCircle(Offset(hx, 15.0 - totalLiftY), 1.3, handCol);
        }
        if (clapGap < 2.2) {
          canvas.drawCircle(
            Offset(16.0 + swayX, 13.0 - totalLiftY),
            2.3,
            Paint()..color = const Color(0x99FFD166),
          );
        }
      } else if ((audHighEnergy && audBeatPulse > 0.40) || isSolo) {
        final handCol = Paint()..color = const Color(0xFFD4A373);
        final outline = Paint()..color = const Color(0xFF1C110A);
        final extraLift = isSolo ? 2.4 : 0.0;
        for (final hx in [7.5 + swayX, 24.5 + swayX]) {
          canvas.drawCircle(
            Offset(hx, 14.0 - totalLiftY - audBeatPulse * 2.0 - extraLift),
            1.9,
            outline,
          );
          canvas.drawCircle(
            Offset(hx, 14.0 - totalLiftY - audBeatPulse * 2.0 - extraLift),
            1.3,
            handCol,
          );
        }
      }
      if ((audBeatIdx + phaseIdx) % 2 == 0) {
        final nPhase = (audBeatFloat - audBeatIdx).clamp(0.0, 1.0);
        final noteCol = (audShow?.secondaryColor ?? const Color(0xFFFFD166))
            .withValues(alpha: (0.68 * (1.0 - nPhase)).clamp(0.0, 0.75));
        final nx = 16.0 + swayX + (phaseIdx.isEven ? -7.2 : 7.2);
        final ny = 6.5 - totalLiftY - nPhase * 7.5;
        final np = Paint()..color = noteCol;
        canvas.drawCircle(Offset(nx, ny), 1.25, np);
        canvas.drawRect(Rect.fromLTWH(nx + 0.65, ny - 3.4, 0.85, 3.4), np);
      }
    }

    if (holdingConcertLighter) {
      final swayLight = math.sin(_animClock * 4.2 + phaseIdx) * 2.2;
      final lx = 24.0 + swayX + swayLight;
      final ly = 9.0 - totalLiftY;
      final flick = 0.82 + 0.22 * math.sin(_animClock * 22.0 + phaseIdx * 2);
      canvas.drawCircle(
        Offset(lx, ly),
        4.6 * flick,
        Paint()..color = const Color(0x55FFB703),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(lx, ly),
          width: 2.1 * flick,
          height: 3.3 * flick,
        ),
        Paint()..color = const Color(0xFFFFD166),
      );
    }

    if (heldTreatEmoji != null && _heldTreatTimer > 0.0) {
      final bobSnack = math.sin(_animClock * 4.4 + phaseIdx) * 0.85;
      renderCenteredWorldPill(
        canvas: canvas,
        center: Offset(25.0 + swayX, 17.5 + stepDownY - totalLiftY + bobSnack),
        text: heldTreatEmoji!,
        fontSize: 5.8,
        textColor: const Color(0xFFFFF8E7),
        backgroundColor: const Color(0xAA1C110A),
        horizontalPadding: 2.0,
        pillHeight: 9.2,
        minPillWidth: 10.0,
        maxPillWidth: 18.0,
        borderRadius: 4.5,
      );
    }

    if (_reactionCalloutTimer > 0.0 && reactionCalloutText != null) {
      final fade = (_reactionCalloutTimer / 0.42).clamp(0.0, 1.0);
      final rise =
          (_reactionCalloutDuration - _reactionCalloutTimer).clamp(0.0, 2.5) *
              3.2;
      renderCenteredWorldPill(
        canvas: canvas,
        center: Offset(16.0 + swayX, -5.2 - totalLiftY - rise),
        text: reactionCalloutText!,
        fontSize: 5.9,
        textColor: Color.fromRGBO(255, 243, 176, fade),
        backgroundColor: Color.fromRGBO(28, 17, 10, 0.86 * fade),
        horizontalPadding: 5.5,
        pillHeight: 11.2,
        minPillWidth: 34.0,
        maxPillWidth: 114.0,
        borderRadius: 5.0,
      );
    }
  }
}

class _StageReactionMemory {
  String? activeTrackId;
  double kickoffRemainingSec = 0.0;
  double ovationRemainingSec = 0.0;
  double calloutCooldownSec = 0.0;
  CrowdReactionKind currentReaction = CrowdReactionKind.none;
}

/// Orchestrates Walnutstock's 3-Day Living Festival Ecosystem:
/// - Stage-to-stage A* crowd migration & pre-set gathering
/// - Progressive Day 1 -> Day 2 -> Day 3 lawn picnic blankets & seated lounging
/// - Vendor Row single-file food & drink queues with active counter service
/// - Beat-synced dancing & live performance reactions (kickoffs, solos/drops, hush sways, ovations)
/// - 3-Day evolving crowds, wardrobes, mud patina, and context-aware conversations
class FestivalCrowdDirector {
  FestivalCrowdDirector({
    required this.map,
    required this.catalog,
    required this.characterSheets,
    required this.picnicBlanketSprite,
    required this.metricsGetter,
    required this.viewBoundsGetter,
    required this.timeGetter,
    this.onCelebrationBurst,
  }) {
    _initBlankets();
    _initFoodQueues();
    _initFestivalGoers();
  }

  final OrchardMapData map;
  final SetlistCatalog catalog;
  final Map<String, Image> characterSheets;
  final Image picnicBlanketSprite;
  final DayNightMetrics Function() metricsGetter;
  final Rect Function() viewBoundsGetter;
  final double Function() timeGetter;
  final void Function(Offset worldPos)? onCelebrationBurst;

  late final FestivalBlanketsGroundComponent blanketsGroundLayer =
      FestivalBlanketsGroundComponent(
    director: this,
    picnicBlanketSprite: picnicBlanketSprite,
    metricsGetter: metricsGetter,
    viewBoundsGetter: viewBoundsGetter,
    timeGetter: timeGetter,
  );

  final List<FestivalBlanketSpot> _curatedBlankets = [];
  FestivalBlanketSpot? _playerCustomBlanket;
  final Map<String, FoodStallQueueState> _foodQueues = {};
  final List<FestivalGoerActor> _allGoers = [];
  final Map<String, _StageReactionMemory> _stageReactions = {
    'main_roots_stage': _StageReactionMemory(),
    'velvet_canopy_stage': _StageReactionMemory(),
    'mellow_meadow_stage': _StageReactionMemory(),
    'andromeda_pavilion_stage': _StageReactionMemory(),
    'urbano_canopy_stage': _StageReactionMemory(),
  };

  final math.Random _rng = math.Random(19690815);
  int _activeDay = 1;
  bool _encoreUnlocked = false;
  bool _wasHeavyRain = false;
  bool _wasBlanketDeployed = false;
  Set<String> _lastLiveStageIds = const {};
  double _rebalanceTimerSec = 0.0;
  double _postSetFoodRushSec = 0.0;

  static const Set<String> _roamingNamedNpcIds = {
    'nora_walnut',
    'raymond_walnut',
    'elsie_walnut',
    'pippin_pecan',
    'saffron_suture',
    'orion_kernel',
    'wen_wan_elder',
  };

  static const Map<String, List<Offset>> _stageBowlAnchors = {
    'main_roots_stage': [
      Offset(528, 484),
      Offset(568, 492),
      Offset(608, 498),
      Offset(644, 490),
      Offset(684, 486),
      Offset(548, 520),
      Offset(592, 526),
      Offset(632, 524),
      Offset(672, 514),
      Offset(576, 548),
      Offset(624, 548),
    ],
    'velvet_canopy_stage': [
      Offset(180, 488),
      Offset(212, 486),
      Offset(244, 492),
      Offset(276, 496),
      Offset(196, 518),
      Offset(232, 522),
      Offset(268, 522),
    ],
    'mellow_meadow_stage': [
      Offset(1076, 496),
      Offset(1108, 502),
      Offset(1148, 506),
      Offset(1184, 500),
      Offset(1216, 496),
      Offset(1096, 532),
      Offset(1144, 536),
      Offset(1188, 532),
    ],
    'andromeda_pavilion_stage': [
      Offset(1696, 412),
      Offset(1736, 420),
      Offset(1776, 420),
      Offset(1812, 414),
      Offset(1716, 452),
      Offset(1760, 456),
      Offset(1796, 450),
    ],
    'urbano_canopy_stage': [
      Offset(196, 1088),
      Offset(228, 1094),
      Offset(260, 1092),
      Offset(292, 1088),
      Offset(216, 1122),
      Offset(248, 1124),
      Offset(280, 1118),
    ],
  };

  static const List<Offset> _scenicStrollWaypoints = [
    Offset(608, 1168), // Inside Front Gate Lane
    Offset(608, 864), // Central Orchard Crossroads
    Offset(992, 640), // Willow Creek West Bank
    Offset(1168, 624), // Mellow Meadow South Path
    Offset(1088, 1040), // Shady Bottoms Campground Commons
    Offset(1216, 1136), // Vendor Row Promenade
    Offset(448, 624), // West Grove Path
    Offset(1616, 512), // Andromeda Approach Ridge
  ];

  List<FestivalGoerActor> get allGoers => _allGoers;

  List<FestivalGoerActor> get activeCrowdActors =>
      _allGoers.where((g) => g.isPresentToday).toList(growable: false);

  List<FestivalBlanketSpot> get activeBlanketSpots {
    final effectiveDay = _encoreUnlocked ? 3 : _activeDay;
    return [
      for (final b in _curatedBlankets)
        if (b.minDay <= effectiveDay) b,
      if (_playerCustomBlanket != null) _playerCustomBlanket!,
    ];
  }

  Map<String, FoodStallQueueState> get foodQueues => _foodQueues;

  FoodStallQueueState? queueForStall(String stallId) => _foodQueues[stallId];

  CrowdReactionKind stageReactionFor(String stageId) =>
      _stageReactions[stageId]?.currentReaction ?? CrowdReactionKind.none;

  int get totalQueuedForFoodCount =>
      _foodQueues.values.fold<int>(0, (sum, q) => sum + q.length);

  int countSeatedActors(List<NpcActor> npcs) {
    var count = 0;
    for (final g in _allGoers) {
      if (g.isSittingOnBlanket) count++;
    }
    for (final n in npcs) {
      if (n.isSittingOnBlanket) count++;
    }
    return count;
  }

  int countDancingActors(List<NpcActor> npcs) {
    var count = 0;
    for (final g in _allGoers) {
      if (g.isDancingNearStage) count++;
    }
    for (final n in npcs) {
      if (n.isDancingNearStage) count++;
    }
    return count;
  }

  Offset snapToWalkable(double x, double y) {
    if (!map.isPointBlocked(x, y)) {
      return Offset(x, y);
    }
    for (var radius = 8.0; radius <= 72.0; radius += 8.0) {
      for (var step = 0; step < 12; step++) {
        final ang = (step / 12.0) * math.pi * 2.0;
        final cx = x + math.cos(ang) * radius;
        final cy = y + math.sin(ang) * radius;
        if (!map.isPointBlocked(cx, cy)) {
          return Offset(cx, cy);
        }
      }
    }
    return const Offset(608.0, 520.0);
  }

  void _initBlankets() {
    final rawSpecs = <(
      String,
      String,
      Offset,
      int,
      Color,
      String,
      String?
    )>[
      (
        'blanket_main_roots_west',
        'Main Roots Stage Lawn',
        const Offset(508, 540),
        1,
        const Color(0xFFE76F51),
        'thermos',
        'main_roots_stage',
      ),
      (
        'blanket_main_roots_east',
        'Main Roots Stage Lawn',
        const Offset(692, 528),
        1,
        const Color(0xFF2A9D8F),
        'songbook',
        'main_roots_stage',
      ),
      (
        'blanket_meadow_clover',
        'Mellow Meadow Clover',
        const Offset(1056, 556),
        1,
        const Color(0xFF52B788),
        'tea',
        'mellow_meadow_stage',
      ),
      (
        'blanket_campground_oak',
        'Shady Bottoms Campground',
        const Offset(1008, 1064),
        1,
        const Color(0xFFF4A261),
        'basket',
        null,
      ),
      (
        'blanket_velvet_lawn',
        'Velvet Canopy Lawn',
        const Offset(248, 540),
        2,
        const Color(0xFF9D4EDD),
        'thermos',
        'velvet_canopy_stage',
      ),
      (
        'blanket_meadow_south',
        'Mellow Meadow Ridge',
        const Offset(1188, 572),
        2,
        const Color(0xFFFFBE0B),
        'basket',
        'mellow_meadow_stage',
      ),
      (
        'blanket_urbano_grove',
        'Urbano Canopy Grove',
        const Offset(220, 1152),
        2,
        const Color(0xFFE63946),
        'songbook',
        'urbano_canopy_stage',
      ),
      (
        'blanket_main_roots_center',
        'Main Roots Amphitheater',
        const Offset(596, 564),
        3,
        const Color(0xFF4CC9F0),
        'tea',
        'main_roots_stage',
      ),
      (
        'blanket_andromeda_lawn',
        'Andromeda Starlight Ridge',
        const Offset(1680, 484),
        3,
        const Color(0xFF7209B7),
        'thermos',
        'andromeda_pavilion_stage',
      ),
    ];

    for (final (id, zone, rawCenter, minDay, trim, prop, stageId) in rawSpecs) {
      final center = snapToWalkable(rawCenter.dx, rawCenter.dy);
      final seats = <Offset>[
        snapToWalkable(center.dx - 13.0, center.dy + 2.0),
        snapToWalkable(center.dx + 13.0, center.dy + 3.0),
        snapToWalkable(center.dx, center.dy - 5.0),
      ];
      _curatedBlankets.add(
        FestivalBlanketSpot(
          id: id,
          zoneLabel: zone,
          center: center,
          seats: seats,
          minDay: minDay,
          trimColor: trim,
          propKind: prop,
          preferredStageId: stageId,
        ),
      );
    }
  }

  void _initFoodQueues() {
    final specs = <FoodStallSpec>[
      FoodStallSpec(
        id: 'falafel_stand',
        displayName: "Burt's Tahini Falafel Stand",
        counterPos: const Offset(1296, 988),
        queueSlots: [
          snapToWalkable(1296, 1012),
          snapToWalkable(1296, 1036),
          snapToWalkable(1296, 1060),
          snapToWalkable(1296, 1084),
          snapToWalkable(1296, 1108),
        ],
        menuTreats: const [
          ('🥙', '🥙 Warm Tahini Falafel!'),
          ('🥨', '🥨 Candied Walnuts!'),
        ],
      ),
      FoodStallSpec(
        id: 'street_food_cart',
        displayName: 'Orchard Cider & Espresso Cart',
        counterPos: const Offset(1152, 992),
        queueSlots: [
          snapToWalkable(1154, 1014),
          snapToWalkable(1158, 1038),
          snapToWalkable(1162, 1062),
          snapToWalkable(1166, 1086),
        ],
        menuTreats: const [
          ('🍎', '🍎 Spiced Cider!'),
          ('☕', '☕ Velvet Espresso!'),
        ],
      ),
      FoodStallSpec(
        id: 'cider_tea_kettle',
        displayName: 'Grapevine & Firefly Tea Kettle',
        counterPos: const Offset(1360, 988),
        queueSlots: [
          snapToWalkable(1360, 1012),
          snapToWalkable(1360, 1036),
          snapToWalkable(1360, 1060),
        ],
        menuTreats: const [
          ('🫖', '🫖 Firefly Tea!'),
          ('🍵', '🍵 Grapevine Tea!'),
        ],
      ),
    ];

    for (final spec in specs) {
      _foodQueues[spec.id] = FoodStallQueueState(spec);
    }
  }

  void _initFestivalGoers() {
    const rawSpecs = <FestivalGoerSpec>[
      // --- DAY 1 ARRIVALS (12 Early-Bird Friday Pilgrims) ---
      FestivalGoerSpec(
        id: 'fg_marigold',
        name: 'Marigold Chandler',
        title: 'Berkeley Folk Hitchhiker',
        cultivarId: 'chandler',
        voicePitch: 'high',
        minDay: 1,
        homePos: Offset(584, 1184),
        day1WardrobeId: 'moss_band',
        day2WardrobeId: 'flower_crown_poncho',
        day3WardrobeId: 'artisan_patchwork_cape',
        favoriteStageId: 'mellow_meadow_stage',
        personalityTag: 'folk_poet',
      ),
      FestivalGoerSpec(
        id: 'fg_otis',
        name: 'Otis Hartley',
        title: 'Napa Basshead & Blanket Host',
        cultivarId: 'hartley',
        voicePitch: 'low',
        minDay: 1,
        homePos: Offset(520, 536),
        day1WardrobeId: 'denim_rose_specs',
        day2WardrobeId: 'fringe_vest',
        day3WardrobeId: 'mcgregor_vest',
        favoriteStageId: 'main_roots_stage',
        personalityTag: 'audio_nerd',
      ),
      FestivalGoerSpec(
        id: 'fg_june',
        name: 'Junebug Howard',
        title: 'Barefoot Tambourine Hopper',
        cultivarId: 'howard',
        voicePitch: 'high',
        minDay: 1,
        homePos: Offset(676, 524),
        day1WardrobeId: 'tie_dye_tee',
        day2WardrobeId: 'flower_crown_poncho',
        day3WardrobeId: 'purple_haze_bandana',
        favoriteStageId: 'main_roots_stage',
        personalityTag: 'dancer',
      ),
      FestivalGoerSpec(
        id: 'fg_levon',
        name: 'Levon Tulare',
        title: 'San Joaquin Blues Rambler',
        cultivarId: 'tulare',
        voicePitch: 'low',
        minDay: 1,
        homePos: Offset(236, 512),
        day1WardrobeId: 'paisley_bandana_vest',
        day2WardrobeId: 'velvet_bellbottom_coat',
        day3WardrobeId: 'amethyst_specs',
        favoriteStageId: 'velvet_canopy_stage',
        personalityTag: 'blues_fan',
      ),
      FestivalGoerSpec(
        id: 'fg_celeste',
        name: 'Celeste Franquette',
        title: 'Left-Bank Lyric Sketcher',
        cultivarId: 'franquette',
        voicePitch: 'mid',
        minDay: 1,
        homePos: Offset(1072, 548),
        day1WardrobeId: 'none',
        day2WardrobeId: 'willow_shawl',
        day3WardrobeId: 'sunset_biolume_shawl',
        favoriteStageId: 'mellow_meadow_stage',
        personalityTag: 'folk_poet',
      ),
      FestivalGoerSpec(
        id: 'fg_cassian',
        name: 'Cassian Hindsii',
        title: 'Creekside Stargazer',
        cultivarId: 'juglans_hindsii',
        voicePitch: 'low',
        minDay: 1,
        homePos: Offset(1704, 444),
        day1WardrobeId: 'denim_rose_specs',
        day2WardrobeId: 'star_crystal_specs',
        day3WardrobeId: 'star_crystal_specs',
        favoriteStageId: 'andromeda_pavilion_stage',
        personalityTag: 'cosmic',
      ),
      FestivalGoerSpec(
        id: 'fg_mei',
        name: 'Mei-Ling Wen-wan',
        title: 'Tea-Kettle Harmony Seeker',
        cultivarId: 'wen_wan',
        voicePitch: 'high',
        minDay: 1,
        homePos: Offset(1296, 1036),
        day1WardrobeId: 'moss_band',
        day2WardrobeId: 'heart_specs',
        day3WardrobeId: 'sunset_biolume_shawl',
        favoriteStageId: 'mellow_meadow_stage',
        personalityTag: 'foodie',
      ),
      FestivalGoerSpec(
        id: 'fg_ruby',
        name: 'Ruby Livermore',
        title: 'Velvet-Drapes Soul Clapper',
        cultivarId: 'red_livermore',
        voicePitch: 'high',
        minDay: 1,
        homePos: Offset(208, 496),
        day1WardrobeId: 'flower_crown_poncho',
        day2WardrobeId: 'velvet_bellbottom_coat',
        day3WardrobeId: 'purple_haze_bandana',
        favoriteStageId: 'velvet_canopy_stage',
        personalityTag: 'dancer',
      ),
      FestivalGoerSpec(
        id: 'fg_jules',
        name: 'Jules Serr',
        title: 'VW Bus Tape-Deck Mechanic',
        cultivarId: 'serr',
        voicePitch: 'mid',
        minDay: 1,
        homePos: Offset(1156, 1036),
        day1WardrobeId: 'fringe_vest',
        day2WardrobeId: 'paisley_bandana_vest',
        day3WardrobeId: 'press_photographer_vest',
        favoriteStageId: 'urbano_canopy_stage',
        personalityTag: 'audio_nerd',
      ),
      FestivalGoerSpec(
        id: 'fg_hana',
        name: 'Hana Heartnut',
        title: 'Daisy-Chain Peace Weaver',
        cultivarId: 'japonica_heartnut',
        voicePitch: 'high',
        minDay: 1,
        homePos: Offset(1012, 1064),
        day1WardrobeId: 'flower_crown_poncho',
        day2WardrobeId: 'heart_specs',
        day3WardrobeId: 'artisan_patchwork_cape',
        favoriteStageId: 'mellow_meadow_stage',
        personalityTag: 'folk_poet',
      ),
      FestivalGoerSpec(
        id: 'fg_silas',
        name: 'Silas Butternut',
        title: 'Catskills Trail Hiker',
        cultivarId: 'cinerea_butternut',
        voicePitch: 'low',
        minDay: 1,
        homePos: Offset(1296, 1060),
        day1WardrobeId: 'none',
        day2WardrobeId: 'campfire_ranger_hat',
        day3WardrobeId: 'campfire_ranger_hat',
        favoriteStageId: 'main_roots_stage',
        personalityTag: 'foodie',
      ),
      FestivalGoerSpec(
        id: 'fg_rico',
        name: 'Rico Howard',
        title: 'Santurce Conga Fanatic',
        cultivarId: 'howard',
        voicePitch: 'mid',
        minDay: 1,
        homePos: Offset(236, 1108),
        day1WardrobeId: 'paisley_bandana_vest',
        day2WardrobeId: 'gold_w_vest',
        day3WardrobeId: 'gold_w_vest',
        favoriteStageId: 'urbano_canopy_stage',
        personalityTag: 'dancer',
      ),

      // --- DAY 2 ARRIVALS (+7 Saturday Surge = 19 Total) ---
      FestivalGoerSpec(
        id: 'fg_delilah',
        name: 'Delilah Chandler',
        title: 'Saturday Mud-Slide Daredevil',
        cultivarId: 'chandler',
        voicePitch: 'high',
        minDay: 2,
        homePos: Offset(564, 512),
        day1WardrobeId: 'tie_dye_tee',
        day2WardrobeId: 'tie_dye_tee',
        day3WardrobeId: 'purple_haze_bandana',
        favoriteStageId: 'main_roots_stage',
        personalityTag: 'mud_lover',
      ),
      FestivalGoerSpec(
        id: 'fg_arthur',
        name: 'Artie Hartley',
        title: 'Falafel Connoisseur',
        cultivarId: 'hartley',
        voicePitch: 'low',
        minDay: 2,
        homePos: Offset(1296, 1084),
        day1WardrobeId: 'fringe_vest',
        day2WardrobeId: 'mcgregor_vest',
        day3WardrobeId: 'mcgregor_vest',
        favoriteStageId: 'velvet_canopy_stage',
        personalityTag: 'foodie',
      ),
      FestivalGoerSpec(
        id: 'fg_birdie',
        name: 'Birdie Livermore',
        title: 'Blueberry Basket Songbird',
        cultivarId: 'red_livermore',
        voicePitch: 'high',
        minDay: 2,
        homePos: Offset(1148, 528),
        day1WardrobeId: 'flower_crown_poncho',
        day2WardrobeId: 'heart_specs',
        day3WardrobeId: 'artisan_patchwork_cape',
        favoriteStageId: 'mellow_meadow_stage',
        personalityTag: 'cosmic',
      ),
      FestivalGoerSpec(
        id: 'fg_lazlo',
        name: 'Lazlo Hindsii',
        title: 'Midnight Dome Synth-Dancer',
        cultivarId: 'juglans_hindsii',
        voicePitch: 'mid',
        minDay: 2,
        homePos: Offset(1752, 436),
        day1WardrobeId: 'denim_rose_specs',
        day2WardrobeId: 'star_crystal_specs',
        day3WardrobeId: 'pinball_wizard_jacket',
        favoriteStageId: 'andromeda_pavilion_stage',
        personalityTag: 'cosmic',
      ),
      FestivalGoerSpec(
        id: 'fg_camille',
        name: 'Camille Franquette',
        title: 'Velvet Ribbon Twirler',
        cultivarId: 'franquette',
        voicePitch: 'high',
        minDay: 2,
        homePos: Offset(252, 536),
        day1WardrobeId: 'velvet_bellbottom_coat',
        day2WardrobeId: 'amethyst_specs',
        day3WardrobeId: 'sunset_biolume_shawl',
        favoriteStageId: 'velvet_canopy_stage',
        personalityTag: 'blues_fan',
      ),
      FestivalGoerSpec(
        id: 'fg_gordy',
        name: 'Gordy Tulare',
        title: 'Hammond Organ Head-Bobber',
        cultivarId: 'tulare',
        voicePitch: 'low',
        minDay: 2,
        homePos: Offset(624, 504),
        day1WardrobeId: 'paisley_bandana_vest',
        day2WardrobeId: 'denim_rose_specs',
        day3WardrobeId: 'purple_haze_bandana',
        favoriteStageId: 'main_roots_stage',
        personalityTag: 'audio_nerd',
      ),
      FestivalGoerSpec(
        id: 'fg_luz',
        name: 'Luz Serr',
        title: 'Sub-Woofer Two-Stepper',
        cultivarId: 'serr',
        voicePitch: 'high',
        minDay: 2,
        homePos: Offset(224, 1148),
        day1WardrobeId: 'tie_dye_tee',
        day2WardrobeId: 'gold_w_vest',
        day3WardrobeId: 'artisan_patchwork_cape',
        favoriteStageId: 'urbano_canopy_stage',
        personalityTag: 'dancer',
      ),

      // --- DAY 3 ARRIVALS (+5 Sunday Finale Family = 24 Total) ---
      FestivalGoerSpec(
        id: 'fg_solomon',
        name: 'Solomon Wen-wan',
        title: 'Sunday Sunrise Choir Elder',
        cultivarId: 'wen_wan',
        voicePitch: 'low',
        minDay: 3,
        homePos: Offset(596, 560),
        day1WardrobeId: 'willow_shawl',
        day2WardrobeId: 'willow_shawl',
        day3WardrobeId: 'sunset_biolume_shawl',
        favoriteStageId: 'main_roots_stage',
        personalityTag: 'folk_poet',
      ),
      FestivalGoerSpec(
        id: 'fg_pepper',
        name: 'Pepper Heartnut',
        title: 'Hendrix Front-Rail Pilgrim',
        cultivarId: 'japonica_heartnut',
        voicePitch: 'high',
        minDay: 3,
        homePos: Offset(552, 488),
        day1WardrobeId: 'tie_dye_tee',
        day2WardrobeId: 'tie_dye_tee',
        day3WardrobeId: 'purple_haze_bandana',
        favoriteStageId: 'main_roots_stage',
        personalityTag: 'dancer',
      ),
      FestivalGoerSpec(
        id: 'fg_bode',
        name: 'Bodega Butternut',
        title: 'Campfire Cider Pourer',
        cultivarId: 'cinerea_butternut',
        voicePitch: 'low',
        minDay: 3,
        homePos: Offset(1360, 1036),
        day1WardrobeId: 'fringe_vest',
        day2WardrobeId: 'campfire_ranger_hat',
        day3WardrobeId: 'mcgregor_vest',
        favoriteStageId: 'main_roots_stage',
        personalityTag: 'foodie',
      ),
      FestivalGoerSpec(
        id: 'fg_starla',
        name: 'Starla Chandler',
        title: 'Patchwork Quilt Lounger',
        cultivarId: 'chandler',
        voicePitch: 'high',
        minDay: 3,
        homePos: Offset(1680, 480),
        day1WardrobeId: 'flower_crown_poncho',
        day2WardrobeId: 'star_crystal_specs',
        day3WardrobeId: 'artisan_patchwork_cape',
        favoriteStageId: 'main_roots_stage',
        personalityTag: 'cosmic',
      ),
      FestivalGoerSpec(
        id: 'fg_django',
        name: 'Django Tulare',
        title: 'Bootleg Cassette Trader',
        cultivarId: 'tulare',
        voicePitch: 'mid',
        minDay: 3,
        homePos: Offset(644, 492),
        day1WardrobeId: 'denim_rose_specs',
        day2WardrobeId: 'press_photographer_vest',
        day3WardrobeId: 'purple_haze_bandana',
        favoriteStageId: 'main_roots_stage',
        personalityTag: 'audio_nerd',
      ),
    ];

    for (final spec in rawSpecs) {
      final safeHome = snapToWalkable(spec.homePos.dx, spec.homePos.dy);
      final safeSpec = FestivalGoerSpec(
        id: spec.id,
        name: spec.name,
        title: spec.title,
        cultivarId: spec.cultivarId,
        voicePitch: spec.voicePitch,
        minDay: spec.minDay,
        homePos: safeHome,
        day1WardrobeId: spec.day1WardrobeId,
        day2WardrobeId: spec.day2WardrobeId,
        day3WardrobeId: spec.day3WardrobeId,
        favoriteStageId: spec.favoriteStageId,
        personalityTag: spec.personalityTag,
      );
      final sheet =
          characterSheets[spec.cultivarId] ?? characterSheets.values.first;
      _allGoers.add(
        FestivalGoerActor(
          spec: safeSpec,
          map: map,
          spriteSheet: sheet,
          metricsGetter: metricsGetter,
        ),
      );
    }
  }

  Future<void> mountIntoWorld(World world) async {
    await world.add(blanketsGroundLayer);
    for (final actor in _allGoers) {
      await world.add(actor);
    }
  }

  void update({
    required double dt,
    required FestivalClockState clock,
    required WorldFlags flags,
    required Map<String, LiveStageVisualState> liveStages,
    required List<NpcActor> namedNpcs,
    required Vector2 playerPos,
    required double bassLevel,
    required bool nightSparklerWave,
    required bool clockJumped,
  }) {
    final prevDay = _activeDay;
    _activeDay = clock.day;
    _encoreUnlocked = clock.encoreModeUnlocked;
    final effectiveDay = _encoreUnlocked ? 3 : clock.day;
    final dayChanged = prevDay != _activeDay || clockJumped;

    final metrics = metricsGetter();
    final heavyRain = metrics.rainIntensity > 0.50;
    final muddy = clock.isOrchardMuddy(catalog);

    // 1. Update player's deployable Woven Picnic Blanket guest seats!
    if (flags.picnicBlanketDeployed && !heavyRain) {
      final center = snapToWalkable(flags.picnicBlanketX, flags.picnicBlanketY);
      _playerCustomBlanket = FestivalBlanketSpot(
        id: 'blanket_player_custom',
        zoneLabel: 'Your Woven Picnic Blanket',
        center: center,
        seats: [
          snapToWalkable(center.dx - 15.0, center.dy + 5.0),
          snapToWalkable(center.dx + 15.0, center.dy + 6.0),
        ],
        minDay: 1,
        trimColor: const Color(0xFFFFD166),
        propKind: 'tea',
        isPlayerBlanket: true,
      );
    } else {
      if (_playerCustomBlanket != null) {
        _evictBlanketSitters('blanket_player_custom', namedNpcs);
      }
      _playerCustomBlanket = null;
    }

    // 2. Sync Day 1 / Day 2 / Day 3 presence, outfits, and post-rain mud patina!
    for (final goer in _allGoers) {
      final wasPresent = goer.isPresentToday;
      goer.isPresentToday = goer.spec.minDay <= effectiveDay;
      goer.activeWardrobeId = goer.spec.wardrobeForDay(effectiveDay);
      if (!goer.isPresentToday) {
        _removeFromFoodQueues('crowd:${goer.spec.id}');
        continue;
      }
      if (!wasPresent && goer.isPresentToday) {
        goer.position.setValues(goer.spec.homePos.dx, goer.spec.homePos.dy);
      }
      // Authentic Woodstock mud patina builds on Day 2 after rain and mellows on Day 3
      final targetMud = muddy
          ? 0.62
          : (clock.day == 2 && clock.minuteOfDay > 500
              ? 0.34
              : (clock.day == 3 && clock.minuteOfDay < 780 ? 0.18 : 0.0));
      goer.mudPatina +=
          (targetMud - goer.mudPatina) * (dt * 0.8).clamp(0.0, 1.0);
    }

    // 3. Step Stage Performance Reaction Trackers (kickoffs, solos/drops, hush sways, ovations!)
    _stepStageReactions(
      dt: dt,
      liveStages: liveStages,
      clockJumped: clockJumped,
      namedNpcs: namedNpcs,
    );

    if (_postSetFoodRushSec > 0.0) {
      _postSetFoodRushSec = math.max(0.0, _postSetFoodRushSec - dt);
    }

    // 4. Evict blanket sitters immediately if heavy rain starts or Sunday finale calls everyone!
    if (heavyRain || flags.crowdMigrateMainRoots) {
      for (final goer in _allGoers) {
        if (goer.activity == FestivalCrowdActivity.sittingOnBlanket) {
          goer.stateHoldTimerSec = 0.0;
          if (heavyRain) {
            goer.triggerCallout('🌧️ Heading for cover!');
          }
        }
      }
      for (final npc in namedNpcs) {
        if (npc.autonomousActivity == NpcAutonomousActivity.sittingOnBlanket) {
          npc.clearAutonomousDirective();
          if (heavyRain) {
            npc.triggerPerformanceCallout('🌧️ Rainstorm!!');
          }
        }
      }
    }

    // 5. Step Vendor Row Food Stall Service & Queue Advancement!
    final falafelTruceReady =
        flags.burtQuestCompleted || flags.falafelTruceUnlocked || clock.day >= 2;
    _stepFoodQueues(
      dt: dt,
      falafelTruceReady: falafelTruceReady,
      namedNpcs: namedNpcs,
      heavyRain: heavyRain,
      liveStages: liveStages,
      clock: clock,
    );

    // 6. Periodically rebalance autonomous goals across stages, blankets & food lines!
    final currentStageSet = {
      for (final s in liveStages.keys)
        if (s != 'pa_global_horn') s,
    };
    final stageLineupChanged =
        currentStageSet.length != _lastLiveStageIds.length ||
            !currentStageSet.containsAll(_lastLiveStageIds);
    final weatherOrBlanketChanged = _wasHeavyRain != heavyRain ||
        _wasBlanketDeployed != flags.picnicBlanketDeployed;
    _wasHeavyRain = heavyRain;
    _wasBlanketDeployed = flags.picnicBlanketDeployed;
    _lastLiveStageIds = currentStageSet;

    _rebalanceTimerSec -= dt;
    if (dayChanged ||
        stageLineupChanged ||
        weatherOrBlanketChanged ||
        _rebalanceTimerSec <= 0.0) {
      _rebalanceTimerSec = 1.6;
      _rebalanceEcosystem(
        clock: clock,
        flags: flags,
        liveStages: liveStages,
        namedNpcs: namedNpcs,
        heavyRain: heavyRain,
        snapImmediately: clockJumped,
      );
    }

    // 7. Step every active FestivalGoerActor + sync reactions onto Named NPCs!
    for (final goer in _allGoers) {
      if (!goer.isPresentToday) continue;
      final nearStage = _nearestStageContext(goer.position, liveStages);
      goer.nearbyStagePos = nearStage.$1;
      goer.nearbyStageShow = nearStage.$2;
      goer.performanceReaction = nearStage.$3;
      final pDist = goer.position.distanceTo(playerPos);
      goer.stepSimulation(
        dt: dt,
        playerDistance: pDist,
        playerDancingNearby: flags.playerDancing,
        bassLevel: bassLevel,
      );
      goer.holdingConcertLighter =
          nightSparklerWave && goer.isDancingNearStage && pDist <= 260.0;
    }

    for (final npc in namedNpcs) {
      if (npc.isOnStagePerforming) {
        npc.performanceReaction = CrowdReactionKind.none;
        continue;
      }
      final nearStage = _nearestStageContext(npc.position, liveStages);
      npc.performanceReaction = nearStage.$3;
    }
  }

  (Offset?, StageShowFrame?, CrowdReactionKind) _nearestStageContext(
    Vector2 pos,
    Map<String, LiveStageVisualState> liveStages,
  ) {
    Offset? bestPos;
    StageShowFrame? bestShow;
    var bestReaction = CrowdReactionKind.none;
    var bestDistSq = 340.0 * 340.0;

    for (final entry in _stageReactions.entries) {
      final stageId = entry.key;
      final st = catalog.stages[stageId];
      if (st == null) continue;
      final live = liveStages[stageId];
      final mem = entry.value;
      if (live == null && mem.ovationRemainingSec <= 0.0) continue;

      final dx = st.x - pos.x;
      final dy = st.y - pos.y;
      final d2 = dx * dx + dy * dy;
      if (d2 <= bestDistSq) {
        bestDistSq = d2;
        bestPos = Offset(st.x, st.y);
        bestShow = live?.show;
        bestReaction = mem.currentReaction;
      }
    }
    return (bestPos, bestShow, bestReaction);
  }

  void _stepStageReactions({
    required double dt,
    required Map<String, LiveStageVisualState> liveStages,
    required bool clockJumped,
    required List<NpcActor> namedNpcs,
  }) {
    for (final entry in _stageReactions.entries) {
      final stageId = entry.key;
      final mem = entry.value;
      final live = liveStages[stageId];
      final stageInfo = catalog.stages[stageId];

      if (mem.kickoffRemainingSec > 0.0) {
        mem.kickoffRemainingSec = math.max(0.0, mem.kickoffRemainingSec - dt);
      }
      if (mem.ovationRemainingSec > 0.0) {
        mem.ovationRemainingSec = math.max(0.0, mem.ovationRemainingSec - dt);
      }
      if (mem.calloutCooldownSec > 0.0) {
        mem.calloutCooldownSec = math.max(0.0, mem.calloutCooldownSec - dt);
      }

      if (live != null) {
        // Detect brand-new set starting on this stage!
        if (mem.activeTrackId != live.track.id) {
          mem.activeTrackId = live.track.id;
          mem.ovationRemainingSec = 0.0;
          if (!clockJumped || live.show.trackTimeSec <= 10.0) {
            mem.kickoffRemainingSec = 7.5;
            _emitStageAudienceCallout(
              stageId: stageId,
              namedNpcs: namedNpcs,
              options: const [
                '🎸 YEAHHH!!',
                '✌️ HERE WE GO!',
                '🎶 TURN IT UP!',
              ],
            );
          }
        }

        final show = live.show;
        if (mem.kickoffRemainingSec > 0.0 || show.trackTimeSec <= 7.0) {
          mem.currentReaction = CrowdReactionKind.setKickoff;
        } else if (show.sectionMode == LightShowSectionMode.outroFade) {
          mem.currentReaction = CrowdReactionKind.encoreOvation;
          if (mem.calloutCooldownSec <= 0.0) {
            mem.calloutCooldownSec = 5.2;
            _emitStageAudienceCallout(
              stageId: stageId,
              namedNpcs: namedNpcs,
              options: const ['👏 ENCORE!!', '🌹 SO GOOD!!', '🙌 BRAVO!'],
            );
          }
        } else if (show.sectionMode == LightShowSectionMode.soloShred ||
            show.sectionMode == LightShowSectionMode.climaxPrism ||
            show.kickDrop ||
            (show.accentKind == LightShowAccentKind.leadRiff &&
                show.accentFlash > 0.42)) {
          mem.currentReaction = CrowdReactionKind.soloOrDrop;
          if (mem.calloutCooldownSec <= 0.0) {
            mem.calloutCooldownSec = 4.6;
            _emitStageAudienceCallout(
              stageId: stageId,
              namedNpcs: namedNpcs,
              options: const [
                '🔥 WHAT A SOLO!',
                '⚡ PURE ELECTRIC!',
                '🙌 FEEL THAT BASS!',
                '🎸 FAR OUT!!',
              ],
            );
          }
        } else if (show.sectionMode == LightShowSectionMode.hushGlow ||
            show.sectionMode == LightShowSectionMode.introDawn) {
          mem.currentReaction = CrowdReactionKind.hushSway;
          if (mem.calloutCooldownSec <= 0.0) {
            mem.calloutCooldownSec = 7.5;
            _emitStageAudienceCallout(
              stageId: stageId,
              namedNpcs: namedNpcs,
              options: const ['✨ Slow-wave sway...', '🕯️ Pure magic...'],
            );
          }
        } else {
          mem.currentReaction = CrowdReactionKind.none;
        }
      } else {
        // Set on this stage just ended! Trigger standing ovation & post-set food rush!
        if (mem.activeTrackId != null) {
          mem.activeTrackId = null;
          if (!clockJumped) {
            mem.ovationRemainingSec = 8.5;
            _postSetFoodRushSec = 28.0;
            if (stageInfo != null) {
              onCelebrationBurst?.call(Offset(stageInfo.x, stageInfo.y + 92.0));
            }
            _emitStageAudienceCallout(
              stageId: stageId,
              namedNpcs: namedNpcs,
              options: const ['👏 ENCORE!!', '🌹 THANK YOU!!', '✌️ PEACE & MUSIC!'],
            );
          }
        }
        mem.currentReaction = mem.ovationRemainingSec > 0.0
            ? CrowdReactionKind.encoreOvation
            : CrowdReactionKind.none;
      }
    }
  }

  void _emitStageAudienceCallout({
    required String stageId,
    required List<NpcActor> namedNpcs,
    required List<String> options,
  }) {
    final st = catalog.stages[stageId];
    if (st == null || options.isEmpty) return;
    final stagePt = Vector2(st.x, st.y);

    final nearGoers = _allGoers
        .where(
          (g) =>
              g.isPresentToday &&
              !g.isMoving &&
              g.position.distanceTo(stagePt) <= 290.0,
        )
        .toList(growable: false);
    if (nearGoers.isNotEmpty) {
      final chosen = nearGoers[_rng.nextInt(nearGoers.length)];
      chosen.triggerCallout(options[_rng.nextInt(options.length)]);
    }

    final nearNpcs = namedNpcs
        .where(
          (n) =>
              !n.isOnStagePerforming &&
              !n.isMoving &&
              n.position.distanceTo(stagePt) <= 290.0,
        )
        .toList(growable: false);
    if (nearNpcs.isNotEmpty) {
      final chosenNpc = nearNpcs[_rng.nextInt(nearNpcs.length)];
      chosenNpc.triggerPerformanceCallout(
        options[_rng.nextInt(options.length)],
      );
    }
  }

  void _stepFoodQueues({
    required double dt,
    required bool falafelTruceReady,
    required List<NpcActor> namedNpcs,
    required bool heavyRain,
    required Map<String, LiveStageVisualState> liveStages,
    required FestivalClockState clock,
  }) {
    for (final queue in _foodQueues.values) {
      // Prune any invalid/absent members
      queue.memberKeys.removeWhere((key) => !_isQueueMemberValid(key, namedNpcs));
      if (queue.memberKeys.isEmpty) {
        queue.serviceTimerSec = 0.0;
        continue;
      }

      // Sync slot positions for everyone in line
      for (var slot = 0; slot < queue.memberKeys.length; slot++) {
        final key = queue.memberKeys[slot];
        final slotPos = queue.slotPositionFor(slot);
        _updateQueueMemberSlot(key, queue.spec.id, slot, slotPos, namedNpcs);
      }

      // Advance service timer once front-of-line customer (slot 0) has arrived at counter
      final frontKey = queue.memberKeys.first;
      if (_hasQueueMemberArrivedAtCounter(frontKey, namedNpcs)) {
        final serviceSeconds =
            (queue.spec.id == 'falafel_stand' && !falafelTruceReady)
                ? 10.5
                : 5.5;
        queue.serviceTimerSec += dt;
        if (queue.spec.id == 'falafel_stand' &&
            !falafelTruceReady &&
            (queue.serviceTimerSec - 3.2).abs() < dt * 1.2) {
          _triggerQueueMemberCallout(
            frontKey,
            '🪰 Mind the cider-flies!',
            namedNpcs,
          );
        }
        if (queue.serviceTimerSec >= serviceSeconds) {
          queue.serviceTimerSec = 0.0;
          queue.servedCount += 1;
          queue.memberKeys.removeAt(0);
          final treat = queue.spec
              .menuTreats[queue.servedCount % queue.spec.menuTreats.length];
          _completeFoodServiceForMember(
            key: frontKey,
            emoji: treat.$1,
            callout: treat.$2,
            namedNpcs: namedNpcs,
            heavyRain: heavyRain,
            liveStages: liveStages,
            clock: clock,
          );
          // Immediately step remaining customers forward one slot!
          for (var slot = 0; slot < queue.memberKeys.length; slot++) {
            final nextKey = queue.memberKeys[slot];
            _updateQueueMemberSlot(
              nextKey,
              queue.spec.id,
              slot,
              queue.slotPositionFor(slot),
              namedNpcs,
            );
          }
        }
      }
    }
  }

  bool _isQueueMemberValid(String key, List<NpcActor> namedNpcs) {
    if (key.startsWith('crowd:')) {
      final id = key.substring(6);
      final g = _goerById(id);
      return g != null &&
          g.isPresentToday &&
          (g.activity == FestivalCrowdActivity.walkingToFoodLine ||
              g.activity == FestivalCrowdActivity.queuingInFoodLine);
    }
    if (key.startsWith('npc:')) {
      final id = key.substring(4);
      final n = _npcById(id, namedNpcs);
      return n != null &&
          !n.isOnStagePerforming &&
          n.stageMark == null &&
          !n.migrateToMainRoots &&
          (n.autonomousActivity == NpcAutonomousActivity.walkingToFoodLine ||
              n.autonomousActivity == NpcAutonomousActivity.queuingInFoodLine);
    }
    return false;
  }

  bool _hasQueueMemberArrivedAtCounter(String key, List<NpcActor> namedNpcs) {
    if (key.startsWith('crowd:')) {
      final g = _goerById(key.substring(6));
      return g != null && g.isQueuingForFood;
    }
    if (key.startsWith('npc:')) {
      final n = _npcById(key.substring(4), namedNpcs);
      return n != null && n.isQueuingForFood;
    }
    return false;
  }

  void _triggerQueueMemberCallout(
    String key,
    String text,
    List<NpcActor> namedNpcs,
  ) {
    if (key.startsWith('crowd:')) {
      _goerById(key.substring(6))?.triggerCallout(text);
    } else if (key.startsWith('npc:')) {
      _npcById(key.substring(4), namedNpcs)?.triggerPerformanceCallout(text);
    }
  }

  void _updateQueueMemberSlot(
    String key,
    String stallId,
    int slot,
    Offset slotPos,
    List<NpcActor> namedNpcs,
  ) {
    if (key.startsWith('crowd:')) {
      final g = _goerById(key.substring(6));
      if (g == null) return;
      if (g.foodQueueSlot != slot ||
          g.targetPoint == null ||
          (g.targetPoint! - slotPos).distance > 3.0) {
        final dist = g.position.distanceTo(Vector2(slotPos.dx, slotPos.dy));
        g.assignGoal(
          nextActivity: dist <= 28.0
              ? FestivalCrowdActivity.queuingInFoodLine
              : FestivalCrowdActivity.walkingToFoodLine,
          goal: slotPos,
          nextFacingOverride: 3,
          foodStallId: stallId,
          queueSlot: slot,
          holdSeconds: 30.0,
        );
      }
    } else if (key.startsWith('npc:')) {
      final n = _npcById(key.substring(4), namedNpcs);
      if (n == null) return;
      if (n.autonomousFoodQueueSlot != slot ||
          n.autonomousTarget == null ||
          (n.autonomousTarget! - slotPos).distance > 3.0) {
        final dist = n.position.distanceTo(Vector2(slotPos.dx, slotPos.dy));
        n.setAutonomousDirective(
          activity: dist <= 28.0
              ? NpcAutonomousActivity.queuingInFoodLine
              : NpcAutonomousActivity.walkingToFoodLine,
          target: slotPos,
          facingOverride: 3,
          foodStallId: stallId,
          queueSlot: slot,
        );
      }
    }
  }

  void _completeFoodServiceForMember({
    required String key,
    required String emoji,
    required String callout,
    required List<NpcActor> namedNpcs,
    required bool heavyRain,
    required Map<String, LiveStageVisualState> liveStages,
    required FestivalClockState clock,
  }) {
    final targetStages = _candidateActiveOrUpcomingStages(liveStages, clock);
    if (key.startsWith('crowd:')) {
      final g = _goerById(key.substring(6));
      if (g == null) return;
      g.grantServedTreat(emoji, callout);
      if (!heavyRain && _rng.nextDouble() < 0.58) {
        if (_tryAssignBlanketToGoer(g, namedNpcs, liveStages)) {
          return;
        }
      }
      if (targetStages.isNotEmpty) {
        final chosenStage = _pickStageForPreference(
          targetStages,
          g.spec.favoriteStageId,
        );
        _sendGoerToStage(g, chosenStage);
      } else {
        _sendGoerStrolling(g);
      }
    } else if (key.startsWith('npc:')) {
      final n = _npcById(key.substring(4), namedNpcs);
      if (n == null) return;
      n.grantServedTreat(emoji, callout);
      if (!heavyRain && _rng.nextDouble() < 0.50) {
        if (_tryAssignBlanketToNpc(n, namedNpcs, liveStages)) {
          return;
        }
      }
      if (targetStages.isNotEmpty) {
        final chosenStage = targetStages[_rng.nextInt(targetStages.length)];
        _sendNpcToStage(n, chosenStage);
      } else {
        n.clearAutonomousDirective();
      }
    }
  }

  void _removeFromFoodQueues(String key) {
    for (final q in _foodQueues.values) {
      q.memberKeys.remove(key);
    }
  }

  void _evictBlanketSitters(String blanketId, List<NpcActor> namedNpcs) {
    for (final g in _allGoers) {
      if (g.targetBlanketId == blanketId) {
        g.targetBlanketId = null;
        g.blanketSeatIndex = null;
        g.stateHoldTimerSec = 0.0;
      }
    }
    for (final n in namedNpcs) {
      if (n.autonomousActivity == NpcAutonomousActivity.sittingOnBlanket) {
        n.clearAutonomousDirective();
      }
    }
  }

  int _desiredTotalFoodQueueCount(FestivalClockState clock, bool finaleActive) {
    if (finaleActive) return 0;
    final m = clock.minuteOfDay;
    final isMealRush = (m >= 420.0 && m <= 585.0) || // Morning espresso & tea
        (m >= 690.0 && m <= 855.0) || // Midday falafel rush
        (m >= 1035.0 && m <= 1220.0) || // Sunset dinner rush
        _postSetFoodRushSec > 0.0;
    final dayBonus = clock.day == 1 ? 0 : (clock.day == 2 ? 2 : 3);
    return (isMealRush ? 5 + dayBonus : 2 + (dayBonus ~/ 2)).clamp(2, 10);
  }

  List<String> _candidateActiveOrUpcomingStages(
    Map<String, LiveStageVisualState> liveStages,
    FestivalClockState clock,
  ) {
    final stages = <String>[
      for (final stageId in liveStages.keys)
        if (stageId != 'pa_global_horn' && catalog.stages.containsKey(stageId))
          stageId,
    ];
    // Also pre-gather at stages whose next scheduled set starts within 9 clock minutes!
    for (final track in catalog.tracks) {
      if (track.day != clock.day || track.isPaBroadcast) continue;
      if (stages.contains(track.stageId)) continue;
      if (!catalog.stages.containsKey(track.stageId)) continue;
      final minsUntil = track.startMinute - clock.minuteOfDay;
      if (minsUntil > 0.0 && minsUntil <= 9.0) {
        stages.add(track.stageId);
      }
    }
    return stages;
  }

  void _rebalanceEcosystem({
    required FestivalClockState clock,
    required WorldFlags flags,
    required Map<String, LiveStageVisualState> liveStages,
    required List<NpcActor> namedNpcs,
    required bool heavyRain,
    required bool snapImmediately,
  }) {
    final finaleActive = flags.crowdMigrateMainRoots;
    final targetStages = finaleActive
        ? const <String>['main_roots_stage']
        : _candidateActiveOrUpcomingStages(liveStages, clock);

    // 1. Top up Vendor Row food lines when hungry festivalgoers are available!
    final desiredQueued = _desiredTotalFoodQueueCount(clock, finaleActive);
    var currentQueued = totalQueuedForFoodCount;
    if (currentQueued < desiredQueued) {
      for (final goer in _allGoers) {
        if (currentQueued >= desiredQueued) break;
        if (!goer.isPresentToday) continue;
        if (goer.activity == FestivalCrowdActivity.walkingToFoodLine ||
            goer.activity == FestivalCrowdActivity.queuingInFoodLine) {
          continue;
        }
        // Prefer festivalgoers whose timer expired or who aren't in the middle of an ovation
        if (!snapImmediately &&
            goer.stateHoldTimerSec > 4.0 &&
            goer.activity == FestivalCrowdActivity.dancingAtStage) {
          continue;
        }
        if (_tryEnqueueForFood('crowd:${goer.spec.id}', namedNpcs,
            snapImmediately: snapImmediately)) {
          currentQueued++;
        }
      }
    }

    // 2. Assign Blanket Loungers on dry lawns (including player's deployed blanket!)
    final desiredSitters = (heavyRain || finaleActive)
        ? 0
        : (clock.day == 1 ? 4 : (clock.day == 2 ? 7 : 9));
    var currentSitters = countSeatedActors(namedNpcs);
    if (currentSitters < desiredSitters) {
      for (final goer in _allGoers) {
        if (currentSitters >= desiredSitters) break;
        if (!goer.isPresentToday) continue;
        if (goer.activity == FestivalCrowdActivity.sittingOnBlanket ||
            goer.activity == FestivalCrowdActivity.walkingToFoodLine ||
            goer.activity == FestivalCrowdActivity.queuingInFoodLine) {
          continue;
        }
        if (!snapImmediately && goer.stateHoldTimerSec > 3.0) continue;
        if (_tryAssignBlanketToGoer(
          goer,
          namedNpcs,
          liveStages,
          snapImmediately: snapImmediately,
        )) {
          currentSitters++;
        }
      }
    }

    // 3. Route remaining FestivalGoers to live/upcoming Concert Stages (or scenic strolls)!
    for (final goer in _allGoers) {
      if (!goer.isPresentToday) continue;
      if (goer.activity == FestivalCrowdActivity.walkingToFoodLine ||
          goer.activity == FestivalCrowdActivity.queuingInFoodLine) {
        continue;
      }

      if (finaleActive) {
        if (goer.targetStageId != 'main_roots_stage') {
          _sendGoerToStage(
            goer,
            'main_roots_stage',
            snapImmediately: snapImmediately,
          );
        }
        continue;
      }

      // If dancing at a stage whose set AND ovation have both finished, migrate!
      if (goer.activity == FestivalCrowdActivity.dancingAtStage ||
          goer.activity == FestivalCrowdActivity.wanderingToStage) {
        final stId = goer.targetStageId;
        final stillActiveOrOvating = stId != null &&
            (targetStages.contains(stId) ||
                (_stageReactions[stId]?.ovationRemainingSec ?? 0.0) > 0.0);
        if (stillActiveOrOvating && !snapImmediately) {
          continue;
        }
      }

      if (goer.activity == FestivalCrowdActivity.sittingOnBlanket &&
          !heavyRain &&
          goer.stateHoldTimerSec > 0.0 &&
          !snapImmediately) {
        continue;
      }

      if (goer.stateHoldTimerSec > 0.0 &&
          !snapImmediately &&
          goer.targetPoint != null &&
          targetStages.isEmpty) {
        continue;
      }

      if (targetStages.isNotEmpty) {
        final stageId =
            _pickStageForPreference(targetStages, goer.spec.favoriteStageId);
        _sendGoerToStage(goer, stageId, snapImmediately: snapImmediately);
      } else if (!heavyRain &&
          _tryAssignBlanketToGoer(
            goer,
            namedNpcs,
            liveStages,
            snapImmediately: snapImmediately,
          )) {
        continue;
      } else {
        _sendGoerStrolling(goer, snapImmediately: snapImmediately);
      }
    }

    // 4. Route Free-Roaming Named NPCs (Nora, Raymond, Elsie, Pippin, Saffron, Orion, Wen-wan, & post-truce Burt)!
    for (final npc in namedNpcs) {
      final canRoam = _roamingNamedNpcIds.contains(npc.spec.id) ||
          (npc.spec.id == 'burt_baskernut' && flags.burtQuestCompleted);
      if (!canRoam) continue;
      if (npc.stageMark != null || npc.isOnStagePerforming) {
        _removeFromFoodQueues('npc:${npc.spec.id}');
        npc.clearAutonomousDirective();
        continue;
      }
      if (finaleActive) {
        _removeFromFoodQueues('npc:${npc.spec.id}');
        npc.clearAutonomousDirective();
        continue;
      }
      if (npc.autonomousActivity == NpcAutonomousActivity.walkingToFoodLine ||
          npc.autonomousActivity == NpcAutonomousActivity.queuingInFoodLine) {
        continue;
      }

      // Keep playing stage if still live!
      if (npc.autonomousActivity == NpcAutonomousActivity.dancingAtStage ||
          npc.autonomousActivity == NpcAutonomousActivity.wanderingToStage) {
        final stId = npc.autonomousTargetStageId;
        if (stId != null &&
            (targetStages.contains(stId) ||
                (_stageReactions[stId]?.ovationRemainingSec ?? 0.0) > 0.0) &&
            !snapImmediately) {
          continue;
        }
      }

      // Occasional food queue visit for roaming Named NPCs during meal rushes
      if (totalQueuedForFoodCount < desiredQueued &&
          _rng.nextDouble() < 0.18 &&
          _tryEnqueueForFood('npc:${npc.spec.id}', namedNpcs,
              snapImmediately: snapImmediately)) {
        continue;
      }

      if (targetStages.isNotEmpty) {
        final preferred = _preferredStageForNamedNpc(npc.spec.id);
        final stageId = _pickStageForPreference(targetStages, preferred);
        _sendNpcToStage(npc, stageId, snapImmediately: snapImmediately);
      } else if (!heavyRain &&
          _rng.nextDouble() < 0.55 &&
          _tryAssignBlanketToNpc(
            npc,
            namedNpcs,
            liveStages,
            snapImmediately: snapImmediately,
          )) {
        continue;
      } else {
        npc.clearAutonomousDirective();
      }
    }
  }

  String _preferredStageForNamedNpc(String npcId) {
    return switch (npcId) {
      'raymond_walnut' || 'saffron_suture' => 'velvet_canopy_stage',
      'elsie_walnut' || 'orion_kernel' => 'andromeda_pavilion_stage',
      'pippin_pecan' => 'mellow_meadow_stage',
      'wen_wan_elder' => 'urbano_canopy_stage',
      _ => 'main_roots_stage',
    };
  }

  String _pickStageForPreference(List<String> available, String favorite) {
    if (available.length == 1) return available.first;
    if (available.contains(favorite) && _rng.nextDouble() < 0.68) {
      return favorite;
    }
    return available[_rng.nextInt(available.length)];
  }

  bool _tryEnqueueForFood(
    String memberKey,
    List<NpcActor> namedNpcs, {
    bool snapImmediately = false,
  }) {
    final candidates = _foodQueues.values
        .where((q) => !q.isFull && !q.memberKeys.contains(memberKey))
        .toList(growable: false);
    if (candidates.isEmpty) return false;
    // Pick the shortest line!
    candidates.sort((a, b) => a.length.compareTo(b.length));
    final chosen = candidates.first;
    final slot = chosen.length;
    chosen.memberKeys.add(memberKey);
    final slotPos = chosen.slotPositionFor(slot);

    if (memberKey.startsWith('crowd:')) {
      final g = _goerById(memberKey.substring(6));
      if (g != null) {
        g.assignGoal(
          nextActivity: snapImmediately
              ? FestivalCrowdActivity.queuingInFoodLine
              : FestivalCrowdActivity.walkingToFoodLine,
          goal: slotPos,
          nextFacingOverride: 3,
          foodStallId: chosen.spec.id,
          queueSlot: slot,
          holdSeconds: 32.0,
          snapImmediately: snapImmediately,
        );
      }
    } else if (memberKey.startsWith('npc:')) {
      final n = _npcById(memberKey.substring(4), namedNpcs);
      if (n != null) {
        n.setAutonomousDirective(
          activity: snapImmediately
              ? NpcAutonomousActivity.queuingInFoodLine
              : NpcAutonomousActivity.walkingToFoodLine,
          target: slotPos,
          facingOverride: 3,
          foodStallId: chosen.spec.id,
          queueSlot: slot,
          snapImmediately: snapImmediately,
        );
      }
    }
    return true;
  }

  Set<(String, int)> _occupiedBlanketSeats(List<NpcActor> namedNpcs) {
    final used = <(String, int)>{};
    for (final g in _allGoers) {
      if (!g.isPresentToday) continue;
      if (g.activity == FestivalCrowdActivity.sittingOnBlanket &&
          g.targetBlanketId != null &&
          g.blanketSeatIndex != null) {
        used.add((g.targetBlanketId!, g.blanketSeatIndex!));
      }
    }
    for (final n in namedNpcs) {
      if (n.autonomousActivity == NpcAutonomousActivity.sittingOnBlanket &&
          n.autonomousTarget != null) {
        for (final b in activeBlanketSpots) {
          for (var i = 0; i < b.seats.length; i++) {
            if ((b.seats[i] - n.autonomousTarget!).distance < 8.0) {
              used.add((b.id, i));
            }
          }
        }
      }
    }
    return used;
  }

  bool _tryAssignBlanketToGoer(
    FestivalGoerActor goer,
    List<NpcActor> namedNpcs,
    Map<String, LiveStageVisualState> liveStages, {
    bool snapImmediately = false,
  }) {
    final spots = activeBlanketSpots;
    if (spots.isEmpty) return false;
    final used = _occupiedBlanketSeats(namedNpcs);

    // Prioritize player's deployed blanket first if open, then blankets near live stages!
    final ordered = [...spots]..sort((a, b) {
        if (a.isPlayerBlanket != b.isPlayerBlanket) {
          return a.isPlayerBlanket ? -1 : 1;
        }
        final aLive =
            a.preferredStageId != null && liveStages.containsKey(a.preferredStageId);
        final bLive =
            b.preferredStageId != null && liveStages.containsKey(b.preferredStageId);
        if (aLive != bLive) return aLive ? -1 : 1;
        return 0;
      });

    for (final blanket in ordered) {
      for (var s = 0; s < blanket.seats.length; s++) {
        if (!used.contains((blanket.id, s))) {
          final seatPos = blanket.seats[s];
          final facing = blanket.preferredStageId != null ? 3 : (s == 0 ? 2 : 1);
          goer.assignGoal(
            nextActivity: FestivalCrowdActivity.sittingOnBlanket,
            goal: seatPos,
            nextFacingOverride: facing,
            blanketId: blanket.id,
            seatIdx: s,
            stageId: blanket.preferredStageId,
            holdSeconds: 26.0 + _rng.nextDouble() * 18.0,
            snapImmediately: snapImmediately,
          );
          return true;
        }
      }
    }
    return false;
  }

  bool _tryAssignBlanketToNpc(
    NpcActor npc,
    List<NpcActor> namedNpcs,
    Map<String, LiveStageVisualState> liveStages, {
    bool snapImmediately = false,
  }) {
    final spots = activeBlanketSpots;
    if (spots.isEmpty) return false;
    final used = _occupiedBlanketSeats(namedNpcs);

    for (final blanket in spots) {
      for (var s = 0; s < blanket.seats.length; s++) {
        if (!used.contains((blanket.id, s))) {
          final seatPos = blanket.seats[s];
          final facing = blanket.preferredStageId != null ? 3 : 0;
          npc.setAutonomousDirective(
            activity: NpcAutonomousActivity.sittingOnBlanket,
            target: seatPos,
            facingOverride: facing,
            stageId: blanket.preferredStageId,
            snapImmediately: snapImmediately,
          );
          return true;
        }
      }
    }
    return false;
  }

  void _sendGoerToStage(
    FestivalGoerActor goer,
    String stageId, {
    bool snapImmediately = false,
  }) {
    final spot = _pickBowlSpotForActor(stageId, goer.spec.id.hashCode);
    goer.assignGoal(
      nextActivity: snapImmediately
          ? FestivalCrowdActivity.dancingAtStage
          : FestivalCrowdActivity.wanderingToStage,
      goal: spot,
      nextFacingOverride: 3,
      stageId: stageId,
      holdSeconds: 28.0 + _rng.nextDouble() * 16.0,
      snapImmediately: snapImmediately,
    );
  }

  void _sendNpcToStage(
    NpcActor npc,
    String stageId, {
    bool snapImmediately = false,
  }) {
    final spot = _pickBowlSpotForActor(stageId, npc.spec.id.hashCode);
    npc.setAutonomousDirective(
      activity: snapImmediately
          ? NpcAutonomousActivity.dancingAtStage
          : NpcAutonomousActivity.wanderingToStage,
      target: spot,
      facingOverride: 3,
      stageId: stageId,
      snapImmediately: snapImmediately,
    );
  }

  Offset _pickBowlSpotForActor(String stageId, int seedHash) {
    final anchors =
        _stageBowlAnchors[stageId] ?? _stageBowlAnchors['main_roots_stage']!;
    final base = anchors[seedHash.abs() % anchors.length];
    final jx = ((seedHash.abs() ~/ 7) % 19) - 9.0;
    final jy = ((seedHash.abs() ~/ 13) % 15) - 7.0;
    return snapToWalkable(base.dx + jx, base.dy + jy);
  }

  void _sendGoerStrolling(
    FestivalGoerActor goer, {
    bool snapImmediately = false,
  }) {
    final wp =
        _scenicStrollWaypoints[_rng.nextInt(_scenicStrollWaypoints.length)];
    final goal = snapToWalkable(
      wp.dx + (_rng.nextDouble() - 0.5) * 28.0,
      wp.dy + (_rng.nextDouble() - 0.5) * 24.0,
    );
    goer.assignGoal(
      nextActivity: FestivalCrowdActivity.strollingOrchard,
      goal: goal,
      holdSeconds: 18.0 + _rng.nextDouble() * 14.0,
      snapImmediately: snapImmediately,
    );
  }

  FestivalGoerActor? _goerById(String id) {
    for (final g in _allGoers) {
      if (g.spec.id == id) return g;
    }
    return null;
  }

  NpcActor? _npcById(String id, List<NpcActor> namedNpcs) {
    for (final n in namedNpcs) {
      if (n.spec.id == id) return n;
    }
    return null;
  }

  (FestivalGoerActor, double)? nearestFestivalGoerWithDist(
    Vector2 pos, {
    required double maxRadius,
  }) {
    FestivalGoerActor? best;
    var bestDist = maxRadius;
    for (final goer in _allGoers) {
      if (!goer.isPresentToday) continue;
      final d = goer.position.distanceTo(pos);
      if (d < bestDist) {
        bestDist = d;
        best = goer;
      }
    }
    return best == null ? null : (best, bestDist);
  }

  /// Builds dynamic, 3-day-evolving dialogue for any interactive `FestivalGoerActor`,
  /// reflecting the current festival day, live performance, weather/mud, and activity!
  List<String> buildFestivalGoerDialogue({
    required FestivalGoerActor goer,
    required FestivalClockState clock,
    required WorldFlags flags,
    required Map<String, LiveStageVisualState> liveStages,
  }) {
    final lines = <String>[];
    final day = clock.encoreModeUnlocked ? 3 : clock.day;
    final muddy = clock.isOrchardMuddy(catalog);
    final blueberryActive =
        flags.isBlueberryRainbowActiveAt(clock.day, clock.minuteOfDay) ||
            clock.isDay2BlueberrySharingActive;

    // 1. Immediate Activity / Performance / Queue / Blanket Hook
    switch (goer.activity) {
      case FestivalCrowdActivity.queuingInFoodLine:
      case FestivalCrowdActivity.walkingToFoodLine:
        final stall = _foodQueues[goer.targetFoodStallId];
        final stallName = stall?.spec.displayName ?? 'Vendor Row';
        final posInLine = (goer.foodQueueSlot ?? 0) + 1;
        if (goer.targetFoodStallId == 'falafel_stand' &&
            !flags.burtQuestCompleted &&
            !flags.falafelTruceUnlocked &&
            day == 1) {
          lines.add(
            "I'm #$posInLine in line at $stallName, and a whole squadron of blowflies is buzzing the pita counter! Folks say Burt Baskernut needs help pouring sweet cider for a truce.",
          );
        } else if (posInLine == 1) {
          lines.add(
            "Right at the front of $stallName! Nothing refuels three days of orchard dancing like hot tahini falafel and spiced persimmon cider.",
          );
        } else {
          lines.add(
            "Waiting #$posInLine in line at $stallName—half the fun of Vendor Row is swapping setlist tips with everyone in the queue!",
          );
        }
        break;

      case FestivalCrowdActivity.sittingOnBlanket:
        if (goer.targetBlanketId == 'blanket_player_custom') {
          lines.add(
            "Hope you don't mind me sharing a corner of your Woven Picnic Blanket! Best view and softest clover in the whole Free Orchard.",
          );
        } else {
          final treatNote = goer.heldTreatEmoji != null
              ? ' Just grabbed ${goer.heldTreatEmoji} from Vendor Row and resting my boots.'
              : '';
          lines.add(
            "Pull up a corner of the blanket, friend!$treatNote Listening to the music drift through the walnut leaves from the grass is pure 1969 bliss.",
          );
        }
        break;

      case FestivalCrowdActivity.wanderingToStage:
        final stId = goer.targetStageId;
        final stName =
            stId != null ? (catalog.stages[stId]?.name ?? stId) : 'the next stage';
        final live = stId != null ? liveStages[stId] : null;
        if (live != null) {
          lines.add(
            "Come on—${live.track.artist} is live at $stName playing \"${live.track.title}\"! Follow the crowd up the lane!",
          );
        } else {
          lines.add(
            "Walking over toward $stName to grab a good spot on the lawn before the next band plugs in!",
          );
        }
        break;

      case FestivalCrowdActivity.dancingAtStage:
        final stId = goer.targetStageId;
        final stName =
            stId != null ? (catalog.stages[stId]?.name ?? stId) : 'this stage';
        final live = stId != null ? liveStages[stId] : null;
        if (goer.performanceReaction == CrowdReactionKind.soloOrDrop &&
            live != null) {
          lines.add(
            "DID YOU HEAR THAT SOLO?! ${live.track.artist} is tearing the canopy clean off $stName on \"${live.track.title}\"!!",
          );
        } else if (goer.performanceReaction == CrowdReactionKind.encoreOvation) {
          lines.add(
            "👏 ENCORE!! My palms are tingling from clapping—what a legendary set at $stName!",
          );
        } else if (goer.performanceReaction == CrowdReactionKind.hushSway &&
            live != null) {
          lines.add(
            "Shhh... sway with us for a beat. When \"${live.track.title}\" drops into this gentle groove, the whole meadow breathes as one.",
          );
        } else if (live != null) {
          lines.add(
            "Locked right into ${live.show.bpm.round()} BPM for \"${live.track.title}\" by ${live.track.artist}! Tap Dance to groove with us!",
          );
        } else {
          lines.add(
            "Holding down the dancefloor at $stName—my shell still hums from the last bassline!",
          );
        }
        break;

      case FestivalCrowdActivity.strollingOrchard:
        final snack = goer.heldTreatEmoji != null
            ? ' Enjoying my ${goer.heldTreatEmoji} while strolling between groves!'
            : '';
        lines.add(
          "Just wandering the orchard paths listening to how the spatial stereo mix shifts between tree canopies!$snack",
        );
        break;
    }

    // 2. Progressive Day 1 -> Day 2 -> Day 3 Cultural & Story Evolution!
    if (clock.encoreModeUnlocked) {
      lines.add(
        "Three days came and went, the fences stayed down, and nobody wants to pack up their blankets—welcome to Endless Encore, cousin!",
      );
    } else if (day == 1) {
      if (!flags.fencesDropped) {
        lines.add(
          "Day 1 just kicked off and cars are backed up three miles past Max Yasgur-Shell's lane—rumor is Patchouli Pete's about to declare a Free Orchard!",
        );
      } else if (muddy) {
        lines.add(
          "Friday night's downpour turned the meadow into a giant Woodstock Mud Pit! Everybody's belly-sliding instead of hiding in tents!",
        );
      } else {
        lines.add(
          "Day 1 energy is electric—fresh blankets on the grass, strangers trading their first Peace Beads, and two whole days of music still ahead!",
        );
      }
    } else if (day == 2) {
      if (blueberryActive) {
        lines.add(
          "Happy Saturday! Folks by Willow Creek have been passing around Electric Purple Blueberries all morning—swear the walnut trees are waving in rainbow colors!",
        );
      } else if (clock.minuteOfDay >= 1400.0) {
        lines.add(
          "Saturday Midnight madness: Don Shell-O is booming Urbano Canopy in the southwest while Cosmo floats Andromeda Dome in the northeast—half the crowd is sprinting between both!",
        );
      } else {
        lines.add(
          "Look how much bigger Saturday's crowd grew overnight! Half of us still have Friday mud on our boots, seven blanket circles are out, and Janice's vocals are shaking the cliffs.",
        );
      }
    } else {
      // Day 3 (Sunday)
      if (flags.crowdMigrateMainRoots || clock.minuteOfDay >= 1180.0) {
        lines.add(
          "It's Sunday night—every blanket camp and grove across the farm is streaming toward Main Roots Stage for The Grateful Nut and Jimi Hendshell's Purple Haze finale!",
        );
      } else {
        lines.add(
          "By Day 3, forty thousand walnuts feel like one big orchard family. People are sharing their last cider, trading bootleg stories, and saving strength for tonight's Main Roots closer!",
        );
      }
    }

    return lines;
  }

  /// Appends authentic Day 1 / Day 2 / Day 3 + live-activity progression lines to Named NPC
  /// ambient & post-quest conversations without altering quest turn-in mechanics!
  List<String> enrichNamedNpcDialogue({
    required NpcSpec npc,
    required NpcActor? actor,
    required List<String> baseLines,
    required bool isAmbientOrCompletedState,
    required FestivalClockState clock,
    required WorldFlags flags,
    required Map<String, LiveStageVisualState> liveStages,
  }) {
    if (!isAmbientOrCompletedState) {
      return baseLines;
    }

    final day = clock.encoreModeUnlocked ? 3 : clock.day;
    final out = <String>[...baseLines];

    // If a roaming Named NPC is currently queuing for food, sitting on a blanket, or visiting another stage, mention it!
    if (actor != null) {
      if (actor.isQueuingForFood) {
        out.add(
          "Even ${npc.name} couldn't resist hopping in the Vendor Row food line—smell that fresh tahini and spiced cider!",
        );
        return out;
      }
      if (actor.isSittingOnBlanket) {
        out.add(
          "Taking five on a woven lawn blanket to soak in the Day $day breeze before the next set kicks in!",
        );
      } else if (actor.autonomousTargetStageId != null &&
          liveStages.containsKey(actor.autonomousTargetStageId)) {
        final live = liveStages[actor.autonomousTargetStageId]!;
        final stName =
            catalog.stages[actor.autonomousTargetStageId!]?.name ?? 'the stage';
        out.add(
          "Had to wander over to $stName for ${live.track.artist}'s \"${live.track.title}\"—listen to this crowd roar!",
        );
      }
    }

    // Day-specific progression reflection tailored to Day 1 vs Day 2 vs Day 3!
    final dayLine = _dayReflectionForNamedNpc(
      npcId: npc.id,
      day: day,
      clock: clock,
      flags: flags,
      encore: clock.encoreModeUnlocked,
    );
    if (dayLine != null) {
      out.add(dayLine);
    }
    return out;
  }

  String? _dayReflectionForNamedNpc({
    required String npcId,
    required int day,
    required FestivalClockState clock,
    required WorldFlags flags,
    required bool encore,
  }) {
    if (encore) {
      return 'Endless Encore Mode is live—all three days of Walnutstock echo across the groves whenever you drop the needle!';
    }
    switch (npcId) {
      case 'nora_walnut':
        return switch (day) {
          1 =>
            'Day 1 Friday: Seeing the first wave of hitchhikers stream past the Front Gate gives me goosebumps!',
          2 =>
            'Day 2 Saturday: Twice as many blankets cover the grass today—and everybody’s talking about creekside Electric Blueberries!',
          _ =>
            'Day 3 Sunday: Everyone who walked in as strangers on Friday is hugging like old cousins before Jimi’s finale tonight!',
        };
      case 'raymond_walnut':
        return switch (day) {
          1 =>
            'Day 1 check: The tube amps are just warming up—wait till Friday night’s rain hits the stage lights!',
          2 =>
            'Day 2 report: Saturday’s crowd packed Velvet Canopy wall-to-wall, mud-splattered shells and all!',
          _ =>
            'Day 3 reflection: My voice is gloriously hoarse from cheering solos all weekend—saving one last shout for Main Roots tonight!',
        };
      case 'elsie_walnut':
        return switch (day) {
          1 =>
            'Friday Page 1 of my sketchbook: clean shells, fresh daisies, and four early picnic blankets on the lawn.',
          2 =>
            'Saturday Page 14: Mud slides, rainbow blueberry ripples, and long joyful lines down Vendor Row!',
          _ =>
            'Sunday Page 30: Every inch of grass is a patchwork quilt of friends converging on Main Roots Stage.',
        };
      case 'wen_wan_elder':
        return switch (day) {
          1 =>
            'On Day 1, the young kernels hurry from stage to stage; by Sunday, the orchard teaches them to sway.',
          2 =>
            'Day 2 brings both rainstorm mud and midnight sub-bass—yin and yang in 1969 stereo.',
          _ =>
            'Day 3 has arrived: forty thousand shells breathing one harmonic chord before the Great Walnut Ritual.',
        };
      case 'hazel_groove':
        return switch (day) {
          1 =>
            'Friday warmup! Plenty of elbow room up front to practice your four-step boogie and beach-ball headers!',
          2 =>
            'Saturday peak! Did you catch Santana’s solo earlier? The whole front rail jumped two feet off the turf!',
          _ =>
            'Sunday home stretch! My boots are muddy, my poncho’s tie-dyed, and nobody’s leaving Main Roots till Jimi’s last note fades!',
        };
      case 'pippin_pecan':
        return switch (day) {
          1 =>
            'Friday’s acoustic openers in Mellow Meadow feel like a cozy backyard hootenanny.',
          2 =>
            'Saturday’s harmonies drew twice the crowd—people unrolled blankets all the way to the Old Oak!',
          _ =>
            'Sunday morning’s mist over the meadow felt sacred... tonight we all march west to Main Roots together!',
        };
      case 'saffron_suture':
        return switch (day) {
          1 =>
            'Keep watching that Friday evening sky—Set 7 brings the drizzle and Set 8 opens the Mud Pit!',
          2 =>
            'Day 2 mud-sliding championship update: nine out of ten walnuts agree muddy caftans dance faster!',
          _ =>
            'Day 3 glow: the mud dried into badges of honor, and the Sunday crowd energy is off the charts!',
        };
      case 'orion_kernel':
        return switch (day) {
          1 =>
            'Day 1 telemetry: clean sine waves and curious early explorers testing the dome’s low gravity.',
          2 =>
            'Day 2 telemetry: peak festival density! Tonight at 12:00 AM, Andromeda and Urbano go head-to-head!',
          _ =>
            'Day 3 telemetry: every harmonic across the nine zones is phase-locking toward tonight’s Main Roots finale.',
        };
      case 'boddhi_barkhand':
        return switch (day) {
          1 =>
            'Friday evening tip: pace yourself, sip chamomile tea, and listen to the distant stages mingle.',
          2 =>
            'Saturday’s campground is bustling with new tents and woven blankets—rest anytime to jump toward evening sets.',
          _ =>
            'Sunday’s kettle is down to its sweetest steep; savor every song before the stars come out at Main Roots.',
        };
      case 'arcade_attendant':
        return switch (day) {
          1 =>
            'Day 1 inside the Arcade Tent: crisp dry flippers and fresh leaderboard chalk!',
          2 =>
            'Day 2 rush: whenever rain clouds roll in, half the festival ducks inside here to cheer Pinball multiballs!',
          _ =>
            'Day 3 legends: folks have been trading high-score tales in the falafel queue all weekend!',
        };
      default:
        return switch (day) {
          1 =>
            'Day 1 (Friday) is just getting rolling—watch the crowds stream from stage to stage as each set goes live!',
          2 =>
            'Day 2 (Saturday) is in full swing—more blankets on the lawns, bustling food lines, and peak weekend energy!',
          _ =>
            'Day 3 (Sunday) brings the whole Free Orchard together—feel how warm and united the crowd has grown!',
        };
    }
  }
}
