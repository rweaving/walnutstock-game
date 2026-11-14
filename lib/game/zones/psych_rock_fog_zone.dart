import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';

enum FogMazeStepOutcome {
  none,
  waypointHarmonized,
  sanctumRevealed,
  wrappedToEntrance,
}

/// Pokémon "Lost Woods"-inspired spatial audio maze in Zone 7 (The Undergrowth).
///
/// Guests follow Tula Twigwalker's stereo C-major brass handbells across two
/// acoustic glade resonances (`West Moss Arch` -> `East Fern Clearing`) to part
/// the central Psych-Rock Fog around the Sacred Tea-Light Circle (`1200, 144`).
/// Straying into wrong-turn fog pockets gently mists and wraps the guest back
/// to the southern Undergrowth threshold (`1200, 248`) — bypassed automatically
/// in `Pure Vibe Mode`, once Tula's quest is completed, or via Janice's secret
/// Upper Velvet Ledge moss trail!
class PsychRockFogZone extends Component {
  PsychRockFogZone({
    required this.fogBounds,
    required this.bellCenter,
    super.priority = 9000,
  });

  static const Offset entranceSpawn = Offset(1200.0, 248.0);
  static const List<Offset> acousticWaypoints = [
    Offset(1064.0, 212.0), // Stage 0: West Moss Arch (left-ear stereo bell)
    Offset(
        1336.0, 196.0), // Stage 1: East Fern Clearing (right-ear stereo bell)
    Offset(1200.0, 144.0), // Stage 2: Sacred Tea-Light Sanctum (center chime)
  ];

  final Rect fogBounds;
  final Offset bellCenter;

  double _time = 0.0;
  double _mistFlashAlpha = 0.0;
  int _mazeStage = 0; // 0 = seek West, 1 = seek East, 2 = Sanctum unlocked!
  bool _wasInside = false;

  Offset playerPos = Offset.zero;
  bool visualAssistEnabled = true;

  int get mazeStage => _mazeStage;
  bool get isSanctumUnlocked => _mazeStage >= 2;
  bool get isPlayerInside => fogBounds.contains(playerPos);

  /// Active world coordinate from which Tula's stereo C-major bell beacon chimes.
  Offset get activeBellTarget =>
      acousticWaypoints[_mazeStage.clamp(0, acousticWaypoints.length - 1)];

  /// Evaluates Lost-Woods acoustic waypoint progression & wrong-turn fog wraps.
  FogMazeStepOutcome evaluateMazeStep({
    required Offset currentPos,
    required bool bypassMaze,
  }) {
    playerPos = currentPos;
    final inside = fogBounds.contains(currentPos);
    if (!inside) {
      if (_wasInside && _mazeStage < 2) {
        _mazeStage = 0;
      }
      _wasInside = false;
      return FogMazeStepOutcome.none;
    }
    _wasInside = true;

    if (bypassMaze) {
      _mazeStage = 2;
    }

    // Entering from Janice's secret western Upper Velvet Ledge moss trail rewards discovery!
    if (_mazeStage < 2 &&
        currentPos.dx < 984.0 &&
        currentPos.dy >= 96.0 &&
        currentPos.dy <= 172.0) {
      _mazeStage = 2;
      return FogMazeStepOutcome.sanctumRevealed;
    }

    // Outer deep-fog boundary wrap (northern/eastern bramble mist edges)
    if (currentPos.dy < 54.0 || currentPos.dx > 1468.0) {
      _mistFlashAlpha = 0.65;
      if (!bypassMaze) _mazeStage = 0;
      return FogMazeStepOutcome.wrappedToEntrance;
    }

    if (_mazeStage == 0) {
      if ((currentPos - acousticWaypoints[0]).distance <= 46.0) {
        _mazeStage = 1;
        return FogMazeStepOutcome.waypointHarmonized;
      }
      // Wrong-way turn: charging straight north into the unparted central mist or far east
      if ((currentPos.dy < 180.0 && currentPos.dx > 1010.0) ||
          currentPos.dx > 1308.0) {
        _mistFlashAlpha = 0.65;
        return FogMazeStepOutcome.wrappedToEntrance;
      }
    } else if (_mazeStage == 1) {
      if ((currentPos - acousticWaypoints[1]).distance <= 46.0) {
        _mazeStage = 2;
        return FogMazeStepOutcome.sanctumRevealed;
      }
      // Wrong-way turn: charging north into the unparted sanctum before the east chime
      if (currentPos.dy < 156.0 ||
          (currentPos.dx < 972.0 && currentPos.dy > 172.0)) {
        _mazeStage = 0;
        _mistFlashAlpha = 0.65;
        return FogMazeStepOutcome.wrappedToEntrance;
      }
    }

    return FogMazeStepOutcome.none;
  }

  @override
  void update(double dt) {
    _time += dt;
    if (_mistFlashAlpha > 0.0) {
      _mistFlashAlpha = math.max(0.0, _mistFlashAlpha - dt * 1.4);
    }
  }

  @override
  void render(Canvas canvas) {
    final baseAlpha = isPlayerInside ? (isSanctumUnlocked ? 0.28 : 0.44) : 0.24;
    canvas.drawRect(
      fogBounds,
      Paint()..color = Color.fromRGBO(38, 18, 66, baseAlpha),
    );

    // Drifting purple-teal fog wisps
    for (var i = 0; i < 14; i++) {
      final phase = _time * (0.25 + (i % 3) * 0.08) + i * 1.7;
      final cx = fogBounds.left +
          ((i * 47.0 + math.sin(phase) * 36.0) % fogBounds.width).abs();
      final cy = fogBounds.top +
          ((i * 29.0 + math.cos(phase * 0.8) * 22.0) % fogBounds.height).abs();
      final isTeal = i.isEven;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: 92, height: 38),
        Paint()
          ..color = isTeal
              ? const Color.fromRGBO(56, 242, 212, 0.14)
              : const Color.fromRGBO(157, 78, 221, 0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }

    // Soft mist-wrap flash when teleported back to Undergrowth threshold
    if (_mistFlashAlpha > 0.01) {
      canvas.drawRect(
        fogBounds,
        Paint()..color = Color.fromRGBO(128, 255, 219, _mistFlashAlpha * 0.45),
      );
    }

    // Accessible subtle C-Major acoustic shimmer ring toward active bell target
    if (isPlayerInside && visualAssistEnabled) {
      final target = activeBellTarget;
      final toBell = target - playerPos;
      final dist = toBell.distance;
      if (dist > 24.0) {
        final dir = Offset(toBell.dx / dist, toBell.dy / dist);
        final pulse = 0.5 + 0.5 * math.sin(_time * 3.6);
        final shimmerPos = playerPos + dir * (26.0 + pulse * 8.0);
        canvas.drawCircle(
          shimmerPos,
          4.0 + pulse * 2.5,
          Paint()
            ..color = Color.fromRGBO(255, 214, 102, 0.38 + 0.35 * pulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }
  }
}
