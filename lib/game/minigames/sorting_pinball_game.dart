import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/soloud_audio_service.dart';
import '../../state/providers.dart';

class WalnutPinball {
  WalnutPinball({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    this.inShooterLane = false,
    this.isRockHazard = false,
  });

  double x;
  double y;
  double vx;
  double vy;
  double spinAngle = 0.0;
  double spinVel = 4.0;
  bool inShooterLane;
  bool isRockHazard;
  double stallTimer = 0.0;
  final List<Offset> trail = <Offset>[];
}

class PinballBumper {
  PinballBumper({
    required this.pos,
    required this.radius,
    required this.basePoints,
    required this.color,
    required this.label,
  });

  final Offset pos;
  final double radius;
  final int basePoints;
  final Color color;
  final String label;
  double flash = 0.0;
}

class PinballDropTarget {
  PinballDropTarget({
    required this.a,
    required this.b,
    required this.letter,
  });

  final Offset a;
  final Offset b;
  final String letter;
  bool isDown = false;
  double flash = 0.0;

  Offset get center => Offset((a.dx + b.dx) * 0.5, (a.dy + b.dy) * 0.5);
}

class PinballScorePopup {
  PinballScorePopup({
    required this.pos,
    required this.text,
    required this.color,
  });

  Offset pos;
  final String text;
  final Color color;
  double age = 0.0;
  static const double maxAge = 0.85;
}

class _WallSeg {
  const _WallSeg(this.a, this.b, {this.restitution = 0.72, this.isSlingshot = false});
  final Offset a;
  final Offset b;
  final double restitution;
  final bool isSlingshot;
}

class PinballSimulation {
  PinballSimulation({this.autoGroove = false}) {
    _initPlayfield();
    // Start immediately with an active 3D walnut dropping through the top rollover arch!
    balls.add(
      WalnutPinball(
        x: 242.0,
        y: 62.0,
        vx: 78.0,
        vy: 35.0,
        inShooterLane: false,
      ),
    );
  }

  static const double boardW = 520.0;
  static const double boardH = 680.0;
  static const double ballRadius = 13.0;
  static const double mainAreaRight = 464.0;
  static const double shooterLaneCenterX = 490.0;

  bool autoGroove;
  int score = 0;
  int combo = 1;
  int primeGradeCount = 0;
  int multiballCount = 0;
  bool kickbackLit = true;
  double kickbackFlash = 0.0;

  bool leftFlipperUp = false;
  bool rightFlipperUp = false;
  bool plungerHeld = false;
  double plungerCharge = 0.0;
  double _autoPlungeWait = 0.0;

  double _leftAngle = 0.42;
  double _rightAngle = math.pi - 0.42;
  double _upperLeftAngle = 0.48;
  double _leftAngVel = 0.0;
  double _rightAngVel = 0.0;
  double _upperLeftAngVel = 0.0;
  bool _prevLeftUp = false;
  bool _prevRightUp = false;

  double spinnerAngle = 0.0;
  double _spinnerVel = 0.0;
  double _nudgeCooldown = 0.0;
  Offset tableShake = Offset.zero;
  double jackpotBannerTimer = 0.0;
  String statusBanner = 'CRACK ALL 4 [H-U-L-L] TARGETS FOR MULTIBALL!';

  final List<WalnutPinball> balls = <WalnutPinball>[];
  final List<bool> rolloverLit = <bool>[false, false, false];
  final List<double> _rolloverCooldown = <double>[0.0, 0.0, 0.0];
  late final List<PinballBumper> bumpers;
  late final List<PinballDropTarget> dropTargets;
  late final List<_WallSeg> _walls;
  final List<PinballScorePopup> popups = <PinballScorePopup>[];

  double leftSlingFlash = 0.0;
  double rightSlingFlash = 0.0;
  double primeChuteFlash = 0.0;

  // Compatibility getters for single-ball inspection
  double get ballX => balls.isNotEmpty ? balls.first.x : 240.0;
  double get ballY => balls.isNotEmpty ? balls.first.y : 120.0;
  double get leftFlipperAngle => _leftAngle;
  double get rightFlipperAngle => _rightAngle;
  double get upperLeftFlipperAngle => _upperLeftAngle;
  bool get multiballActive => balls.length > 1;
  bool get hasBallWaitingInShooter =>
      balls.any((b) => b.inShooterLane && b.y > 540.0);

  void _initPlayfield() {
    bumpers = <PinballBumper>[
      PinballBumper(
        pos: const Offset(152, 204),
        radius: 23.0,
        basePoints: 120,
        color: const Color(0xFF9D4EDD),
        label: '120',
      ),
      PinballBumper(
        pos: const Offset(242, 174),
        radius: 25.0,
        basePoints: 180,
        color: const Color(0xFFFF006E),
        label: '180',
      ),
      PinballBumper(
        pos: const Offset(332, 204),
        radius: 23.0,
        basePoints: 120,
        color: const Color(0xFF3A86FF),
        label: '120',
      ),
      PinballBumper(
        pos: const Offset(194, 274),
        radius: 22.0,
        basePoints: 150,
        color: const Color(0xFFFFBE0B),
        label: '150',
      ),
      PinballBumper(
        pos: const Offset(290, 274),
        radius: 22.0,
        basePoints: 150,
        color: const Color(0xFF06D6A0),
        label: '150',
      ),
    ];

    dropTargets = <PinballDropTarget>[
      PinballDropTarget(
        a: const Offset(40, 220),
        b: const Offset(54, 266),
        letter: 'H',
      ),
      PinballDropTarget(
        a: const Offset(58, 276),
        b: const Offset(72, 322),
        letter: 'U',
      ),
      PinballDropTarget(
        a: const Offset(444, 220),
        b: const Offset(430, 266),
        letter: 'L',
      ),
      PinballDropTarget(
        a: const Offset(426, 276),
        b: const Offset(412, 322),
        letter: 'L',
      ),
    ];

    _walls = const <_WallSeg>[
      // Top curved arch guide segments (funnels shooter lane smoothly across top rollovers)
      _WallSeg(Offset(508, 120), Offset(492, 62), restitution: 0.82),
      _WallSeg(Offset(492, 62), Offset(452, 28), restitution: 0.82),
      _WallSeg(Offset(452, 28), Offset(370, 16), restitution: 0.80),
      _WallSeg(Offset(114, 16), Offset(42, 48), restitution: 0.78),
      _WallSeg(Offset(42, 48), Offset(20, 108), restitution: 0.78),

      // Top rollover lane dividers (N · U · T)
      _WallSeg(Offset(210, 68), Offset(210, 106), restitution: 0.65),
      _WallSeg(Offset(274, 68), Offset(274, 106), restitution: 0.65),

      // Left & right outer guide rails & inlane funnels to flippers
      _WallSeg(Offset(20, 440), Offset(20, 565), restitution: 0.65),
      _WallSeg(Offset(56, 456), Offset(56, 536), restitution: 0.65),
      _WallSeg(Offset(56, 536), Offset(144, 594), restitution: 0.55),

      _WallSeg(Offset(428, 456), Offset(428, 536), restitution: 0.65),
      _WallSeg(Offset(428, 536), Offset(340, 594), restitution: 0.55),

      // Outer bottom apron funnels toward drain (outside inlanes)
      _WallSeg(Offset(20, 565), Offset(132, 650), restitution: 0.55),
      _WallSeg(Offset(464, 565), Offset(352, 650), restitution: 0.55),

      // Left Slingshot triangle
      _WallSeg(Offset(86, 456), Offset(86, 528), restitution: 0.70),
      _WallSeg(Offset(86, 528), Offset(144, 562), restitution: 0.70),
      _WallSeg(
        Offset(86, 456),
        Offset(144, 562),
        restitution: 1.35,
        isSlingshot: true,
      ),

      // Right Slingshot triangle
      _WallSeg(Offset(398, 456), Offset(398, 528), restitution: 0.70),
      _WallSeg(Offset(398, 528), Offset(340, 562), restitution: 0.70),
      _WallSeg(
        Offset(398, 456),
        Offset(340, 562),
        restitution: 1.35,
        isSlingshot: true,
      ),
    ];
  }

  /// Instant spring-plunger launch (for tap/Space press or UI button).
  String? launchPlunger({double minPower = 0.82}) {
    var launched = false;
    final power = math.max(plungerCharge, minPower).clamp(0.45, 1.0);
    for (final b in balls) {
      if (b.inShooterLane && b.y > 500.0) {
        b.vy = -(760.0 + power * 230.0);
        b.vx = -12.0;
        b.spinVel = -16.0;
        launched = true;
      }
    }
    plungerHeld = false;
    plungerCharge = 0.0;
    if (launched) {
      statusBanner = 'SKILL SHOT! AIM FOR THE GLOWING ROLLOVER LANES!';
      return 'flipper';
    }
    return null;
  }

  /// Gentle zero-tilt table bump (`W` / `ArrowUp`).
  void nudgeTable() {
    if (_nudgeCooldown > 0.0) return;
    _nudgeCooldown = 0.65;
    tableShake = const Offset(4.5, -3.5);
    for (final b in balls) {
      if (!b.inShooterLane) {
        b.vy -= 68.0;
        b.vx += (b.x < 242.0 ? 52.0 : -52.0);
      }
    }
    statusBanner = 'ORCHARD TABLE NUDGE!';
  }

  void _rotateRolloverLanes({required bool right}) {
    if (right) {
      final last = rolloverLit[2];
      rolloverLit[2] = rolloverLit[1];
      rolloverLit[1] = rolloverLit[0];
      rolloverLit[0] = last;
    } else {
      final first = rolloverLit[0];
      rolloverLit[0] = rolloverLit[1];
      rolloverLit[1] = rolloverLit[2];
      rolloverLit[2] = first;
    }
  }

  /// Advances physics by `dt` seconds; returns `'bumper'`, `'chute'`, `'flipper'`, or `null`.
  String? step(double dt) {
    String? primaryEvent;
    final clampedDt = dt.clamp(0.0, 0.04);
    if (clampedDt <= 0.0) return null;

    // Decay visual flashes & popups
    for (final b in bumpers) {
      b.flash = math.max(0.0, b.flash - clampedDt * 4.2);
    }
    for (final t in dropTargets) {
      t.flash = math.max(0.0, t.flash - clampedDt * 3.5);
    }
    for (var i = 0; i < 3; i++) {
      _rolloverCooldown[i] = math.max(0.0, _rolloverCooldown[i] - clampedDt);
    }
    leftSlingFlash = math.max(0.0, leftSlingFlash - clampedDt * 5.0);
    rightSlingFlash = math.max(0.0, rightSlingFlash - clampedDt * 5.0);
    primeChuteFlash = math.max(0.0, primeChuteFlash - clampedDt * 2.8);
    kickbackFlash = math.max(0.0, kickbackFlash - clampedDt * 3.0);
    jackpotBannerTimer = math.max(0.0, jackpotBannerTimer - clampedDt);
    _nudgeCooldown = math.max(0.0, _nudgeCooldown - clampedDt);
    tableShake = Offset.lerp(tableShake, Offset.zero, (clampedDt * 18.0).clamp(0.0, 1.0))!;

    if (_spinnerVel.abs() > 0.2) {
      final prevTurns = (spinnerAngle / (math.pi * 2)).floor();
      spinnerAngle += _spinnerVel * clampedDt;
      final nextTurns = (spinnerAngle / (math.pi * 2)).floor();
      if (nextTurns != prevTurns) {
        score += 45 * combo;
      }
      _spinnerVel *= math.pow(0.28, clampedDt).toDouble();
    }

    for (final p in popups) {
      p.age += clampedDt;
      p.pos = p.pos.translate(0, -28.0 * clampedDt);
    }
    popups.removeWhere((p) => p.age >= PinballScorePopup.maxAge);

    // Auto-Groove AI assistant (automatically launches shooter & flips incoming walnuts!)
    if (autoGroove) {
      if (hasBallWaitingInShooter) {
        _autoPlungeWait += clampedDt;
        plungerCharge = (_autoPlungeWait / 0.32).clamp(0.0, 1.0);
        if (_autoPlungeWait >= 0.32) {
          _autoPlungeWait = 0.0;
          primaryEvent ??= launchPlunger(minPower: 0.92);
        }
      } else {
        _autoPlungeWait = 0.0;
      }

      var wantLeft = false;
      var wantRight = false;
      for (final b in balls) {
        if (b.inShooterLane) continue;
        if (b.vy > -20.0 && b.y > 515.0 && b.y < 622.0) {
          if (b.x >= 122.0 && b.x <= 252.0) wantLeft = true;
          if (b.x >= 232.0 && b.x <= 362.0) wantRight = true;
        }
        // Upper-left mini-flipper snipe
        if (b.vy > -10.0 && b.y > 350.0 && b.y < 430.0 && b.x < 132.0) {
          wantLeft = true;
        }
      }
      leftFlipperUp = wantLeft;
      rightFlipperUp = wantRight;
    } else if (plungerHeld && hasBallWaitingInShooter) {
      plungerCharge = (plungerCharge + clampedDt * 1.35).clamp(0.0, 1.0);
    }

    // Classic pinball lane-change on fresh flipper press!
    if (leftFlipperUp && !_prevLeftUp) {
      _rotateRolloverLanes(right: false);
      primaryEvent ??= 'flipper';
    }
    if (rightFlipperUp && !_prevRightUp) {
      _rotateRolloverLanes(right: true);
      primaryEvent ??= 'flipper';
    }
    _prevLeftUp = leftFlipperUp;
    _prevRightUp = rightFlipperUp;

    const subSteps = 4;
    final subDt = clampedDt / subSteps;

    for (var s = 0; s < subSteps; s++) {
      // Update flipper angles & angular velocities
      final targetL = leftFlipperUp ? -0.48 : 0.42;
      final targetR = rightFlipperUp ? (math.pi + 0.48) : (math.pi - 0.42);
      final targetUL = leftFlipperUp ? -0.36 : 0.48;

      final prevL = _leftAngle;
      final prevR = _rightAngle;
      final prevUL = _upperLeftAngle;

      final rateL = leftFlipperUp ? 34.0 : 20.0;
      final rateR = rightFlipperUp ? 34.0 : 20.0;
      _leftAngle += (targetL - _leftAngle) * (subDt * rateL).clamp(0.0, 1.0);
      _rightAngle += (targetR - _rightAngle) * (subDt * rateR).clamp(0.0, 1.0);
      _upperLeftAngle +=
          (targetUL - _upperLeftAngle) * (subDt * rateL).clamp(0.0, 1.0);

      _leftAngVel = (_leftAngle - prevL) / subDt;
      _rightAngVel = (_rightAngle - prevR) / subDt;
      _upperLeftAngVel = (_upperLeftAngle - prevUL) / subDt;

      final stepBalls = List<WalnutPinball>.of(balls);
      for (final ball in stepBalls) {
        // Gravity (realistic tilted pinball playfield)
        ball.vy += 430.0 * subDt;
        ball.x += ball.vx * subDt;
        ball.y += ball.vy * subDt;
        ball.spinAngle += ball.spinVel * subDt;
        ball.spinVel += (ball.vx * 0.018) * subDt;
        ball.spinVel = ball.spinVel.clamp(-24.0, 24.0);

        if (s == 0) {
          ball.trail.add(Offset(ball.x, ball.y));
          if (ball.trail.length > 7) {
            ball.trail.removeAt(0);
          }
        }

        // Shooter lane handling
        if (ball.inShooterLane) {
          // Plunger rest floor
          final plungerTopY = 626.0 + plungerCharge * 22.0;
          if (ball.y > plungerTopY - ballRadius) {
            ball.y = plungerTopY - ballRadius;
            if (ball.vy > 0) ball.vy = 0.0;
            ball.vx = 0.0;
            ball.spinVel = 0.0;
          }
          if (ball.x > boardW - 14.0 - ballRadius) {
            ball.x = boardW - 14.0 - ballRadius;
            ball.vx = -ball.vx.abs() * 0.75;
          }
          if (ball.y > 124.0 && ball.x < 472.0 + ballRadius) {
            ball.x = 472.0 + ballRadius;
            ball.vx = ball.vx.abs() * 0.75;
          }
          // Exited top of shooter chute into main upper arch!
          if (ball.x < 454.0) {
            ball.inShooterLane = false;
            if (ball.vx > -140.0) ball.vx = -220.0;
          }
        } else {
          // Outer playfield bounds (main playfield x: 20 .. 464)
          if (ball.x < 20.0 + ballRadius) {
            ball.x = 20.0 + ballRadius;
            ball.vx = ball.vx.abs() * 0.78;
          } else if (ball.x > mainAreaRight - ballRadius) {
            ball.x = mainAreaRight - ballRadius;
            ball.vx = -ball.vx.abs() * 0.78;
          }
          if (ball.y < 18.0 + ballRadius) {
            // Check Top Prime Harvest Jackpot Chute (x: 198..286, y < 38)
            if (ball.x >= 198.0 && ball.x <= 286.0) {
              primeGradeCount++;
              final pts = 500 * combo;
              score += pts;
              combo = (combo + 1).clamp(1, 8);
              primeChuteFlash = 1.0;
              kickbackLit = true;
              statusBanner =
                  'PRIME HARVEST CHUTE! +$pts PTS (COMBO x$combo)';
              popups.add(
                PinballScorePopup(
                  pos: Offset(ball.x, 54.0),
                  text: 'PRIME +$pts!',
                  color: const Color(0xFF80FFDB),
                ),
              );
              // Eject cleanly toward bumpers
              ball.y = 54.0;
              ball.vy = 235.0;
              ball.vx = ((score % 2 == 0) ? 1.0 : -1.0) * 125.0;
              ball.isRockHazard = false;
              primaryEvent = 'chute';
            } else {
              ball.y = 18.0 + ballRadius;
              ball.vy = ball.vy.abs() * 0.78;
            }
          }

          // Top 3 Rollover Sensors (N · U · T at x = 178, 242, 306, y ~ 86)
          const laneXs = <double>[178.0, 242.0, 306.0];
          for (var i = 0; i < 3; i++) {
            if (_rolloverCooldown[i] <= 0.0 &&
                (ball.x - laneXs[i]).abs() < 20.0 &&
                (ball.y - 86.0).abs() < 16.0) {
              _rolloverCooldown[i] = 0.6;
              rolloverLit[i] = true;
              score += 110 * combo;
              if (rolloverLit[0] && rolloverLit[1] && rolloverLit[2]) {
                combo = (combo + 1).clamp(1, 8);
                final bonus = 600 * combo;
                score += bonus;
                rolloverLit[0] = false;
                rolloverLit[1] = false;
                rolloverLit[2] = false;
                statusBanner =
                    'N-U-T ROLLOVER COMPLETE! BONUS +$bonus · COMBO x$combo!';
                popups.add(
                  PinballScorePopup(
                    pos: const Offset(242, 92),
                    text: 'x$combo BONUS!',
                    color: const Color(0xFFFFBE0B),
                  ),
                );
                primaryEvent = 'chute';
              }
            }
          }

          // Whirling Hull-Spinner sensor at (104, 342)
          if ((ball.x - 104.0).abs() < 22.0 && (ball.y - 342.0).abs() < 14.0) {
            if (ball.vy.abs() > 60.0) {
              _spinnerVel = (ball.vy.abs() * 0.095).clamp(10.0, 42.0);
            }
          }

          // Left Outlane Optical Air-Jet Kickback Save!
          if (kickbackLit &&
              ball.x < 54.0 &&
              ball.y > 532.0 &&
              ball.y < 566.0 &&
              ball.vy > 0) {
            kickbackLit = false;
            kickbackFlash = 1.0;
            ball.y = 526.0;
            ball.vy = -660.0;
            ball.vx = 135.0;
            score += 200 * combo;
            statusBanner = 'OPTICAL AIR-JET BALL SAVE!';
            popups.add(
              PinballScorePopup(
                pos: const Offset(48, 520),
                text: 'AIR SAVE!',
                color: const Color(0xFF4CC9F0),
              ),
            );
            primaryEvent = 'flipper';
          }
        }

        // Static walls & diagonal slingshots
        for (final w in _walls) {
          if (ball.inShooterLane && w.a.dx < 450.0 && w.b.dx < 450.0) continue;
          if (_collideSegment(
            ball: ball,
            a: w.a,
            b: w.b,
            thickness: 3.5,
            restitution: w.restitution,
            extraImpulse: w.isSlingshot ? 255.0 : 0.0,
          )) {
            if (w.isSlingshot) {
              final pts = 95 * combo;
              score += pts;
              if (w.a.dx < 240.0) {
                leftSlingFlash = 1.0;
              } else {
                rightSlingFlash = 1.0;
              }
              primaryEvent ??= 'bumper';
            }
          }
        }

        if (!ball.inShooterLane) {
          // 5 Optical Sorter Pop Bumpers
          for (final b in bumpers) {
            final dx = ball.x - b.pos.dx;
            final dy = ball.y - b.pos.dy;
            final dist = math.sqrt(dx * dx + dy * dy);
            final minDist = b.radius + ballRadius;
            if (dist < minDist && dist > 0.0001) {
              final nx = dx / dist;
              final ny = dy / dist;
              ball.x = b.pos.dx + nx * (minDist + 0.8);
              ball.y = b.pos.dy + ny * (minDist + 0.8);
              const kickSpeed = 375.0;
              ball.vx = nx * kickSpeed;
              ball.vy = ny * kickSpeed;
              ball.spinVel = (nx * 18.0).clamp(-22.0, 22.0);
              b.flash = 1.0;
              final pts = b.basePoints * combo;
              score += pts;
              popups.add(
                PinballScorePopup(
                  pos: b.pos.translate(0, -18),
                  text: '+$pts',
                  color: b.color,
                ),
              );
              primaryEvent = 'bumper';
            }
          }

          // 4 H-U-L-L Drop Targets -> Unlock Multiball!
          for (final t in dropTargets) {
            if (t.isDown) continue;
            if (_collideSegment(
              ball: ball,
              a: t.a,
              b: t.b,
              thickness: 6.0,
              restitution: 0.92,
              extraImpulse: 90.0,
            )) {
              t.isDown = true;
              t.flash = 1.0;
              final pts = 250 * combo;
              score += pts;
              popups.add(
                PinballScorePopup(
                  pos: t.center,
                  text: '${t.letter} +$pts',
                  color: const Color(0xFFFFD166),
                ),
              );
              primaryEvent = 'bumper';

              if (dropTargets.every((dt) => dt.isDown)) {
                _triggerHullMultiball();
                primaryEvent = 'chute';
              }
            }
          }

          // 3 Swept Capsule Flippers (Main Left, Main Right, Upper-Left Cross-Shot)
          if (_collideFlipper(
            ball: ball,
            pivot: const Offset(152, 598),
            length: 82.0,
            angle: _leftAngle,
            angVel: _leftAngVel,
            isActiveUp: leftFlipperUp,
          )) {
            if (ball.isRockHazard && leftFlipperUp) {
              ball.isRockHazard = false;
              score += 200;
            }
            primaryEvent ??= 'flipper';
          }
          if (_collideFlipper(
            ball: ball,
            pivot: const Offset(332, 598),
            length: 82.0,
            angle: _rightAngle,
            angVel: _rightAngVel,
            isActiveUp: rightFlipperUp,
          )) {
            if (ball.isRockHazard && rightFlipperUp) {
              ball.isRockHazard = false;
              score += 200;
            }
            primaryEvent ??= 'flipper';
          }
          if (_collideFlipper(
            ball: ball,
            pivot: const Offset(56, 388),
            length: 56.0,
            angle: _upperLeftAngle,
            angVel: _upperLeftAngVel,
            isActiveUp: leftFlipperUp,
          )) {
            primaryEvent ??= 'flipper';
          }

          // Anti-stall safeguard
          final spd = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy);
          final cradled =
              (leftFlipperUp || rightFlipperUp) && ball.y > 540.0;
          if (spd < 18.0 && !cradled) {
            ball.stallTimer += subDt;
            if (ball.stallTimer > 1.2) {
              ball.stallTimer = 0.0;
              ball.vy = -180.0;
              ball.vx = (ball.x < 242.0 ? 95.0 : -95.0);
            }
          } else {
            ball.stallTimer = 0.0;
          }
        }

        // Clamp max ball speed for crisp visual tracking
        final speed = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy);
        if (speed > 860.0) {
          final scale = 860.0 / speed;
          ball.vx *= scale;
          ball.vy *= scale;
        }
      }
    }

    // Drain handling: remove drained multiballs, or re-serve fresh walnut in shooter lane!
    balls.removeWhere((b) => !b.inShooterLane && b.y > boardH + 22.0);
    if (balls.isEmpty) {
      combo = 1;
      kickbackLit = true;
      balls.add(
        WalnutPinball(
          x: shooterLaneCenterX,
          y: 606.0,
          vx: 0.0,
          vy: 0.0,
          inShooterLane: true,
          isRockHazard: primeGradeCount > 0 && (primeGradeCount % 4 == 0),
        ),
      );
      statusBanner = autoGroove
          ? 'AUTO-GROOVE RE-SERVING FRESH WALNUT...'
          : 'WALNUT READY! PRESS [SPACE] OR TAP LAUNCH!';
    }

    return primaryEvent;
  }

  void _triggerHullMultiball() {
    multiballCount++;
    final bonus = 1000 * combo;
    score += bonus;
    combo = (combo + 1).clamp(1, 8);
    jackpotBannerTimer = 3.2;
    kickbackLit = true;
    statusBanner = 'WALNUT MULTIBALL JACKPOT! +$bonus PTS!';
    popups.add(
      PinballScorePopup(
        pos: const Offset(242, 330),
        text: 'MULTIBALL +$bonus!',
        color: const Color(0xFFFF006E),
      ),
    );
    for (final t in dropTargets) {
      t.isDown = false;
      t.flash = 1.0;
    }
    if (balls.length < 3) {
      balls.add(
        WalnutPinball(
          x: 242.0,
          y: 66.0,
          vx: -145.0,
          vy: 80.0,
          inShooterLane: false,
        ),
      );
    }
  }

  bool _collideSegment({
    required WalnutPinball ball,
    required Offset a,
    required Offset b,
    required double thickness,
    required double restitution,
    double extraImpulse = 0.0,
  }) {
    final abx = b.dx - a.dx;
    final aby = b.dy - a.dy;
    final lenSq = abx * abx + aby * aby;
    if (lenSq < 0.0001) return false;

    final t = (((ball.x - a.dx) * abx + (ball.y - a.dy) * aby) / lenSq)
        .clamp(0.0, 1.0);
    final cx = a.dx + abx * t;
    final cy = a.dy + aby * t;
    final dx = ball.x - cx;
    final dy = ball.y - cy;
    final dist = math.sqrt(dx * dx + dy * dy);
    final minDist = ballRadius + thickness;
    if (dist >= minDist || dist < 0.0001) return false;

    final nx = dx / dist;
    final ny = dy / dist;
    ball.x = cx + nx * (minDist + 0.4);
    ball.y = cy + ny * (minDist + 0.4);

    final vn = ball.vx * nx + ball.vy * ny;
    if (vn < 0.0) {
      ball.vx -= (1.0 + restitution) * vn * nx;
      ball.vy -= (1.0 + restitution) * vn * ny;
    }
    if (extraImpulse > 0.0) {
      ball.vx += nx * extraImpulse;
      ball.vy += ny * extraImpulse;
    }
    return true;
  }

  bool _collideFlipper({
    required WalnutPinball ball,
    required Offset pivot,
    required double length,
    required double angle,
    required double angVel,
    required bool isActiveUp,
  }) {
    final tip = Offset(
      pivot.dx + math.cos(angle) * length,
      pivot.dy + math.sin(angle) * length,
    );
    final abx = tip.dx - pivot.dx;
    final aby = tip.dy - pivot.dy;
    final lenSq = abx * abx + aby * aby;
    final t = (((ball.x - pivot.dx) * abx + (ball.y - pivot.dy) * aby) / lenSq)
        .clamp(0.0, 1.0);
    final cx = pivot.dx + abx * t;
    final cy = pivot.dy + aby * t;
    final dx = ball.x - cx;
    final dy = ball.y - cy;
    final dist = math.sqrt(dx * dx + dy * dy);
    final batRadius = ui.lerpDouble(8.5, 5.5, t)!;
    final minDist = ballRadius + batRadius;
    if (dist >= minDist || dist < 0.0001) return false;

    final nx = dx / dist;
    final ny = dy / dist;
    ball.x = cx + nx * (minDist + 0.6);
    ball.y = cy + ny * (minDist + 0.6);

    // Tangential velocity of flipper contact point due to angular swing
    final rx = cx - pivot.dx;
    final ry = cy - pivot.dy;
    final surfVx = -angVel * ry;
    final surfVy = angVel * rx;

    final relVx = ball.vx - surfVx;
    final relVy = ball.vy - surfVy;
    final relVn = relVx * nx + relVy * ny;

    if (relVn < 0.0) {
      const bounce = 0.58;
      ball.vx -= (1.0 + bounce) * relVn * nx;
      ball.vy -= (1.0 + bounce) * relVn * ny;
    }

    // Active upward snap kick (gives crisp controllable arcade shots!)
    final swingingUp =
        isActiveUp && angVel.abs() > 1.8 && ny < -0.15;
    if (swingingUp) {
      final power = 520.0 + t * 185.0;
      final aimX = (ball.x - pivot.dx) / length;
      ball.vy = math.min(ball.vy, -power);
      ball.vx = aimX * 340.0 + surfVx * 0.25;
      ball.spinVel = aimX * 20.0;
    }
    return swingingUp || relVn < -45.0;
  }
}

class SortingPinballOverlay extends ConsumerStatefulWidget {
  const SortingPinballOverlay({
    super.key,
    required this.audio,
  });

  final SoloudAudioService audio;

  @override
  ConsumerState<SortingPinballOverlay> createState() =>
      _SortingPinballOverlayState();
}

class _SortingPinballOverlayState extends ConsumerState<SortingPinballOverlay>
    with SingleTickerProviderStateMixin {
  late final PinballSimulation _sim;
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  final FocusNode _focusNode = FocusNode(debugLabel: 'SortingPinballFocus');

  bool _pointerLeftDown = false;
  bool _pointerRightDown = false;
  bool _pointerPlungerDown = false;
  ui.Image? _walnutBallImage;

  static final Set<LogicalKeyboardKey> _leftKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.keyZ,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.comma,
  };

  static final Set<LogicalKeyboardKey> _rightKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.keyM,
    LogicalKeyboardKey.slash,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.period,
  };

  static final Set<LogicalKeyboardKey> _plungerKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.keyS,
  };

  @override
  void initState() {
    super.initState();
    final pureVibe = ref.read(festivalClockProvider).pureVibeMode;
    _sim = PinballSimulation(autoGroove: pureVibe);
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
    _loadWalnutSprite();
    _ticker = createTicker(_onTick)..start();
  }

  Future<void> _loadWalnutSprite() async {
    try {
      final bytes =
          await rootBundle.load('assets/images/props/walnut_pinball.png');
      final codec =
          await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() => _walnutBallImage = frame.image);
      }
    } catch (_) {
      // Procedural 3D grooved walnut shell fallback renders automatically
    }
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (!mounted) return false;
    final key = event.logicalKey;
    final isDown = event is KeyDownEvent || event is KeyRepeatEvent;

    if (event is KeyDownEvent && key == LogicalKeyboardKey.escape) {
      _closeModal();
      return true;
    }

    if (_leftKeys.contains(key)) {
      if (_sim.autoGroove && isDown) _sim.autoGroove = false;
      _sim.leftFlipperUp = isDown || _pointerLeftDown;
      return true;
    }

    if (_rightKeys.contains(key)) {
      if (_sim.autoGroove && isDown) _sim.autoGroove = false;
      _sim.rightFlipperUp = isDown || _pointerRightDown;
      return true;
    }

    if (_plungerKeys.contains(key)) {
      if (_sim.autoGroove && isDown) _sim.autoGroove = false;
      if (isDown) {
        _sim.plungerHeld = true;
      } else if (event is KeyUpEvent) {
        final ev = _sim.launchPlunger(
          minPower: _sim.plungerCharge > 0.15 ? _sim.plungerCharge : 0.88,
        );
        if (ev != null) _playEventSfx(ev);
      }
      return true;
    }

    if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.keyW ||
            key == LogicalKeyboardKey.arrowUp)) {
      _sim.nudgeTable();
      return true;
    }

    return false;
  }

  void _syncHeldKeysFromHardware() {
    if (_sim.autoGroove) return;
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final hwLeft = pressed.any(_leftKeys.contains);
    final hwRight = pressed.any(_rightKeys.contains);
    final hwPlunge = pressed.any(_plungerKeys.contains);
    _sim.leftFlipperUp = hwLeft || _pointerLeftDown;
    _sim.rightFlipperUp = hwRight || _pointerRightDown;
    if (hwPlunge || _pointerPlungerDown) {
      _sim.plungerHeld = true;
    }
  }

  void _playEventSfx(String ev) {
    if (ev == 'bumper' || ev == 'chute') {
      unawaited(
        widget.audio
            .playSfx('assets/audio/sfx/sfx_pinball_bumper.wav', volume: 0.46),
      );
      ref.read(worldFlagsProvider.notifier).recordPinballScore(_sim.score);
    } else if (ev == 'flipper') {
      unawaited(
        widget.audio
            .playSfx('assets/audio/sfx/sfx_pinball_flipper.wav', volume: 0.36),
      );
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _lastElapsed == Duration.zero
        ? 0.016
        : (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    _syncHeldKeysFromHardware();
    final ev = _sim.step(dt);
    if (ev != null) {
      _playEventSfx(ev);
    }
    if (mounted) setState(() {});
  }

  void _closeModal() {
    ref.read(worldFlagsProvider.notifier).recordPinballScore(_sim.score);
    ref.read(uiOverlayProvider.notifier).closeModal();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highScore =
        math.max(ref.watch(worldFlagsProvider).pinballHighScore, _sim.score);
    final screen = MediaQuery.sizeOf(context);
    final availW = math.max(260.0, screen.width - 16.0);
    final availH = math.max(240.0, screen.height - 16.0);
    final modalW = math.min(820.0, availW);
    final modalH = math.min(620.0, availH);
    final isWide = modalW >= 580.0 && modalH >= 320.0;
    final isShort = modalH < 440.0;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      child: Center(
        child: Container(
          key: const ValueKey('pinball_wizard_modal'),
          width: modalW,
          height: modalH,
          padding: EdgeInsets.all(isShort ? 10 : 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFA1B0F2E),
                Color(0xFA10091D),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFBE0B), width: 2.4),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Colors.black87, blurRadius: 28),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: <Widget>[
                // Top Arcade Cabinet Marquee Header
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        '🌰 PINBALL WIZARD · WALNUT CRACKER DELUXE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFFFFBE0B),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    FilterChip(
                      key: const ValueKey('pinball_autogroove_toggle'),
                      visualDensity: VisualDensity.compact,
                      label: const Text(
                        'Auto-Groove',
                        style: TextStyle(fontSize: 11),
                      ),
                      selected: _sim.autoGroove,
                      selectedColor: const Color(0xFF52B788),
                      onSelected: (v) => setState(() => _sim.autoGroove = v),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      key: const ValueKey('close_pinball_button'),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, color: Color(0xFFF4E3C1)),
                      onPressed: _closeModal,
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Main Playfield + Side Backglass Scoreboard (responsive)
                Expanded(
                  child: isWide
                      ? Row(
                          children: <Widget>[
                            Expanded(
                              flex: 6,
                              child: _buildPlayfieldCanvas(),
                            ),
                            const SizedBox(width: 14),
                            SizedBox(
                              width: 248,
                              child: _buildSideScoreboardAndControls(highScore),
                            ),
                          ],
                        )
                      : Column(
                          children: <Widget>[
                            _buildCompactScoreStrip(highScore),
                            const SizedBox(height: 6),
                            Expanded(child: _buildPlayfieldCanvas()),
                            const SizedBox(height: 8),
                            _buildBottomTouchControls(),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayfieldCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (ev) {
            _focusNode.requestFocus();
            final relX = ev.localPosition.dx / math.max(1.0, constraints.maxWidth);
            if (_sim.hasBallWaitingInShooter && relX > 0.78) {
              _pointerPlungerDown = true;
              _sim.autoGroove = false;
              _sim.plungerHeld = true;
            } else if (relX < 0.5) {
              _pointerLeftDown = true;
              _sim.autoGroove = false;
              _sim.leftFlipperUp = true;
            } else {
              _pointerRightDown = true;
              _sim.autoGroove = false;
              _sim.rightFlipperUp = true;
            }
          },
          onPointerUp: (_) {
            if (_pointerPlungerDown) {
              _pointerPlungerDown = false;
              final ev = _sim.launchPlunger(minPower: 0.88);
              if (ev != null) _playEventSfx(ev);
            }
            _pointerLeftDown = false;
            _pointerRightDown = false;
            _sim.leftFlipperUp = false;
            _sim.rightFlipperUp = false;
          },
          onPointerCancel: (_) {
            _pointerPlungerDown = false;
            _pointerLeftDown = false;
            _pointerRightDown = false;
            _sim.leftFlipperUp = false;
            _sim.rightFlipperUp = false;
          },
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: Transform.translate(
                offset: _sim.tableShake,
                child: SizedBox(
                  width: PinballSimulation.boardW,
                  height: PinballSimulation.boardH,
                  child: CustomPaint(
                    painter: _PinballBoardPainter(
                      sim: _sim,
                      walnutImage: _walnutBallImage,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSideScoreboardAndControls(int highScore) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Neon Backglass LED Readout
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF140B24),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: const Color(0xFF9D4EDD), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'SCORE',
                        style: TextStyle(
                          color: Color(0xFFB7A99A),
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        '${_sim.score}',
                        style: const TextStyle(
                          color: Color(0xFF80FFDB),
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          _statBadge(
                              'COMBO', 'x${_sim.combo}', const Color(0xFFFFBE0B)),
                          _statBadge('PRIME', '${_sim.primeGradeCount}',
                              const Color(0xFF06D6A0)),
                          _statBadge('WALNUTS', '${_sim.balls.length}',
                              const Color(0xFFFF006E)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'HIGH SCORE: $highScore',
                        style: const TextStyle(
                          color: Color(0xFFF4E3C1),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Live Marquee Callout Box
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: _sim.jackpotBannerTimer > 0
                        ? const Color(0xFF5A1042)
                        : const Color(0xFF1D1333),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _sim.jackpotBannerTimer > 0
                          ? const Color(0xFFFF006E)
                          : const Color(0xFF4CC9F0),
                    ),
                  ),
                  child: Text(
                    _sim.statusBanner,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFFFF8E7),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Keyboard Legend Card
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171026),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF3C2A56)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'ARCADE CONTROLS',
                        style: TextStyle(
                          color: Color(0xFFFFBE0B),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Left Flipper: [A] / [←] / [Z] / [L-Shift]\n'
                        '• Right Flipper: [D] / [→] / [/] / [R-Shift]\n'
                        '• Spring Plunger: [SPACE] / [↓] / [ENTER]\n'
                        '• Nudge Table: [W] / [↑] · Click Board!',
                        style: TextStyle(
                          color: Color(0xFFD9C5A0),
                          fontSize: 10.5,
                          height: 1.32,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Spring Plunger Launch Button
        Listener(
          key: const ValueKey('pinball_plunger_btn'),
          onPointerDown: (_) {
            _focusNode.requestFocus();
            _pointerPlungerDown = true;
            _sim.autoGroove = false;
            _sim.plungerHeld = true;
          },
          onPointerUp: (_) {
            _pointerPlungerDown = false;
            final ev = _sim.launchPlunger(
              minPower: _sim.plungerCharge > 0.15 ? _sim.plungerCharge : 0.90,
            );
            if (ev != null) _playEventSfx(ev);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _sim.hasBallWaitingInShooter
                    ? const <Color>[Color(0xFFFF006E), Color(0xFFFF9F1C)]
                    : const <Color>[Color(0xFF3A2449), Color(0xFF2B1B38)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFBE0B), width: 1.5),
            ),
            child: Text(
              _sim.hasBallWaitingInShooter
                  ? '🚀 LAUNCH WALNUT [SPACE]'
                  : 'SPRING SHOOTER READY [SPACE]',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 11.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildBottomTouchControls(),
      ],
    );
  }

  Widget _statBadge(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(color: Color(0xFFB7A99A), fontSize: 9.5),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactScoreStrip(int highScore) {
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: <Widget>[
        Text(
          'SCORE: ${_sim.score}',
          style: const TextStyle(
            color: Color(0xFF80FFDB),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          'COMBO: x${_sim.combo}',
          style: const TextStyle(
            color: Color(0xFFFFBE0B),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          'PRIME: ${_sim.primeGradeCount} · BEST: $highScore',
          style: const TextStyle(color: Color(0xFFF4E3C1), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildBottomTouchControls() {
    return Row(
      children: <Widget>[
        Expanded(
          child: Listener(
            key: const ValueKey('pinball_left_flipper_btn'),
            onPointerDown: (_) {
              _focusNode.requestFocus();
              _pointerLeftDown = true;
              _sim.autoGroove = false;
              _sim.leftFlipperUp = true;
            },
            onPointerUp: (_) {
              _pointerLeftDown = false;
              _sim.leftFlipperUp = false;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _sim.leftFlipperUp
                    ? const Color(0xFF7209B7)
                    : const Color(0xFF3A0CA3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF4CC9F0), width: 1.5),
              ),
              child: const Text(
                '◀ LEFT [A / ←]',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                ),
              ),
            ),
          ),
        ),
        if (_sim.hasBallWaitingInShooter) ...<Widget>[
          const SizedBox(width: 6),
          Listener(
            onPointerDown: (_) {
              _focusNode.requestFocus();
              _sim.autoGroove = false;
              final ev = _sim.launchPlunger(minPower: 0.92);
              if (ev != null) _playEventSfx(ev);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFF006E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFBE0B)),
              ),
              child: const Text(
                'LAUNCH',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(width: 8),
        Expanded(
          child: Listener(
            key: const ValueKey('pinball_right_flipper_btn'),
            onPointerDown: (_) {
              _focusNode.requestFocus();
              _pointerRightDown = true;
              _sim.autoGroove = false;
              _sim.rightFlipperUp = true;
            },
            onPointerUp: (_) {
              _pointerRightDown = false;
              _sim.rightFlipperUp = false;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _sim.rightFlipperUp
                    ? const Color(0xFF7209B7)
                    : const Color(0xFF3A0CA3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF4CC9F0), width: 1.5),
              ),
              child: const Text(
                'RIGHT [D / →] ▶',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PinballBoardPainter extends CustomPainter {
  const _PinballBoardPainter({
    required this.sim,
    this.walnutImage,
  });

  final PinballSimulation sim;
  final ui.Image? walnutImage;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));
    canvas.save();
    canvas.clipRRect(rrect);

    // 1. Rich Woodstock Lacquered Walnut-Wood & Cosmic Indigo Playfield
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF190E33),
            Color(0xFF120924),
            Color(0xFF21112B),
          ],
        ).createShader(rect),
    );

    // Subtle concentric orchard mandala playfield inlay
    final inlayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0x22FFB703);
    for (final r in const <double>[68.0, 112.0, 156.0]) {
      canvas.drawCircle(const Offset(242, 345), r, inlayPaint);
    }
    _drawLabel(
      canvas,
      text: 'WALNUTSTOCK \'69\nOPTICAL SORTER',
      center: const Offset(242, 355),
      fontSize: 14,
      color: const Color(0x38FFD166),
    );

    // 2. Shooter Lane Channel & Brass Spring Plunger (`x: 468..512`)
    canvas.drawRect(
      const Rect.fromLTWH(468, 120, 44, 552),
      Paint()..color = const Color(0xFF0D061A),
    );
    canvas.drawLine(
      const Offset(468, 124),
      const Offset(468, 668),
      Paint()
        ..color = const Color(0xFFD4A373)
        ..strokeWidth = 4.0,
    );

    // Coiled brass plunger spring & rubber tip
    final plungerTopY = 626.0 + sim.plungerCharge * 22.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(477, plungerTopY, 26, 9),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFFF006E),
    );
    final springPaint = Paint()
      ..color = const Color(0xFFFFBE0B)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 6; i++) {
      final sy = plungerTopY + 10.0 + i * ((668.0 - plungerTopY - 10.0) / 6.0);
      canvas.drawLine(Offset(479, sy), Offset(501, sy + 3), springPaint);
    }

    // 3. Top Prime Harvest Jackpot Chute (`x: 198..286`)
    final chuteCol = Color.lerp(
      const Color(0xFF06D6A0),
      const Color(0xFFFFFFFF),
      sim.primeChuteFlash,
    )!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(196, 8, 92, 28),
        const Radius.circular(10),
      ),
      Paint()..color = chuteCol.withValues(alpha: 0.28),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(196, 8, 92, 28),
        const Radius.circular(10),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..color = chuteCol,
    );
    _drawLabel(
      canvas,
      text: '★ PRIME CHUTE ★',
      center: const Offset(242, 22),
      fontSize: 9.5,
      color: const Color(0xFFFFF8E7),
    );

    // 4. Top 3 Rollover Lanes (N · U · T)
    const laneLetters = <String>['N', 'U', 'T'];
    const laneXs = <double>[178.0, 242.0, 306.0];
    for (var i = 0; i < 3; i++) {
      final lit = sim.rolloverLit[i];
      canvas.drawCircle(
        Offset(laneXs[i], 86),
        13,
        Paint()
          ..color = lit ? const Color(0xFFFFBE0B) : const Color(0xFF281942),
      );
      canvas.drawCircle(
        Offset(laneXs[i], 86),
        13,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = const Color(0xFFFFD166),
      );
      _drawLabel(
        canvas,
        text: laneLetters[i],
        center: Offset(laneXs[i], 86),
        fontSize: 11,
        color: lit ? const Color(0xFF190E33) : const Color(0xFFFFD166),
      );
    }
    for (final divX in const <double>[210.0, 274.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(divX, 87), width: 6, height: 38),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF4CC9F0),
      );
    }

    // 5. Whirling Hull Spinner on left orbit (`(104, 342)`)
    canvas.save();
    canvas.translate(104, 342);
    final spinW = (math.cos(sim.spinnerAngle).abs() * 26.0).clamp(3.0, 26.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: spinW, height: 8),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF80FFDB),
    );
    canvas.restore();

    // 6. Left Outlane Air-Jet Kickback Indicator (`x: 38, y: 552`)
    if (sim.kickbackLit || sim.kickbackFlash > 0.0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(25, 540, 26, 18),
          const Radius.circular(5),
        ),
        Paint()
          ..color = sim.kickbackFlash > 0
              ? const Color(0xFFFFFFFF)
              : const Color(0xCC06D6A0),
      );
      _drawLabel(
        canvas,
        text: 'SAVE',
        center: const Offset(38, 549),
        fontSize: 7.5,
        color: const Color(0xFF081C15),
      );
    }

    // 7. Chrome Guide Rails, Inlanes & Triangular Neon Slingshots
    final railPaint = Paint()
      ..color = const Color(0xFFB8C0FF)
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round;
    for (final w in sim._walls) {
      if (w.isSlingshot) continue;
      canvas.drawLine(w.a, w.b, railPaint);
    }

    _drawSlingshot(
      canvas,
      const Offset(86, 456),
      const Offset(86, 528),
      const Offset(144, 562),
      sim.leftSlingFlash,
    );
    _drawSlingshot(
      canvas,
      const Offset(398, 456),
      const Offset(398, 528),
      const Offset(340, 562),
      sim.rightSlingFlash,
    );

    // 8. 4 H-U-L-L Drop Targets
    for (final t in sim.dropTargets) {
      final p = Paint()
        ..strokeWidth = t.isDown ? 3.0 : 8.5
        ..strokeCap = StrokeCap.round
        ..color = t.isDown
            ? const Color(0x554CC9F0)
            : Color.lerp(
                const Color(0xFFFF9F1C),
                const Color(0xFFFFFFFF),
                t.flash,
              )!;
      canvas.drawLine(t.a, t.b, p);
      _drawLabel(
        canvas,
        text: t.letter,
        center: Offset(
          t.center.dx + (t.center.dx < 242 ? 15 : -15),
          t.center.dy,
        ),
        fontSize: 10,
        color: t.isDown ? const Color(0x66FFFFFF) : const Color(0xFFFFF3B0),
      );
    }

    // 9. 5 Optical Sorter Pop Bumpers (with animated shockwave halo!)
    for (final b in sim.bumpers) {
      final r = b.radius + b.flash * 4.5;
      if (b.flash > 0.05) {
        canvas.drawCircle(
          b.pos,
          r + 9.0 * b.flash,
          Paint()..color = b.color.withValues(alpha: 0.36 * b.flash),
        );
      }
      // 3D bumper base shadow
      canvas.drawCircle(
        b.pos.translate(2, 4),
        r,
        Paint()..color = const Color(0x8805020A),
      );
      canvas.drawCircle(
        b.pos,
        r,
        Paint()
          ..color = Color.lerp(b.color, const Color(0xFFFFFFFF), b.flash * 0.65)!,
      );
      canvas.drawCircle(
        b.pos,
        r * 0.72,
        Paint()..color = const Color(0xFF190E33),
      );
      canvas.drawCircle(
        b.pos,
        r * 0.56,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = const Color(0xFFFFF8E7),
      );
      _drawLabel(
        canvas,
        text: b.label,
        center: b.pos,
        fontSize: 9.5,
        color: const Color(0xFFFFF8E7),
      );
    }

    // 10. 3 Tapered Arcade Flippers (Left, Right, Upper-Left Cross-Shot)
    _drawFlipperBat(canvas, const Offset(152, 598), 82.0, sim.leftFlipperAngle);
    _drawFlipperBat(canvas, const Offset(332, 598), 82.0, sim.rightFlipperAngle);
    _drawFlipperBat(
        canvas, const Offset(56, 388), 56.0, sim.upperLeftFlipperAngle);

    // 11. Tumbling 3D Walnut Pinballs!
    for (final ball in sim.balls) {
      _drawWalnutPinball(canvas, ball);
    }

    // 12. Floating Score Popups
    for (final p in sim.popups) {
      final a = (1.0 - p.age / PinballScorePopup.maxAge).clamp(0.0, 1.0);
      _drawLabel(
        canvas,
        text: p.text,
        center: p.pos,
        fontSize: 12,
        color: p.color.withValues(alpha: a),
      );
    }

    // Outer brass cabinet bezel
    canvas.drawRRect(
      rrect.deflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = const Color(0xFFD4A373),
    );
    canvas.restore();
  }

  void _drawSlingshot(
      Canvas canvas, Offset a, Offset b, Offset c, double flash) {
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy)
      ..close();
    final col = Color.lerp(
      const Color(0xFF7209B7),
      const Color(0xFFFF006E),
      0.35 + flash * 0.65,
    )!;
    canvas.drawPath(path, Paint()..color = col.withValues(alpha: 0.45));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6 + flash * 2.0
        ..color = flash > 0.1 ? const Color(0xFFFFFFFF) : const Color(0xFF4CC9F0),
    );
  }

  void _drawFlipperBat(
      Canvas canvas, Offset pivot, double length, double angle) {
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angle);

    // Drop shadow
    final shadowPath = Path()
      ..moveTo(0, -6)
      ..lineTo(length, -3.5)
      ..arcToPoint(Offset(length, 7.5), radius: const Radius.circular(5.5))
      ..lineTo(0, 10)
      ..arcToPoint(const Offset(0, -6), radius: const Radius.circular(8))
      ..close();
    canvas.drawPath(shadowPath, Paint()..color = const Color(0x77000000));

    final path = Path()
      ..moveTo(0, -8)
      ..lineTo(length, -5)
      ..arcToPoint(Offset(length, 5), radius: const Radius.circular(5))
      ..lineTo(0, 8)
      ..arcToPoint(const Offset(0, -8), radius: const Radius.circular(8))
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFBE0B));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = const Color(0xFFFF006E),
    );
    canvas.drawCircle(Offset.zero, 4.2, Paint()..color = const Color(0xFF190E33));
    canvas.restore();
  }

  void _drawWalnutPinball(Canvas canvas, WalnutPinball ball) {
    // Motion comet trail
    for (var i = 0; i < ball.trail.length; i++) {
      final t = (i + 1) / (ball.trail.length + 1);
      canvas.drawCircle(
        ball.trail[i],
        PinballSimulation.ballRadius * 0.65 * t,
        Paint()
          ..color = (ball.isRockHazard
                  ? const Color(0xFFE63946)
                  : const Color(0xFFFFD166))
              .withValues(alpha: 0.22 * t),
      );
    }

    // Playfield 3D cast shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(ball.x + 3.5, ball.y + 5.0),
        width: PinballSimulation.ballRadius * 2.05,
        height: PinballSimulation.ballRadius * 1.65,
      ),
      Paint()..color = const Color(0x8805020A),
    );

    const r = PinballSimulation.ballRadius;
    canvas.save();
    canvas.translate(ball.x, ball.y);
    canvas.rotate(ball.spinAngle);

    if (walnutImage != null && !ball.isRockHazard) {
      final src = Rect.fromLTWH(
        0,
        0,
        walnutImage!.width.toDouble(),
        walnutImage!.height.toDouble(),
      );
      final dst = Rect.fromCircle(center: Offset.zero, radius: r * 1.12);
      canvas.drawImageRect(
        walnutImage!,
        src,
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      );
    } else if (ball.isRockHazard) {
      // Angular quarry stone ("Rock-in-a-Box" hazard!)
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()..color = const Color(0xFF6C757D),
      );
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = const Color(0xFFE63946),
      );
    } else {
      // Sculpted 3D English Walnut Shell (rotates with spinAngle!)
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: r * 2.08, height: r * 1.90),
        Paint()
          ..shader = ui.Gradient.radial(
            const Offset(-3.5, -3.5),
            r * 1.35,
            const <Color>[
              Color(0xFFF3D5A5),
              Color(0xFFC68B59),
              Color(0xFF6F4518),
            ],
            const <double>[0.0, 0.58, 1.0],
          ),
      );

      // Organic convoluted shell grooves
      final groovePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.35
        ..color = const Color(0xAA4A2C11);
      for (final side in const <double>[-1.0, 1.0]) {
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(0, side * 4.2), width: r * 1.4, height: 6.2),
          side > 0 ? 0.2 : math.pi + 0.2,
          math.pi - 0.4,
          false,
          groovePaint,
        );
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(0, side * 7.2), width: r * 0.95, height: 4.4),
          side > 0 ? 0.3 : math.pi + 0.3,
          math.pi - 0.6,
          false,
          groovePaint,
        );
      }

      // Raised woody central walnut suture ridge (equatorial seam)
      canvas.drawLine(
        const Offset(-r * 0.98, 0),
        const Offset(r * 0.98, 0),
        Paint()
          ..color = const Color(0xFF4A2C11)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        const Offset(-r * 0.92, -0.7),
        const Offset(r * 0.92, -0.7),
        Paint()
          ..color = const Color(0xFFF8E2BA)
          ..strokeWidth = 1.0,
      );

      // Outer woody shell rim
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: r * 2.06, height: r * 1.90),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFF3D220C),
      );
    }
    canvas.restore();

    // Non-rotating top-left arcade glass specular glint on the 3D walnut
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(ball.x - 4.2, ball.y - 4.6),
        width: 5.5,
        height: 3.4,
      ),
      Paint()..color = const Color(0x77FFF8E7),
    );
  }

  void _drawLabel(
    Canvas canvas, {
    required String text,
    required Offset center,
    required double fontSize,
    required Color color,
  }) {
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        maxLines: 2,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
      ),
    )
      ..pushStyle(
        ui.TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      )
      ..addText(text);
    final para = pb.build()
      ..layout(const ui.ParagraphConstraints(width: 220));
    canvas.drawParagraph(
      para,
      Offset(center.dx - 110.0, center.dy - para.height * 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant _PinballBoardPainter oldDelegate) => true;
}
