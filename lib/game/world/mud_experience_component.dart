import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../actors/npc_actor.dart';
import '../actors/player_walnut.dart';
import '../actors/stage_performer_director.dart';
import 'day_night_atmosphere.dart';
import 'stage_3d_rig_component.dart';
import 'tiled_map_parser.dart';

class _MudSkidMark {
  _MudSkidMark({
    required this.from,
    required this.to,
    required this.width,
  });

  final Offset from;
  final Offset to;
  final double width;
  double age = 0.0;
  static const double maxAge = 12.0;
}

class _MudGroundSplat {
  _MudGroundSplat({
    required this.pos,
    required this.radius,
    required this.seed,
  });

  final Offset pos;
  final double radius;
  final int seed;
  double age = 0.0;
  static const double maxAge = 15.0;
}

class _MudProjectile3D {
  _MudProjectile3D({
    required this.x,
    required this.y,
    required this.z,
    required this.vx,
    required this.vy,
    required this.vz,
    required this.fromPlayer,
    this.sourceId,
  });

  double x;
  double y;
  double z;
  final double vx;
  final double vy;
  double vz;
  final bool fromPlayer;
  final String? sourceId;
}

class _MudBurstDroplet {
  _MudBurstDroplet({
    required this.x,
    required this.y,
    required this.z,
    required this.vx,
    required this.vy,
    required this.vz,
    required this.radius,
  });

  double x;
  double y;
  double z;
  final double vx;
  final double vy;
  double vz;
  final double radius;
  double age = 0.0;
  static const double maxAge = 0.55;
}

class _FloatingMudCallout {
  _FloatingMudCallout({
    required this.pos,
    required this.text,
  });

  final Offset pos;
  final String text;
  double age = 0.0;
  static const double maxAge = 1.65;
}

class _QueuedReturnThrow {
  _QueuedReturnThrow({
    required this.delay,
    required this.fromPos,
    required this.sourceId,
  });

  double delay;
  final Offset fromPos;
  final String sourceId;
}

/// Joyful festival walnut who slides & plays mud fights in the Velvet-to-Main-Roots Mud Pit after Set 8!
class MudRevelerComponent extends PositionComponent {
  MudRevelerComponent({
    required this.id,
    required this.displayName,
    required this.spriteSheet,
    required this.homeStart,
    required this.homeEnd,
    required this.metricsGetter,
    required double phaseOffset,
  })  : _animClock = phaseOffset,
        super(
          position: Vector2(homeStart.dx, homeStart.dy),
          size: Vector2.all(32),
          anchor: Anchor.center,
        );

  final String id;
  final String displayName;
  final Image spriteSheet;
  final Offset homeStart;
  final Offset homeEnd;
  final DayNightMetrics Function() metricsGetter;

  double _animClock;
  bool _headingToEnd = true;
  double _slideBurstTimer = 0.0;
  double _nextSlideIn = 2.4;
  double _hopTimer = 0.0;
  double _reactionTimer = 0.0;
  String? _reactionText;
  double mudSplatter = 0.35;
  int _facingRow = 2;

  bool get isSliding => _slideBurstTimer > 0.0;

  void receiveMudSplat(String text) {
    mudSplatter = (mudSplatter + 0.50).clamp(0.0, 1.0);
    _hopTimer = 0.45;
    _reactionText = text;
    _reactionTimer = 1.9;
  }

  Offset? stepReveler(double dt) {
    _animClock += dt;
    if (_hopTimer > 0.0) _hopTimer = math.max(0.0, _hopTimer - dt);
    if (_reactionTimer > 0.0) {
      _reactionTimer = math.max(0.0, _reactionTimer - dt);
    }

    _nextSlideIn -= dt;
    if (_nextSlideIn <= 0.0 && _slideBurstTimer <= 0.0) {
      _slideBurstTimer = 0.72;
      _nextSlideIn = 2.6 + (id.hashCode.abs() % 5) * 0.45;
    }
    if (_slideBurstTimer > 0.0) {
      _slideBurstTimer = math.max(0.0, _slideBurstTimer - dt);
    }

    final target = _headingToEnd ? homeEnd : homeStart;
    final dx = target.dx - position.x;
    final dy = target.dy - position.y;
    final dist = math.sqrt(dx * dx + dy * dy);
    final prev = Offset(position.x, position.y);

    if (dist < 6.0) {
      _headingToEnd = !_headingToEnd;
    } else {
      final speed = isSliding ? 148.0 : 54.0;
      final step = math.min(dist, speed * dt);
      final vx = (dx / dist) * speed;
      final vy = (dy / dist) * speed;
      position.x += (dx / dist) * step;
      position.y += (dy / dist) * step;
      if (vx.abs() > vy.abs()) {
        _facingRow = vx < 0 ? 1 : 2;
      } else {
        _facingRow = vy < 0 ? 3 : 0;
      }
    }
    priority = position.y.round();
    return isSliding ? prev : null;
  }

  @override
  void render(Canvas canvas) {
    final metrics = metricsGetter();
    final hop =
        _hopTimer > 0.0 ? math.sin((_hopTimer / 0.45) * math.pi) * 5.2 : 0.0;

    renderActor3dShadow(
      canvas: canvas,
      metrics: metrics,
      centerX: 16.0,
      footY: 28.5,
    );

    if (isSliding) {
      final sprayPaint = Paint()..color = const Color(0xCC5C3A21);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(16, 27.5), width: 22, height: 7),
        sprayPaint,
      );
      for (var i = 0; i < 4; i++) {
        final p = (_animClock * 12.0 + i * 0.25) % 1.0;
        final side = i.isEven ? -1.0 : 1.0;
        canvas.drawCircle(
          Offset(16.0 + side * (7.0 + 7.5 * p), 26.5 - math.sin(p * math.pi) * 5.0),
          1.5 * (1.0 - p * 0.4),
          sprayPaint,
        );
      }
    }

    final frameCol = 1 + ((_animClock * 7.5).floor() % 2);
    final src = Rect.fromLTWH(frameCol * 32.0, _facingRow * 32.0, 32.0, 32.0);

    canvas.save();
    if (isSliding) {
      final dirSign = _facingRow == 1 ? -1.0 : 1.0;
      canvas.translate(16.0, 23.0);
      canvas.rotate(dirSign * 0.24);
      canvas.scale(1.12, 0.82);
      canvas.translate(-16.0, -23.0);
    }
    canvas.drawImageRect(
      spriteSheet,
      src,
      Rect.fromLTWH(0, isSliding ? 2.0 : -hop, 32.0, 32.0),
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );

    // Mud flecks on playful mud-reveler shell
    final mudPaint = Paint()..color = const Color(0xCC4A2C18);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(13, 19 - hop), width: 4.0, height: 2.5),
      mudPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(19.5, 16.5 - hop), width: 3.4, height: 2.3),
      mudPaint,
    );
    canvas.restore();

    if (_reactionTimer > 0.0 && _reactionText != null) {
      final fade = (_reactionTimer / 0.4).clamp(0.0, 1.0);
      renderCenteredWorldPill(
        canvas: canvas,
        center: Offset(16.0, -5.0 - hop - (1.9 - _reactionTimer) * 4.0),
        text: _reactionText!,
        fontSize: 6.0,
        textColor: Color.fromRGBO(255, 224, 130, fade),
        backgroundColor: Color.fromRGBO(36, 22, 14, 0.86 * fade),
        horizontalPadding: 6.0,
        pillHeight: 11.8,
        minPillWidth: 44.0,
        maxPillWidth: 108.0,
        borderRadius: 5.0,
      );
    }
  }
}

/// Coordinates the post-rain Woodstock Mud Experience: belly-slide skid trails, 3D mudballs,
/// friendly NPC mud fights, and Mud Pit Meadow festivities!
class MudExperienceController {
  MudExperienceController({
    required this.map,
    required this.characterSheets,
    required this.metricsGetter,
    required this.cameraCenterGetter,
    required this.timeGetter,
    required this.onPlayMudSfx,
    required this.onPlayerScoredMudSplat,
    required this.onPlayerHitByFriendlyMud,
    this.viewBoundsGetter,
  }) {
    groundLayer = _MudGroundLayerComponent(controller: this, priority: -4300);
    airborneLayer = _MudAirborneLayerComponent(controller: this, priority: 7200);
  }

  final OrchardMapData map;
  final Map<String, Image> characterSheets;
  final DayNightMetrics Function() metricsGetter;
  final Offset Function() cameraCenterGetter;
  final Rect Function()? viewBoundsGetter;
  final double Function() timeGetter;
  final void Function(double pan, double volume) onPlayMudSfx;
  final void Function(String targetName) onPlayerScoredMudSplat;
  final void Function() onPlayerHitByFriendlyMud;

  late final Component groundLayer;
  late final Component airborneLayer;

  final List<_MudSkidMark> _skids = [];
  final List<_MudGroundSplat> _splats = [];
  final List<_MudProjectile3D> _projectiles = [];
  final List<_MudBurstDroplet> _droplets = [];
  final List<_FloatingMudCallout> _callouts = [];
  final List<_QueuedReturnThrow> _queuedReturns = [];
  final List<MudRevelerComponent> _revelers = [];
  final Set<String> _slideBowledIds = {};

  bool _mudPartyActive = false;
  double _throwCooldown = 0.0;
  double _revelerCrossfireTimer = 1.6;
  Offset? _lastPlayerSkidPos;
  int _seedCounter = 1;

  int get activeProjectileCount => _projectiles.length;
  int get groundDecalCount => _skids.length + _splats.length;
  int get activeRevelerCount => _revelers.length;
  List<MudRevelerComponent> get revelers => _revelers;

  static const List<String> _cheerReactions = [
    'SPLAT! 😂',
    'MUD PEACE! ✌️',
    'NICE TOSS! 🤎',
    "WOODSTOCK '69!",
    'GROOVY MUD!',
  ];

  void update({
    required double dt,
    required World world,
    required bool mudPartyActive,
    required bool orchardMuddy,
    required PlayerWalnut player,
    required List<NpcActor> npcs,
  }) {
    _mudPartyActive = mudPartyActive;
    if (_throwCooldown > 0.0) {
      _throwCooldown = math.max(0.0, _throwCooldown - dt);
    }

    // 1. Spawn or despawn the 4 joyful Mud Pit Meadow revelers when post-Set-8 Mud Experience is active!
    _syncRevelers(world, mudPartyActive);

    // 2. Record 3D glossy mud skid ribbons behind the player during belly-slides & fast mud drifts
    final pPos = Offset(player.position.x, player.position.y);
    final playerOnMud = map.isSlipperyAtWorld(pPos.dx, pPos.dy);
    if ((player.isBellySliding || (playerOnMud && player.velocity.length > 82.0))) {
      final prev = _lastPlayerSkidPos;
      if (prev != null && (pPos - prev).distance >= 5.5) {
        _addSkid(
          prev,
          pPos,
          width: player.isBellySliding ? 11.5 : 6.5,
        );
        _lastPlayerSkidPos = pPos;
      } else if (prev == null) {
        _lastPlayerSkidPos = pPos;
      }
    } else {
      _lastPlayerSkidPos = null;
      _slideBowledIds.clear();
    }

    // 3. Belly-Slide Bowling: sliding past mud-revelers or off-stage NPCs splashes everyone in joyful mud!
    if (player.isBellySliding) {
      for (final rev in _revelers) {
        if (_slideBowledIds.contains(rev.id)) continue;
        if (rev.position.distanceTo(player.position) < 24.0) {
          _slideBowledIds.add(rev.id);
          rev.receiveMudSplat('SLIDE STRIKE! 🎳');
          _spawnSplatBurst(Offset(rev.position.x, rev.position.y), radius: 11.5);
          _callouts.add(
            _FloatingMudCallout(
              pos: Offset(rev.position.x, rev.position.y - 16.0),
              text: 'MUD BOWLING! 🎳🤎',
            ),
          );
          onPlayMudSfx(0.0, 0.52);
          onPlayerScoredMudSplat(rev.displayName);
        }
      }
      for (final npc in npcs) {
        if (npc.isOnStagePerforming || npc.stageMark != null) continue;
        if (_slideBowledIds.contains(npc.spec.id)) continue;
        if (npc.position.distanceTo(player.position) < 23.0) {
          _slideBowledIds.add(npc.spec.id);
          if (npc.receiveMudSplat('SLIDE WAVE! ✌️')) {
            _spawnSplatBurst(Offset(npc.position.x, npc.position.y), radius: 11.0);
            onPlayMudSfx(0.0, 0.48);
            onPlayerScoredMudSplat(npc.spec.name);
          }
        }
      }
    }

    // 4. Step Mud Revelers & friendly mudball crossfire in the Mud Pit Meadow
    if (mudPartyActive && _revelers.isNotEmpty) {
      for (final rev in _revelers) {
        final prevSlidePos = rev.stepReveler(dt);
        if (prevSlidePos != null) {
          final cur = Offset(rev.position.x, rev.position.y);
          if ((cur - prevSlidePos).distance >= 4.0) {
            _addSkid(prevSlidePos, cur, width: 9.5);
          }
        }
      }

      _revelerCrossfireTimer -= dt;
      if (_revelerCrossfireTimer <= 0.0) {
        _revelerCrossfireTimer = 2.1 + (_seedCounter % 3) * 0.55;
        final thrower = _revelers[_seedCounter % _revelers.length];
        _seedCounter++;
        final from = Offset(thrower.position.x, thrower.position.y);
        final distToPlayer = (pPos - from).distance;
        // If player is hanging out in the Mud Pit, occasionally lob a playful mudball their way!
        if (distToPlayer < 175.0 && (_seedCounter % 2 == 0)) {
          _launchParabolicMudball(
            from: from,
            to: pPos + Offset((_seedCounter % 3 - 1) * 10.0, 0),
            fromPlayer: false,
            sourceId: thrower.id,
          );
        } else {
          final peer = _revelers[(_seedCounter + 1) % _revelers.length];
          _launchParabolicMudball(
            from: from,
            to: Offset(peer.position.x, peer.position.y),
            fromPlayer: false,
            sourceId: thrower.id,
          );
        }
      }
    }

    // 5. Process queued playful return mudballs from splatted NPCs/revelers
    for (var i = _queuedReturns.length - 1; i >= 0; i--) {
      final q = _queuedReturns[i];
      q.delay -= dt;
      if (q.delay <= 0.0) {
        _queuedReturns.removeAt(i);
        _launchParabolicMudball(
          from: q.fromPos,
          to: Offset(player.position.x, player.position.y),
          fromPlayer: false,
          sourceId: q.sourceId,
        );
      }
    }

    // 6. Step 3D parabolic mudball projectiles & check collisions
    _stepProjectiles(dt, player, npcs);

    // 7. Step 3D burst droplets, callouts & fade decals
    for (var i = _droplets.length - 1; i >= 0; i--) {
      final d = _droplets[i];
      d.age += dt;
      d.x += d.vx * dt;
      d.y += d.vy * dt;
      d.z = math.max(0.0, d.z + d.vz * dt);
      d.vz -= 220.0 * dt;
      if (d.age >= _MudBurstDroplet.maxAge) {
        _droplets.removeAt(i);
      }
    }

    for (var i = _callouts.length - 1; i >= 0; i--) {
      _callouts[i].age += dt;
      if (_callouts[i].age >= _FloatingMudCallout.maxAge) {
        _callouts.removeAt(i);
      }
    }

    final fadeScale = (!orchardMuddy && !mudPartyActive) ? 3.0 : 1.0;
    for (var i = _skids.length - 1; i >= 0; i--) {
      _skids[i].age += dt * fadeScale;
      if (_skids[i].age >= _MudSkidMark.maxAge) {
        _skids.removeAt(i);
      }
    }
    for (var i = _splats.length - 1; i >= 0; i--) {
      _splats[i].age += dt * fadeScale;
      if (_splats[i].age >= _MudGroundSplat.maxAge) {
        _splats.removeAt(i);
      }
    }
  }

  void recordSlideCallout(Offset pos) {
    _spawnSplatBurst(pos, radius: 9.0);
    _callouts.add(_FloatingMudCallout(pos: pos.translate(0, -14), text: 'MUD SLIDE! 🛝'));
  }

  /// Scoops & lobs a 3D glossy mudball toward the nearest playful target or facing direction!
  bool throwPlayerMudball({
    required PlayerWalnut player,
    required List<NpcActor> npcs,
    required bool mudAllowed,
    Offset? targetWorldPos,
  }) {
    if (_throwCooldown > 0.0) return false;
    final pPos = Offset(player.position.x, player.position.y);
    final onMudTile = map.isSlipperyAtWorld(pPos.dx, pPos.dy);
    if (!mudAllowed && !onMudTile) return false;

    _throwCooldown = 0.28;
    player.receiveMudSplat(0.14);

    final aimTarget = targetWorldPos ?? _selectBestAutoTarget(player, npcs);
    _launchParabolicMudball(
      from: pPos,
      to: aimTarget,
      fromPlayer: true,
      sourceId: 'player',
    );
    onPlayMudSfx(0.0, 0.42);
    return true;
  }

  Offset _selectBestAutoTarget(PlayerWalnut player, List<NpcActor> npcs) {
    final pPos = Offset(player.position.x, player.position.y);
    final facing = player.facingUnitVector;
    Offset? bestTarget;
    var bestScore = double.infinity;

    void consider(Offset candidatePos) {
      final delta = candidatePos - pPos;
      final dist = delta.distance;
      if (dist < 10.0 || dist > 195.0) return;
      final dirDot =
          (delta.dx * facing.x + delta.dy * facing.y) / math.max(1.0, dist);
      // Prefer targets roughly in front of player, but still lock onto close mud-fight buddies!
      final anglePenalty = dirDot >= -0.15 ? (1.0 - dirDot) * 28.0 : 95.0;
      final score = dist + anglePenalty;
      if (score < bestScore) {
        bestScore = score;
        bestTarget = candidatePos;
      }
    }

    for (final rev in _revelers) {
      consider(Offset(rev.position.x, rev.position.y));
    }
    for (final npc in npcs) {
      if (npc.isOnStagePerforming || npc.stageMark != null) continue;
      consider(Offset(npc.position.x, npc.position.y));
    }

    if (bestTarget != null) return bestTarget!;
    return Offset(
      (pPos.dx + facing.x * 112.0).clamp(24.0, map.pixelWidth - 24.0),
      (pPos.dy + facing.y * 112.0).clamp(24.0, map.pixelHeight - 24.0),
    );
  }

  void _launchParabolicMudball({
    required Offset from,
    required Offset to,
    required bool fromPlayer,
    String? sourceId,
  }) {
    final delta = to - from;
    final dist = delta.distance.clamp(28.0, 210.0);
    final flightTime = (dist / 195.0).clamp(0.30, 0.88);
    final vx = delta.dx / flightTime;
    final vy = delta.dy / flightTime;
    const gravity = 220.0;
    const startZ = 12.0;
    // Solve z(flightTime) = 0 => startZ + vz * T - 0.5 * g * T^2 = 0
    final vz = (0.5 * gravity * flightTime * flightTime - startZ) / flightTime;

    _projectiles.add(
      _MudProjectile3D(
        x: from.dx,
        y: from.dy,
        z: startZ,
        vx: vx,
        vy: vy,
        vz: vz,
        fromPlayer: fromPlayer,
        sourceId: sourceId,
      ),
    );
  }

  void _stepProjectiles(
    double dt,
    PlayerWalnut player,
    List<NpcActor> npcs,
  ) {
    const gravity = 220.0;
    final camX = cameraCenterGetter().dx;

    for (var i = _projectiles.length - 1; i >= 0; i--) {
      final m = _projectiles[i];
      m.x += m.vx * dt;
      m.y += m.vy * dt;
      m.z += m.vz * dt;
      m.vz -= gravity * dt;

      // Low enough in 3D arc (`z < 22`) to splat a walnut shell!
      if (m.z < 22.0) {
        if (m.fromPlayer) {
          var hitSomething = false;
          for (final rev in _revelers) {
            final dx = rev.position.x - m.x;
            final dy = rev.position.y - m.y;
            if (dx * dx + dy * dy <= 21.0 * 21.0) {
              final cheer =
                  _cheerReactions[_seedCounter++ % _cheerReactions.length];
              rev.receiveMudSplat(cheer);
              _impactAt(Offset(rev.position.x, rev.position.y), camX);
              onPlayerScoredMudSplat(rev.displayName);
              _queueReturnThrow(
                Offset(rev.position.x, rev.position.y),
                rev.id,
              );
              hitSomething = true;
              break;
            }
          }
          if (!hitSomething) {
            for (final npc in npcs) {
              if (npc.isOnStagePerforming || npc.stageMark != null) continue;
              final dx = npc.position.x - m.x;
              final dy = npc.position.y - m.y;
              if (dx * dx + dy * dy <= 21.0 * 21.0) {
                final cheer =
                    _cheerReactions[_seedCounter++ % _cheerReactions.length];
                if (npc.receiveMudSplat(cheer)) {
                  _impactAt(Offset(npc.position.x, npc.position.y), camX);
                  onPlayerScoredMudSplat(npc.spec.name);
                  _queueReturnThrow(
                    Offset(npc.position.x, npc.position.y),
                    npc.spec.id,
                  );
                  hitSomething = true;
                  break;
                }
              }
            }
          }
          if (hitSomething) {
            _projectiles.removeAt(i);
            continue;
          }
        } else {
          // Friendly NPC / reveler mudball: check player or peer revelers!
          final dxP = player.position.x - m.x;
          final dyP = player.position.y - m.y;
          if (dxP * dxP + dyP * dyP <= 18.0 * 18.0) {
            player.receiveMudSplat(0.45);
            _impactAt(Offset(player.position.x, player.position.y), camX);
            _callouts.add(
              _FloatingMudCallout(
                pos: Offset(player.position.x, player.position.y - 18.0),
                text: 'SPLATTED! 😂✌️',
              ),
            );
            onPlayerHitByFriendlyMud();
            _projectiles.removeAt(i);
            continue;
          }
          var hitPeer = false;
          for (final rev in _revelers) {
            if (rev.id == m.sourceId) continue;
            final dx = rev.position.x - m.x;
            final dy = rev.position.y - m.y;
            if (dx * dx + dy * dy <= 18.0 * 18.0) {
              rev.receiveMudSplat('HAHA! 🤎');
              _impactAt(Offset(rev.position.x, rev.position.y), camX, quiet: true);
              hitPeer = true;
              break;
            }
          }
          if (hitPeer) {
            _projectiles.removeAt(i);
            continue;
          }
        }
      }

      // Ground impact when z <= 0
      if (m.z <= 0.0) {
        _impactAt(Offset(m.x, m.y), camX, quiet: !m.fromPlayer);
        _projectiles.removeAt(i);
      }
    }
  }

  void _queueReturnThrow(Offset fromPos, String sourceId) {
    if (_queuedReturns.length >= 3) return;
    _queuedReturns.add(
      _QueuedReturnThrow(
        delay: 0.72,
        fromPos: fromPos,
        sourceId: sourceId,
      ),
    );
  }

  void _impactAt(Offset pos, double camX, {bool quiet = false}) {
    _spawnSplatBurst(pos, radius: 10.5);
    final pan = ((pos.dx - camX) / 220.0).clamp(-0.85, 0.85);
    if (!quiet || (pos.dx - camX).abs() < 260.0) {
      onPlayMudSfx(pan, quiet ? 0.22 : 0.48);
    }
  }

  void _addSkid(Offset from, Offset to, {required double width}) {
    if (_skids.length >= 90) {
      _skids.removeAt(0);
    }
    _skids.add(_MudSkidMark(from: from, to: to, width: width));
  }

  void _spawnSplatBurst(Offset pos, {required double radius}) {
    if (_splats.length >= 55) {
      _splats.removeAt(0);
    }
    final seed = _seedCounter++;
    _splats.add(_MudGroundSplat(pos: pos, radius: radius, seed: seed));
    for (var i = 0; i < 9; i++) {
      final ang = (i / 9.0) * math.pi * 2.0 + (seed % 7) * 0.21;
      final spd = 24.0 + ((seed + i * 13) % 28);
      _droplets.add(
        _MudBurstDroplet(
          x: pos.dx,
          y: pos.dy,
          z: 4.0,
          vx: math.cos(ang) * spd,
          vy: math.sin(ang) * spd * 0.65,
          vz: 48.0 + ((seed + i * 7) % 36),
          radius: 1.5 + (i % 3) * 0.55,
        ),
      );
    }
  }

  void _syncRevelers(World world, bool shouldHaveRevelers) {
    if (!shouldHaveRevelers) {
      if (_revelers.isNotEmpty) {
        for (final r in _revelers) {
          r.removeFromParent();
        }
        _revelers.clear();
      }
      return;
    }

    if (_revelers.isNotEmpty || characterSheets.isEmpty) return;

    final fallback = characterSheets.values.first;
    final specs = <(String, String, String, Offset, Offset, double)>[
      (
        'mud_reveler_velvet_w',
        'Sunny Slider',
        'chandler',
        const Offset(236.0, 576.0),
        const Offset(328.0, 594.0),
        0.0,
      ),
      (
        'mud_reveler_velvet_e',
        'Groovy Gus',
        'howard',
        const Offset(424.0, 608.0),
        const Offset(332.0, 584.0),
        1.1,
      ),
      (
        'mud_reveler_roots_w',
        'Mud-Lark Meadow',
        'tulare',
        const Offset(468.0, 596.0),
        const Offset(566.0, 616.0),
        2.3,
      ),
      (
        'mud_reveler_roots_e',
        'Woodstock Wally',
        'franquette',
        const Offset(662.0, 592.0),
        const Offset(562.0, 608.0),
        3.4,
      ),
    ];

    for (final (id, name, sheetKey, start, end, phase) in specs) {
      final comp = MudRevelerComponent(
        id: id,
        displayName: name,
        spriteSheet: characterSheets[sheetKey] ?? fallback,
        homeStart: start,
        homeEnd: end,
        metricsGetter: metricsGetter,
        phaseOffset: phase,
      );
      _revelers.add(comp);
      world.add(comp);
    }
  }
}

class _MudGroundLayerComponent extends Component {
  _MudGroundLayerComponent({
    required this.controller,
    super.priority,
  });

  final MudExperienceController controller;

  @override
  void render(Canvas canvas) {
    final cam = controller.cameraCenterGetter();
    final view = controller.viewBoundsGetter?.call().inflate(60.0) ??
        Rect.fromCenter(center: cam, width: 720, height: 680);
    final t = controller.timeGetter();

    // 1. Festive Woodstock Mud Pit Meadow ground banners & puddle glints after Set 8!
    if (controller._mudPartyActive) {
      for (final bannerCenter in const [
        Offset(286.0, 548.0),
        Offset(564.0, 566.0),
      ]) {
        if (view.inflate(90).contains(bannerCenter)) {
          _renderMudPitSignpost(canvas, bannerCenter, t);
        }
      }
    }

    // 2. 3D Belly-Slide & Mud-Drift Skid Ribbons
    for (final skid in controller._skids) {
      if (!view.inflate(32).contains(skid.from) &&
          !view.inflate(32).contains(skid.to)) {
        continue;
      }
      final alpha = (1.0 - skid.age / _MudSkidMark.maxAge).clamp(0.0, 1.0);
      final rimPaint = Paint()
        ..color = Color.fromRGBO(146, 98, 62, 0.46 * alpha)
        ..strokeWidth = skid.width + 2.4
        ..strokeCap = StrokeCap.round;
      final troughPaint = Paint()
        ..color = Color.fromRGBO(58, 34, 18, 0.64 * alpha)
        ..strokeWidth = skid.width
        ..strokeCap = StrokeCap.round;
      final sheenPaint = Paint()
        ..color = Color.fromRGBO(208, 168, 128, 0.25 * alpha)
        ..strokeWidth = skid.width * 0.28
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(skid.from, skid.to, rimPaint);
      canvas.drawLine(skid.from, skid.to, troughPaint);
      canvas.drawLine(
        skid.from.translate(0, -1.0),
        skid.to.translate(0, -1.0),
        sheenPaint,
      );
    }

    // 3. 3D Multi-Lobed Mudball Splat Puddles
    for (final s in controller._splats) {
      if (!view.inflate(24).contains(s.pos)) continue;
      final alpha = (1.0 - s.age / _MudGroundSplat.maxAge).clamp(0.0, 1.0);
      final basePaint =
          Paint()..color = Color.fromRGBO(68, 40, 22, 0.72 * alpha);
      final specPaint =
          Paint()..color = Color.fromRGBO(164, 112, 74, 0.50 * alpha);

      canvas.drawOval(
        Rect.fromCenter(
          center: s.pos,
          width: s.radius * 2.1,
          height: s.radius * 1.15,
        ),
        basePaint,
      );
      for (var k = 0; k < 5; k++) {
        final ang = (k / 5.0) * math.pi * 2.0 + (s.seed % 11) * 0.4;
        final lobe = Offset(
          s.pos.dx + math.cos(ang) * s.radius * 0.85,
          s.pos.dy + math.sin(ang) * s.radius * 0.48,
        );
        canvas.drawOval(
          Rect.fromCenter(
              center: lobe, width: s.radius * 0.7, height: s.radius * 0.45),
          basePaint,
        );
      }
      canvas.drawOval(
        Rect.fromCenter(
          center: s.pos.translate(-s.radius * 0.25, -s.radius * 0.14),
          width: s.radius * 0.65,
          height: s.radius * 0.30,
        ),
        specPaint,
      );
    }
  }

  void _renderMudPitSignpost(Canvas canvas, Offset center, double t) {
    final shimmer = 0.5 + 0.5 * math.sin(t * 2.8 + center.dx);
    // Inviting concentric mud-ring ripple around the mud pit hub
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 18), width: 68, height: 24),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Color.fromRGBO(186, 132, 86, 0.22 + 0.16 * shimmer),
    );
    // Wooden festival plank post
    canvas.drawRect(
      Rect.fromCenter(center: center.translate(0, 5), width: 3.0, height: 10.0),
      Paint()..color = const Color(0xFF5C3A21),
    );
    renderCenteredWorldPill(
      canvas: canvas,
      center: center,
      text: '🛝 MUD PIT · SLIDE [SHIFT] · TOSS [F]',
      fontSize: 5.8,
      textColor: const Color(0xFFFFE599),
      backgroundColor: const Color(0xEE3B2314),
      borderColor: const Color(0xFFFFB703),
      borderWidth: 1.0,
      horizontalPadding: 6.5,
      pillHeight: 12.6,
      minPillWidth: 92.0,
      maxPillWidth: 164.0,
      borderRadius: 3.5,
    );
  }
}

class _MudAirborneLayerComponent extends Component {
  _MudAirborneLayerComponent({
    required this.controller,
    super.priority,
  });

  final MudExperienceController controller;

  @override
  void render(Canvas canvas) {
    final metrics = controller.metricsGetter();
    final cam = controller.cameraCenterGetter();
    final view = controller.viewBoundsGetter?.call().inflate(60.0) ??
        Rect.fromCenter(center: cam, width: 720, height: 680);

    // 1. Render 3D Parabolic Mudballs with Ground Shadow + Blinn-Phong Highlight!
    for (final m in controller._projectiles) {
      final groundPos = Offset(m.x, m.y);
      if (!view.inflate(40).contains(groundPos)) continue;

      final heightFactor = (1.0 - (m.z / 75.0)).clamp(0.35, 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            m.x + metrics.shadowOffset.dx * 0.35,
            m.y + 4.0,
          ),
          width: 9.0 * heightFactor,
          height: 4.2 * heightFactor,
        ),
        Paint()..color = Color.fromRGBO(12, 10, 8, 0.38 * heightFactor),
      );

      final ballCenter = Offset(m.x, m.y - m.z);
      // Outer dark umber 3D sphere
      canvas.drawCircle(
        ballCenter,
        4.4,
        Paint()..color = const Color(0xFF4A2C18),
      );
      // Warm cocoa diffuse core
      canvas.drawCircle(
        ballCenter.translate(-0.7, -0.7),
        3.2,
        Paint()..color = const Color(0xFF7F5539),
      );
      // Wet specular highlight
      canvas.drawCircle(
        ballCenter.translate(-1.4, -1.5),
        1.2,
        Paint()..color = const Color(0xFFDDB892),
      );
    }

    // 2. Render 3D Mud-Splat Burst Droplets
    final dropPaint = Paint()..color = const Color(0xDD6C462B);
    final dropSpec = Paint()..color = const Color(0xCC9C6644);
    for (final d in controller._droplets) {
      final pos = Offset(d.x, d.y - d.z);
      if (!view.inflate(20).contains(pos)) continue;
      final shrink = (1.0 - d.age / _MudBurstDroplet.maxAge).clamp(0.2, 1.0);
      canvas.drawCircle(pos, d.radius * shrink, dropPaint);
      canvas.drawCircle(
          pos.translate(-0.4, -0.4), d.radius * 0.45 * shrink, dropSpec);
    }

    // 3. Render Cheerful Floating Mud-Fight Callouts
    for (final c in controller._callouts) {
      if (!view.inflate(40).contains(c.pos)) continue;
      final t = (c.age / _FloatingMudCallout.maxAge).clamp(0.0, 1.0);
      final alpha = (1.0 - t * t).clamp(0.0, 1.0);
      final y = c.pos.dy - t * 16.0;
      renderCenteredWorldPill(
        canvas: canvas,
        center: Offset(c.pos.dx, y),
        text: c.text,
        fontSize: 6.2,
        textColor: Color.fromRGBO(255, 214, 102, alpha),
        backgroundColor: Color.fromRGBO(42, 24, 14, 0.88 * alpha),
        horizontalPadding: 6.5,
        pillHeight: 12.4,
        minPillWidth: 52.0,
        maxPillWidth: 136.0,
        borderRadius: 5.0,
      );
    }
  }
}
