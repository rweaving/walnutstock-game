import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import '../../data/models.dart';
import '../world/astar_pathfinder.dart';
import '../world/concert_light_show.dart';
import '../world/day_night_atmosphere.dart';
import '../world/stage_3d_rig_component.dart';
import '../world/tiled_map_parser.dart';
import 'catmull_rom_spline.dart';
import 'stage_performer_director.dart';

enum CrowdReactionKind {
  none,
  setKickoff,
  soloOrDrop,
  hushSway,
  encoreOvation,
}

enum NpcAutonomousActivity {
  none,
  wanderingToStage,
  dancingAtStage,
  sittingOnBlanket,
  walkingToFoodLine,
  queuingInFoodLine,
}

class NpcActor extends PositionComponent {
  NpcActor({
    required this.spec,
    required this.map,
    required this.spriteSheet,
    this.metricsGetter,
  }) : super(
          position: Vector2(spec.spawnX, spec.spawnY),
          size: Vector2.all(32),
          anchor: Anchor.center,
        ) {
    if (spec.aiMode == 'sine_curve' && spec.waypoints.length >= 3) {
      _spline = CatmullRomSpline2D(
        spec.waypoints.map((w) => Offset(w[0], w[1])).toList(growable: false),
      );
    }
  }

  final NpcSpec spec;
  final OrchardMapData map;
  final Image spriteSheet;
  final DayNightMetrics Function()? metricsGetter;

  CatmullRomSpline2D? _spline;
  double _splineT = 0.0;
  double _animClock = 0.0;
  int _facingRow = 0;
  bool _moving = false;

  int _waypointIndex = 0;
  final List<(double, double)> _patrolPath = [];
  final List<(double, double)> _migrationPath = [];
  final List<(double, double)> _stagePath = [];
  final List<(double, double)> _autonomousPath = [];
  Offset? _plannedAutonomousGoal;
  bool _migrationPlannedForStage = false;
  double _hapticCooldown = 0.0;

  NpcStageMark? _stageMark;
  StageShowFrame? activeStageShow;
  StageShowFrame? _nearbyStageShow;
  Offset? _plannedStageGoal;
  bool _returningFromStage = false;
  double _bassLevel = 0.0;
  bool _audienceGrooving = false;

  NpcAutonomousActivity autonomousActivity = NpcAutonomousActivity.none;
  Offset? autonomousTarget;
  int? autonomousFacingOverride;
  String? autonomousTargetStageId;
  String? autonomousFoodStallId;
  int? autonomousFoodQueueSlot;

  CrowdReactionKind performanceReaction = CrowdReactionKind.none;
  String? reactionCalloutText;
  double _reactionCalloutTimer = 0.0;
  double _reactionCalloutDuration = 2.2;
  String? heldTreatEmoji;
  double _heldTreatTimer = 0.0;

  bool gMajorBudding = false;
  bool vibrating440Hz = false;
  bool migrateToMainRoots = false;

  double mudSplatter = 0.0;
  double _mudHopTimer = 0.0;
  double _mudReactionTimer = 0.0;
  String? _mudReactionText;
  String? questBadgeState; // 'available' | 'ready' | null
  bool holdingConcertLighter = false;

  NpcStageMark? get stageMark => _stageMark;
  bool get isDancingNearStage => _audienceGrooving;
  bool get isMoving => _moving;
  bool get isSittingOnBlanket =>
      autonomousActivity == NpcAutonomousActivity.sittingOnBlanket &&
      !_moving &&
      !isOnStagePerforming;
  bool get isQueuingForFood =>
      autonomousActivity == NpcAutonomousActivity.queuingInFoodLine &&
      !_moving &&
      !isOnStagePerforming;
  StageShowFrame? get nearbyStageShow => _nearbyStageShow;

  void setAutonomousDirective({
    required NpcAutonomousActivity activity,
    Offset? target,
    int? facingOverride,
    String? stageId,
    String? foodStallId,
    int? queueSlot,
    bool snapImmediately = false,
  }) {
    autonomousActivity = activity;
    autonomousFacingOverride = facingOverride;
    autonomousTargetStageId = stageId;
    autonomousFoodStallId = foodStallId;
    autonomousFoodQueueSlot = queueSlot;
    if (target == null) {
      autonomousTarget = null;
      _plannedAutonomousGoal = null;
      _autonomousPath.clear();
      return;
    }
    if (snapImmediately && !map.isPointBlocked(target.dx, target.dy)) {
      position.setValues(target.dx, target.dy);
      autonomousTarget = target;
      _plannedAutonomousGoal = target;
      _autonomousPath.clear();
      _moving = false;
      if (facingOverride != null) {
        _facingRow = facingOverride;
      }
      priority = position.y.round();
      return;
    }
    if (_plannedAutonomousGoal == null ||
        (_plannedAutonomousGoal! - target).distance > 6.0) {
      _autonomousPath.clear();
      _plannedAutonomousGoal = target;
    }
    autonomousTarget = target;
  }

  void clearAutonomousDirective() {
    autonomousActivity = NpcAutonomousActivity.none;
    autonomousTarget = null;
    autonomousFacingOverride = null;
    autonomousTargetStageId = null;
    autonomousFoodStallId = null;
    autonomousFoodQueueSlot = null;
    _plannedAutonomousGoal = null;
    _autonomousPath.clear();
  }

  void triggerPerformanceCallout(String text, {double duration = 2.2}) {
    if (_mudReactionTimer > 0.0 || _reactionCalloutTimer > 0.2) return;
    reactionCalloutText = text;
    _reactionCalloutDuration = duration;
    _reactionCalloutTimer = duration;
  }

  void grantServedTreat(String emoji, String callout) {
    heldTreatEmoji = emoji;
    _heldTreatTimer = 42.0;
    reactionCalloutText = callout;
    _reactionCalloutDuration = 2.4;
    _reactionCalloutTimer = 2.4;
  }

  PerformerChoreoSample? get currentChoreoSample {
    final mark = _stageMark;
    final show = activeStageShow;
    if (!isOnStagePerforming || mark == null || show == null) return null;
    return sampleChoreographyForPerformer(
      show: show,
      instrument: mark.instrument,
      isLeadPerformer: mark.isLeadPerformer,
      rolePhaseIndex: spec.id.hashCode.abs() % 5,
    );
  }

  bool receiveMudSplat(String reaction) {
    if (isOnStagePerforming || _stageMark != null) return false;
    mudSplatter = (mudSplatter + 0.55).clamp(0.0, 1.0);
    _mudHopTimer = 0.45;
    _mudReactionText = reaction;
    _mudReactionTimer = 2.0;
    return true;
  }

  bool get isOnStagePerforming {
    final m = _stageMark;
    if (m == null || m.isSoundcheck) return false;
    final dx = position.x - m.stagePos.dx;
    final dy = position.y - m.stagePos.dy;
    return (dx * dx + dy * dy) <= 64.0;
  }

  void applyStageAssignment(
    NpcStageMark? nextMark, {
    required bool snapImmediately,
  }) {
    final prev = _stageMark;
    _stageMark = nextMark;

    if (nextMark != null) {
      _returningFromStage = false;
      if (snapImmediately) {
        if (!map.isPointBlocked(nextMark.stagePos.dx, nextMark.stagePos.dy)) {
          position.setValues(nextMark.stagePos.dx, nextMark.stagePos.dy);
        }
        _stagePath.clear();
        _plannedStageGoal = nextMark.stagePos;
        _moving = false;
        _facingRow = 0;
        priority = position.y.round();
      } else if (_plannedStageGoal != nextMark.stagePos) {
        _stagePath.clear();
        _plannedStageGoal = nextMark.stagePos;
      }
      return;
    }

    // No active stage assignment for this NPC
    _plannedStageGoal = null;
    final restPos = StagePerformerDirector.offStageRestPositionFor(spec);
    final hasCustomOffStageRest =
        (restPos.dx - spec.spawnX).abs() > 1.0 ||
            (restPos.dy - spec.spawnY).abs() > 1.0;

    if (snapImmediately && (prev != null || hasCustomOffStageRest)) {
      if (!map.isPointBlocked(restPos.dx, restPos.dy)) {
        position.setValues(restPos.dx, restPos.dy);
      }
      _stagePath.clear();
      _returningFromStage = false;
      _moving = false;
      _facingRow = 0;
      priority = position.y.round();
    } else if (prev != null) {
      _stagePath.clear();
      _returningFromStage = true;
    }
  }

  void stepAi({
    required double dt,
    required bool gMajorActive,
    required double organ440Level,
    required bool crowdMigrateMainRoots,
    required double playerDistance,
    double bassLevel = 0.0,
    Offset? nearbyLiveStagePos,
    StageShowFrame? nearbyStageShow,
    bool playerDancingNearby = false,
  }) {
    _animClock += dt;
    _bassLevel = bassLevel;
    _nearbyStageShow = nearbyStageShow;
    migrateToMainRoots = crowdMigrateMainRoots;
    _audienceGrooving = false;
    if (_mudHopTimer > 0.0) {
      _mudHopTimer = math.max(0.0, _mudHopTimer - dt);
    }
    if (_mudReactionTimer > 0.0) {
      _mudReactionTimer = math.max(0.0, _mudReactionTimer - dt);
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
    if (mudSplatter > 0.0) {
      final rainWash = (metricsGetter?.call().rainIntensity ?? 0.0) > 0.4;
      mudSplatter =
          math.max(0.0, mudSplatter - dt * (rainWash ? 0.16 : 0.02));
    }

    // Barnaby Breeze-Walker's living willow twig buds on G-Major chords!
    if (spec.id == 'barnaby_breezewalker') {
      gMajorBudding = gMajorActive;
    }

    // Barnaby Bittershell vibrates at 440Hz whenever a Hammond B3 organ plays!
    if (spec.id == 'barnaby_bittershell') {
      vibrating440Hz = organ440Level > 0.50;
      if (vibrating440Hz && playerDistance < 220.0) {
        _hapticCooldown -= dt;
        if (_hapticCooldown <= 0.0) {
          _hapticCooldown = 1.6;
          unawaited(HapticFeedback.selectionClick());
        }
      }
    }

    // 1. Scheduled On-Stage Performance / Pre-Set Soundcheck!
    final mark = _stageMark;
    if (mark != null) {
      _stepTowardStageMark(mark, dt);
      priority = position.y.round();
      return;
    }

    // 2. Post-Set Walk Back Off-Stage to Rest / Patrol Zone
    if (_returningFromStage) {
      final restPos = StagePerformerDirector.offStageRestPositionFor(spec);
      final reached =
          _stepStageAStar(restPos.dx, restPos.dy, speed: 58.0, dt: dt);
      if (reached) {
        _returningFromStage = false;
        _facingRow = 0;
      }
      priority = position.y.round();
      return;
    }

    double? stageDistSq;
    if (nearbyLiveStagePos != null) {
      final dxStage = nearbyLiveStagePos.dx - position.x;
      final dyStage = nearbyLiveStagePos.dy - position.y;
      stageDistSq = dxStage * dxStage + dyStage * dyStage;
    }
    final withinStageDanceBowl =
        stageDistSq != null && stageDistSq <= 340.0 * 340.0;
    final dancingWithPlayer = playerDancingNearby && playerDistance <= 165.0;

    // Pause walking while chatting/dancing closely with player, but keep grooving to the stage!
    if (playerDistance < 34.0) {
      _moving = false;
      if (withinStageDanceBowl || dancingWithPlayer) {
        _audienceGrooving = true;
      }
      priority = position.y.round();
      return;
    }

    // Sunday Track 24 Crowd Convergence toward Main Roots Stage bowl via A*!
    if (spec.aiMode == 'stationary_then_stage') {
      if (crowdMigrateMainRoots) {
        final goalX = 560.0 + (spec.id.hashCode.abs() % 110);
        final goalY = 472.0 + (spec.name.hashCode.abs() % 64);
        _stepAStarGoal(goalX, goalY, forStageMigration: true, dt: dt);
        _audienceGrooving = !_moving || withinStageDanceBowl;
        priority = position.y.round();
        return;
      } else if (autonomousActivity == NpcAutonomousActivity.none &&
          ((position.x - spec.spawnX).abs() > 8.0 ||
              (position.y - spec.spawnY).abs() > 8.0)) {
        // Return cleanly to home grove if scrubbed back from Sunday finale in Encore Mode
        _stepAStarGoal(spec.spawnX, spec.spawnY,
            forStageMigration: false, dt: dt);
        priority = position.y.round();
        return;
      }
    }

    // Autonomous living-festival activity (wandering between stages, sitting on blankets, queuing for food!)
    if (autonomousActivity != NpcAutonomousActivity.none &&
        autonomousTarget != null) {
      final goal = autonomousTarget!;
      final moveSpeed =
          autonomousActivity == NpcAutonomousActivity.queuingInFoodLine
              ? 36.0
              : 49.0;
      final reached = _stepAutonomousGoal(
        goal.dx,
        goal.dy,
        speed: moveSpeed,
        dt: dt,
      );
      if (reached) {
        if (autonomousActivity == NpcAutonomousActivity.wanderingToStage) {
          autonomousActivity = NpcAutonomousActivity.dancingAtStage;
        } else if (autonomousActivity ==
            NpcAutonomousActivity.walkingToFoodLine) {
          autonomousActivity = NpcAutonomousActivity.queuingInFoodLine;
        }
        if (autonomousFacingOverride != null) {
          _facingRow = autonomousFacingOverride!;
        } else if (nearbyLiveStagePos != null && withinStageDanceBowl) {
          _updateFacing(
            nearbyLiveStagePos.dx - position.x,
            nearbyLiveStagePos.dy - position.y,
          );
        }
        if (autonomousActivity == NpcAutonomousActivity.dancingAtStage &&
            (withinStageDanceBowl ||
                dancingWithPlayer ||
                performanceReaction == CrowdReactionKind.encoreOvation)) {
          _audienceGrooving = true;
        }
      }
      priority = position.y.round();
      return;
    }

    if (_spline != null) {
      // Ziggy Shell-shock's closed C1 Catmull-Rom curve
      _splineT = (_splineT + dt * 0.045) % 1.0;
      final nextPt = _spline!.evaluate(_splineT);
      final tang = _spline!.tangent(_splineT);
      _updateFacing(tang.dx, tang.dy);
      position.setValues(nextPt.dx, nextPt.dy);
      _moving = true;
      if (stageDistSq != null && stageDistSq <= 280.0 * 280.0) {
        _audienceGrooving = true;
      }
    } else if (spec.aiMode == 'avoid_asphalt_patrol' &&
        spec.waypoints.isNotEmpty) {
      _stepAvoidAsphaltPatrol(dt);
      if (stageDistSq != null && stageDistSq <= 280.0 * 280.0) {
        _audienceGrooving = true;
      }
    } else if (spec.aiMode == 'outskirts_rover' && spec.waypoints.isNotEmpty) {
      final wp = spec.waypoints[_waypointIndex % spec.waypoints.length];
      final reached = _moveDirectlyToward(wp[0], wp[1], speed: 40.0, dt: dt);
      if (reached) {
        _waypointIndex = (_waypointIndex + 1) % spec.waypoints.length;
      }
      if (stageDistSq != null && stageDistSq <= 280.0 * 280.0) {
        _audienceGrooving = true;
      }
    } else {
      _moving = false;
      // Stage-front & amphitheater characters dance synced to the live music!
      if (withinStageDanceBowl && nearbyLiveStagePos != null) {
        final dx = nearbyLiveStagePos.dx - position.x;
        final dy = nearbyLiveStagePos.dy - position.y;
        _updateFacing(dx, dy);
        _audienceGrooving = true;
      } else if (dancingWithPlayer ||
          performanceReaction == CrowdReactionKind.encoreOvation) {
        _audienceGrooving = true;
      }
    }

    priority = position.y.round();
  }

  bool _stepAutonomousGoal(
    double goalX,
    double goalY, {
    required double speed,
    required double dt,
  }) {
    final dxGoal = goalX - position.x;
    final dyGoal = goalY - position.y;
    if (dxGoal * dxGoal + dyGoal * dyGoal <= 25.0) {
      if (!map.isPointBlocked(goalX, goalY)) {
        position.setValues(goalX, goalY);
      }
      _autonomousPath.clear();
      _moving = false;
      return true;
    }

    final nearDirect = dxGoal * dxGoal + dyGoal * dyGoal <= 36.0 * 36.0 &&
        !map.isPointBlocked(
          position.x + dxGoal * 0.5,
          position.y + dyGoal * 0.5,
        );
    if (nearDirect && _autonomousPath.isEmpty) {
      return _moveDirectlyToward(goalX, goalY, speed: speed, dt: dt);
    }

    if (_autonomousPath.isEmpty) {
      final planned = AStarPathfinder(map).findWorldPath(
        startX: position.x,
        startY: position.y,
        goalX: goalX,
        goalY: goalY,
      );
      if (planned.isEmpty) {
        _moving = false;
        return _moveDirectlyToward(goalX, goalY, speed: speed, dt: dt);
      }
      _autonomousPath.addAll(planned);
      if (!map.isPointBlocked(goalX, goalY)) {
        _autonomousPath.add((goalX, goalY));
      }
    }

    final (tx, ty) = _autonomousPath.first;
    if (_moveDirectlyToward(tx, ty, speed: speed, dt: dt)) {
      _autonomousPath.removeAt(0);
    }
    return false;
  }

  void _stepTowardStageMark(NpcStageMark mark, double dt) {
    final reached = _stepStageAStar(
      mark.stagePos.dx,
      mark.stagePos.dy,
      speed: 78.0,
      dt: dt,
    );
    if (reached) {
      position.setValues(mark.stagePos.dx, mark.stagePos.dy);
      _moving = false;
      _facingRow = 0; // Face South toward the cheering orchard audience!
    }
  }

  bool _stepStageAStar(
    double goalX,
    double goalY, {
    required double speed,
    required double dt,
  }) {
    final dxGoal = goalX - position.x;
    final dyGoal = goalY - position.y;
    if (dxGoal * dxGoal + dyGoal * dyGoal <= 9.0) {
      if (!map.isPointBlocked(goalX, goalY)) {
        position.setValues(goalX, goalY);
      }
      _stagePath.clear();
      _moving = false;
      return true;
    }

    final sameTile =
        (position.x / map.tileWidth).floor() == (goalX / map.tileWidth).floor() &&
            (position.y / map.tileHeight).floor() ==
                (goalY / map.tileHeight).floor();
    if (sameTile && _stagePath.isEmpty) {
      return _moveDirectlyToward(goalX, goalY, speed: speed, dt: dt);
    }

    if (_stagePath.isEmpty) {
      final planned = AStarPathfinder(map).findWorldPath(
        startX: position.x,
        startY: position.y,
        goalX: goalX,
        goalY: goalY,
        avoidAsphalt: spec.id == 'barnaby_breezewalker',
      );
      if (planned.isEmpty) {
        // Direct fallback if standing on adjacent stage apron
        if (!map.isPointBlocked(goalX, goalY)) {
          position.setValues(goalX, goalY);
        }
        _moving = false;
        return true;
      }
      _stagePath.addAll(planned);
      if (!map.isPointBlocked(goalX, goalY)) {
        _stagePath.add((goalX, goalY));
      }
    }

    final (tx, ty) = _stagePath.first;
    if (_moveDirectlyToward(tx, ty, speed: speed, dt: dt)) {
      _stagePath.removeAt(0);
    }
    return false;
  }

  void _stepAStarGoal(
    double goalX,
    double goalY, {
    required bool forStageMigration,
    required double dt,
  }) {
    final dxGoal = goalX - position.x;
    final dyGoal = goalY - position.y;
    if (dxGoal * dxGoal + dyGoal * dyGoal < 144.0) {
      _migrationPath.clear();
      _moving = false;
      if (forStageMigration) {
        _facingRow = 3; // Face north toward Main Roots Stage!
      }
      return;
    }

    if (_migrationPlannedForStage != forStageMigration) {
      _migrationPath.clear();
      _migrationPlannedForStage = forStageMigration;
    }

    if (_migrationPath.isEmpty) {
      final planned = AStarPathfinder(map).findWorldPath(
        startX: position.x,
        startY: position.y,
        goalX: goalX,
        goalY: goalY,
      );
      if (planned.isEmpty) {
        _moving = false;
        return;
      }
      _migrationPath.addAll(planned);
    }

    final (tx, ty) = _migrationPath.first;
    if (_moveDirectlyToward(tx, ty, speed: 52.0, dt: dt)) {
      _migrationPath.removeAt(0);
    }
  }

  void _stepAvoidAsphaltPatrol(double dt) {
    if (_patrolPath.isEmpty) {
      final wp = spec.waypoints[_waypointIndex % spec.waypoints.length];
      _waypointIndex = (_waypointIndex + 1) % spec.waypoints.length;
      final planned = AStarPathfinder(map).findWorldPath(
        startX: position.x,
        startY: position.y,
        goalX: wp[0],
        goalY: wp[1],
        avoidAsphalt: true,
      );
      _patrolPath.addAll(planned);
      if (_patrolPath.isEmpty) {
        _moving = false;
        return;
      }
    }

    final (tx, ty) = _patrolPath.first;
    // Double-guard: Barnaby Breeze-Walker refuses to tread on asphalt even if mutated
    if (map.surfaceAtWorld(tx, ty) == 'asphalt') {
      _patrolPath.clear();
      _moving = false;
      return;
    }
    if (_moveDirectlyToward(tx, ty, speed: 42.0, dt: dt)) {
      _patrolPath.removeAt(0);
    }
  }

  bool _moveDirectlyToward(
    double tx,
    double ty, {
    required double speed,
    required double dt,
  }) {
    final dx = tx - position.x;
    final dy = ty - position.y;
    final dist = math.sqrt(dx * dx + dy * dy);
    final step = speed * dt;
    if (dist < 2.5 || step >= dist) {
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
    final metrics = metricsGetter?.call() ?? DayNightMetrics.middayDefault;
    final inLowGravity = map.isLowGravityAtWorld(position.x, position.y);
    final performing = isOnStagePerforming;
    final mark = _stageMark;
    final choreo = currentChoreoSample;
    final audShow = _nearbyStageShow;

    final floatBob = inLowGravity ? math.sin(_animClock * 2.8) * 4.0 : 0.0;
    final npcPhaseIdx = spec.id.hashCode.abs() % 4;
    final npcDanceStyle = (spec.id.hashCode.abs() ~/ 3) % 4;
    final audBeatFloat = audShow != null
        ? audShow.beatIndex + audShow.beatPhase
        : _animClock * (112.0 / 60.0);
    final audBeatIdx = audShow?.beatIndex ?? audBeatFloat.floor();
    final audBeatPulse = audShow?.beatPulse ??
        math.pow(1.0 - (audBeatFloat - audBeatIdx), 2.1).toDouble();
    final audBass = audShow?.bass ?? math.max(0.28, _bassLevel);
    final audHighEnergy = audShow != null &&
        (audShow.kickDrop ||
            audShow.sectionMode == LightShowSectionMode.chorusAnthemy ||
            audShow.sectionMode == LightShowSectionMode.soloShred ||
            audShow.sectionMode == LightShowSectionMode.climaxPrism);

    final seated = isSittingOnBlanket;
    final double perfBounce;
    final double perfSwayX;
    final double stepForwardY;
    final double bodyTilt;
    int? audienceDanceFrameCol;
    int renderFacingRow = _facingRow;

    if (performing && choreo != null) {
      perfBounce = choreo.bounceY;
      perfSwayX = choreo.swayX;
      stepForwardY = choreo.forwardStepY;
      bodyTilt = choreo.bodyTiltRad;
    } else if (performing) {
      perfBounce = math.sin(_animClock * 7.6).abs() * (1.5 + _bassLevel * 2.3);
      perfSwayX = math.sin(_animClock * 3.8) * 1.6;
      stepForwardY = 0.0;
      bodyTilt = 0.0;
    } else if (seated) {
      perfBounce = audShow != null ? audBeatPulse * 1.15 : 0.0;
      perfSwayX = math.sin(_animClock * 2.1 + npcPhaseIdx * 0.8) * 1.1;
      stepForwardY = 3.6;
      bodyTilt = math.sin(_animClock * 2.1 + npcPhaseIdx * 0.8) * 0.06;
    } else if (_audienceGrooving &&
        performanceReaction == CrowdReactionKind.hushSway) {
      // Gentle synchronized Slow-Wave Sway during acoustic & dawn breakdowns!
      perfBounce = audBeatPulse * 0.75;
      perfSwayX = math.sin(_animClock * 2.3 + npcPhaseIdx * 0.65) * 3.5;
      bodyTilt = math.sin(_animClock * 2.3 + npcPhaseIdx * 0.65) * 0.13;
      stepForwardY = 0.0;
    } else if (_audienceGrooving &&
        performanceReaction == CrowdReactionKind.encoreOvation) {
      // Enthusiastic standing ovation & applause at set end!
      perfBounce = math.sin(_animClock * 11.0 + npcPhaseIdx).abs() * 2.4;
      perfSwayX = math.sin(_animClock * 3.6 + npcPhaseIdx) * 1.2;
      bodyTilt = 0.0;
      stepForwardY = 0.0;
    } else if (_audienceGrooving) {
      final soloBoost = performanceReaction == CrowdReactionKind.soloOrDrop ||
              performanceReaction == CrowdReactionKind.setKickoff
          ? 1.32
          : 1.0;
      audienceDanceFrameCol =
          const [1, 0, 2, 0][(audBeatIdx + npcPhaseIdx) % 4];
      switch (npcDanceStyle) {
        case 0: // Stage-front Boogie Bounce
          perfBounce = audBeatPulse * (2.1 + audBass * 2.8) * soloBoost;
          perfSwayX =
              math.sin((audBeatFloat + npcPhaseIdx * 0.5) * math.pi * 0.5) *
                  2.4;
          bodyTilt =
              math.sin((audBeatFloat + npcPhaseIdx * 0.5) * math.pi * 0.5) *
                  0.12;
          break;
        case 1: // 1969 Hip Twist
          perfBounce = (1.6 + audBass * 2.2) *
              soloBoost *
              math.sin(((audBeatFloat - audBeatIdx) * math.pi));
          perfSwayX = math.sin((audBeatFloat + npcPhaseIdx) * math.pi) * 2.7;
          bodyTilt = -math.sin((audBeatFloat + npcPhaseIdx) * math.pi) * 0.14;
          break;
        case 2: // Two-Step Meadow Shuffle
          final barPhase = ((audBeatFloat + npcPhaseIdx) % 4.0) / 4.0;
          perfSwayX = math.sin(barPhase * math.pi * 2.0) * 3.1;
          perfBounce = audBeatPulse * (2.0 + audBass * 2.6) * soloBoost;
          bodyTilt = math.sin(barPhase * math.pi * 2.0) * 0.10;
          break;
        default: // Joyful Chorus Twirl & Hop
          perfBounce = audBeatPulse * (2.4 + audBass * 3.1) * soloBoost;
          perfSwayX =
              math.cos((audBeatFloat + npcPhaseIdx) * math.pi * 0.5) * 2.2;
          bodyTilt = math.sin((audBeatFloat + npcPhaseIdx) * math.pi) * 0.11;
          if (!_moving && (audHighEnergy || soloBoost > 1.1)) {
            const spinRows = [0, 1, 3, 2];
            renderFacingRow = spinRows[(audBeatIdx + npcPhaseIdx) % 4];
          }
          break;
      }
      stepForwardY = 0.0;
    } else if (isQueuingForFood) {
      // Subtle hungry shift while waiting in a Vendor Row food line
      perfBounce = math.sin(_animClock * 3.1 + npcPhaseIdx).abs() * 0.55;
      perfSwayX = math.sin(_animClock * 1.7 + npcPhaseIdx) * 0.65;
      stepForwardY = 0.0;
      bodyTilt = 0.0;
    } else {
      perfBounce = 0.0;
      perfSwayX = 0.0;
      stepForwardY = 0.0;
      bodyTilt = 0.0;
    }

    final buzzX = vibrating440Hz ? math.sin(_animClock * 55.0) * 1.6 : 0.0;
    final mudHop = _mudHopTimer > 0.0
        ? math.sin((_mudHopTimer / 0.45) * math.pi) * 5.2
        : 0.0;
    final totalX = buzzX + perfSwayX;
    final totalLiftY = floatBob + perfBounce + mudHop;

    // 1. Directional 3D sun/moon cast shadow + beat-synced stage spotlight floor rim
    renderActor3dShadow(
      canvas: canvas,
      metrics: metrics,
      centerX: 16.0 + totalX * 0.35,
      footY: seated ? 26.8 : (28.5 + stepForwardY),
      spotlightColor: performing
          ? mark?.spotlightColor
          : (_audienceGrooving ? audShow?.primaryColor : null),
      haloIntensity: performing
          ? (choreo?.haloIntensity ?? 0.28)
          : (_audienceGrooving ? (0.18 + 0.26 * audBeatPulse) : 0.24),
    );

    final int frameCol;
    if (_moving) {
      frameCol = 1 + ((_animClock * 6.5).floor() % 2);
    } else if (performing && choreo != null) {
      frameCol = choreo.spriteFrameCol;
    } else if (performing) {
      frameCol = (_animClock * 5.5).floor() % 3;
    } else if (seated) {
      frameCol = 0;
    } else if (_audienceGrooving && audienceDanceFrameCol != null) {
      frameCol = audienceDanceFrameCol;
    } else {
      frameCol = 0;
    }
    final src =
        Rect.fromLTWH(frameCol * 32.0, renderFacingRow * 32.0, 32.0, 32.0);
    final dst = seated
        ? Rect.fromLTWH(totalX, stepForwardY - totalLiftY, 32.0, 28.5)
        : Rect.fromLTWH(totalX, stepForwardY - totalLiftY, 32.0, 32.0);

    canvas.save();
    if (bodyTilt.abs() > 0.005) {
      final pivotX = 16.0 + totalX;
      final pivotY = 22.0 + stepForwardY - totalLiftY;
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
    canvas.restore();

    if (seated) {
      // Tucked cross-legged lap shadow & cozy blanket cushion rim
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(16.0 + totalX, 27.6 - totalLiftY * 0.4),
          width: 14.5,
          height: 4.2,
        ),
        Paint()..color = const Color(0x551C110A),
      );
    }

    // Stage-front crowd cheering hands, applause & floating groove notes!
    if (_audienceGrooving && !performing && !_moving) {
      final isOvation = performanceReaction == CrowdReactionKind.encoreOvation;
      final isSolo = performanceReaction == CrowdReactionKind.soloOrDrop ||
          performanceReaction == CrowdReactionKind.setKickoff;
      if (isOvation) {
        final clapGap =
            1.6 + math.sin(_animClock * 20.0 + npcPhaseIdx * 1.4).abs() * 3.8;
        final handCol = Paint()..color = const Color(0xFFD4A373);
        final outline = Paint()..color = const Color(0xFF1C110A);
        for (final hx in [16.0 + totalX - clapGap, 16.0 + totalX + clapGap]) {
          canvas.drawCircle(Offset(hx, 15.0 - totalLiftY), 2.0, outline);
          canvas.drawCircle(Offset(hx, 15.0 - totalLiftY), 1.35, handCol);
        }
        if (clapGap < 2.2) {
          canvas.drawCircle(
            Offset(16.0 + totalX, 13.0 - totalLiftY),
            2.4,
            Paint()..color = const Color(0x99FFD166),
          );
        }
      } else if ((audHighEnergy && audBeatPulse > 0.38) || isSolo) {
        final handCol = Paint()..color = const Color(0xFFD4A373);
        final outline = Paint()..color = const Color(0xFF1C110A);
        final raiseExtra = isSolo ? 2.4 : 0.0;
        for (final hx in [7.5 + totalX, 24.5 + totalX]) {
          canvas.drawCircle(
            Offset(hx, 14.0 - totalLiftY - audBeatPulse * 2.0 - raiseExtra),
            2.0,
            outline,
          );
          canvas.drawCircle(
            Offset(hx, 14.0 - totalLiftY - audBeatPulse * 2.0 - raiseExtra),
            1.35,
            handCol,
          );
        }
      }
      if ((audBeatIdx + npcPhaseIdx) % 2 == 0) {
        final nPhase = (audBeatFloat - audBeatIdx).clamp(0.0, 1.0);
        final noteCol = (audShow?.secondaryColor ?? const Color(0xFFFFD166))
            .withValues(alpha: (0.72 * (1.0 - nPhase)).clamp(0.0, 0.78));
        final nx = 16.0 + totalX + (npcPhaseIdx.isEven ? -7.5 : 7.5);
        final ny = 6.5 - totalLiftY - nPhase * 8.0;
        final np = Paint()..color = noteCol;
        canvas.drawCircle(Offset(nx, ny), 1.3, np);
        canvas.drawRect(Rect.fromLTWH(nx + 0.7, ny - 3.6, 0.9, 3.6), np);
      }
    }

    // 2. Render live 3D stage instrument, stand mic, solo sparks & floating notes when on stage!
    if (mark != null && (performing || (mark.isSoundcheck && !_moving))) {
      renderPerformerInstrumentProp(
        canvas: canvas,
        instrument: mark.instrument,
        time: activeStageShow?.trackTimeSec ?? _animClock,
        bass: activeStageShow?.bass ?? _bassLevel,
        offsetX: totalX,
        liftY: totalLiftY,
        stepForwardY: stepForwardY,
        accentColor: mark.spotlightColor,
        instrumentBodyColor: mark.instrumentBodyColor,
        instrumentPickguardColor: mark.instrumentPickguardColor,
        choreo: choreo,
        emitNotes: performing,
      );
    }

    if (gMajorBudding) {
      // Glowing living willow leaf bud above Barnaby Breeze-Walker's green hat!
      canvas.drawCircle(
        Offset(21 + totalX, 2 - totalLiftY),
        3.5,
        Paint()..color = const Color(0xFF80FFDB),
      );
    }

    if (vibrating440Hz) {
      canvas.drawCircle(
        Offset(16 + totalX, 14 - totalLiftY),
        15.0,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0x88FFB703),
      );
    }

    if (mudSplatter > 0.06 && !performing) {
      final alpha = (mudSplatter * 0.88).clamp(0.18, 0.88);
      final mudDark = Paint()..color = Color.fromRGBO(74, 44, 24, alpha);
      final mudSpec =
          Paint()..color = Color.fromRGBO(156, 102, 68, alpha * 0.85);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(12.5 + totalX, 19.0 - totalLiftY),
            width: 4.0,
            height: 2.6),
        mudDark,
      );
      canvas.drawCircle(
          Offset(12.0 + totalX, 18.6 - totalLiftY), 0.85, mudSpec);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(19.5 + totalX, 16.5 - totalLiftY),
            width: 3.5,
            height: 2.4),
        mudDark,
      );
    }

    if (heldTreatEmoji != null && _heldTreatTimer > 0.0 && !performing) {
      final bobSnack = math.sin(_animClock * 4.5 + npcPhaseIdx) * 0.9;
      renderCenteredWorldPill(
        canvas: canvas,
        center: Offset(25.2 + totalX, 17.5 - totalLiftY + bobSnack),
        text: heldTreatEmoji!,
        fontSize: 6.0,
        textColor: const Color(0xFFFFF8E7),
        backgroundColor: const Color(0xAA1C110A),
        horizontalPadding: 2.0,
        pillHeight: 9.5,
        minPillWidth: 10.0,
        maxPillWidth: 18.0,
        borderRadius: 4.5,
      );
    }

    if (_mudReactionTimer > 0.0 && _mudReactionText != null) {
      final fade = (_mudReactionTimer / 0.45).clamp(0.0, 1.0);
      final rise = (2.0 - _mudReactionTimer) * 4.5;
      renderCenteredWorldPill(
        canvas: canvas,
        center: Offset(16.0 + totalX, -5.0 - totalLiftY - rise),
        text: _mudReactionText!,
        fontSize: 6.2,
        textColor: Color.fromRGBO(255, 224, 130, fade),
        backgroundColor: Color.fromRGBO(36, 22, 14, 0.88 * fade),
        horizontalPadding: 6.5,
        pillHeight: 12.0,
        minPillWidth: 44.0,
        maxPillWidth: 112.0,
        borderRadius: 5.0,
      );
    } else if (_reactionCalloutTimer > 0.0 &&
        reactionCalloutText != null &&
        !performing) {
      final fade = (_reactionCalloutTimer / 0.42).clamp(0.0, 1.0);
      final rise =
          (_reactionCalloutDuration - _reactionCalloutTimer).clamp(0.0, 2.5) *
              3.2;
      final pillY = questBadgeState != null
          ? (-14.5 - totalLiftY - rise)
          : (-5.2 - totalLiftY - rise);
      renderCenteredWorldPill(
        canvas: canvas,
        center: Offset(16.0 + totalX, pillY),
        text: reactionCalloutText!,
        fontSize: 6.0,
        textColor: Color.fromRGBO(255, 243, 176, fade),
        backgroundColor: Color.fromRGBO(28, 17, 10, 0.86 * fade),
        horizontalPadding: 5.5,
        pillHeight: 11.5,
        minPillWidth: 36.0,
        maxPillWidth: 116.0,
        borderRadius: 5.0,
      );
    }

    // Synchronized Nighttime Concert Lighter Wave when player raises Encore Sparkler!
    if (holdingConcertLighter && !performing) {
      final swayLight = math.sin(_animClock * 4.2 + npcPhaseIdx) * 2.2;
      final lx = 24.0 + totalX + swayLight;
      final ly = 9.0 - totalLiftY;
      final flick = 0.82 + 0.22 * math.sin(_animClock * 22.0 + npcPhaseIdx * 2);
      canvas.drawCircle(
        Offset(lx, ly),
        4.8 * flick,
        Paint()..color = const Color(0x55FFB703),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(lx, ly),
          width: 2.2 * flick,
          height: 3.4 * flick,
        ),
        Paint()..color = const Color(0xFFFFD166),
      );
      canvas.drawCircle(
        Offset(lx, ly + 0.4),
        0.9,
        Paint()..color = const Color(0xFFFFFFFF),
      );
    }

    // Overhead Quest Status Badge (! = Available Quest, ★ = Ready to Turn In)
    if (questBadgeState != null &&
        !performing &&
        _mudReactionTimer <= 0.0) {
      final isReady = questBadgeState == 'ready';
      final bob = math.sin(_animClock * 4.8 + npcPhaseIdx) * 1.4;
      final badgeCenter = Offset(16.0 + totalX, -4.2 - totalLiftY + bob);
      canvas.drawCircle(
        badgeCenter,
        5.2,
        Paint()
          ..color = isReady
              ? const Color(0xEB2A9D8F)
              : const Color(0xEBFFB703),
      );
      canvas.drawCircle(
        badgeCenter,
        5.2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = const Color(0xFF1C110A),
      );
      renderCenteredWorldPill(
        canvas: canvas,
        center: badgeCenter,
        text: isReady ? '★' : '!',
        fontSize: 6.8,
        textColor: isReady ? const Color(0xFFFFFFFF) : const Color(0xFF1C110A),
        backgroundColor: const Color(0x00000000),
        horizontalPadding: 1.0,
        pillHeight: 10.0,
        minPillWidth: 8.0,
        maxPillWidth: 14.0,
        borderRadius: 4.0,
      );
    }
  }
}
