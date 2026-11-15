import 'dart:async';
import 'dart:math' as math;

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/walnutstock_game.dart';
import '../state/providers.dart';

/// Invisible full-canvas floating thumb joystick + direct tap-to-walk / tap-to-interact layer.
///
/// - Zero permanent D-pad or static rings on screen.
/// - Touching and dragging spawns a subtle translucent 1969 tie-dye & carved walnut
///   woodgrain origin ring directly under the thumb, fading to `opacity: 0` immediately on release.
/// - Quick taps (`<= 8px` travel) dispatch `game.handleCanvasTapAt(...)` for direct
///   tap-to-walk and tap-to-interact on gate kiosks, NPCs, cultivar trees, and stage signs.
class FloatingThumbJoystick extends ConsumerStatefulWidget {
  const FloatingThumbJoystick({
    super.key,
    required this.game,
    this.onUserActivity,
  });

  final WalnutstockGame game;
  final VoidCallback? onUserActivity;

  @override
  ConsumerState<FloatingThumbJoystick> createState() =>
      _FloatingThumbJoystickState();
}

class _FloatingThumbJoystickState extends ConsumerState<FloatingThumbJoystick>
    with SingleTickerProviderStateMixin {
  static const double _dragActivationPx = 8.0;
  static const double _deadzonePx = 4.5;
  static const double _maxRadiusPx = 46.0;

  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
    value: 0.0,
  );

  int? _activePointer;
  Offset _origin = Offset.zero;
  Offset _current = Offset.zero;
  bool _isDragging = false;

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    widget.onUserActivity?.call();
    unawaited(widget.game.audioService.unlockAndInitialize());
    if (_activePointer != null) return;

    _activePointer = event.pointer;
    _origin = event.localPosition;
    _current = event.localPosition;
    _isDragging = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    widget.onUserActivity?.call();

    final delta = event.localPosition - _origin;
    final dist = delta.distance;

    if (!_isDragging && dist > _dragActivationPx) {
      _isDragging = true;
      widget.game.player?.clearTapPath();
      _fadeController.value = 1.0;
    }

    if (_isDragging) {
      setState(() {
        _current = event.localPosition;
      });
      if (dist < _deadzonePx) {
        widget.game.inputController.setVirtualDpad(0, 0);
      } else {
        final mag = ((dist - _deadzonePx) / (_maxRadiusPx - _deadzonePx))
            .clamp(0.28, 1.0);
        final nx = (delta.dx / dist) * mag;
        final ny = (delta.dy / dist) * mag;
        widget.game.inputController.setVirtualDpad(nx, ny);
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    widget.onUserActivity?.call();
    final wasDragging = _isDragging;
    final tapPos = event.localPosition;

    _releaseStick();
    if (!wasDragging) {
      widget.game.handleCanvasTapAt(tapPos);
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _releaseStick();
  }

  void _releaseStick() {
    _activePointer = null;
    _isDragging = false;
    widget.game.inputController.setVirtualDpad(0, 0);
    _fadeController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final overlay = ref.watch(uiOverlayProvider);
    final journalOpen = ref.watch(journalStateProvider).isOpen;
    final blocked = overlay.isBlockingInput || journalOpen;

    if (blocked && (_activePointer != null || _fadeController.value > 0.0)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (_activePointer != null || _fadeController.value > 0.0)) {
          _releaseStick();
        }
      });
    }

    return IgnorePointer(
      ignoring: blocked,
      child: Listener(
        key: const ValueKey('floating_thumb_surface'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        child: AnimatedBuilder(
          animation: _fadeController,
          builder: (context, _) {
            final alpha = _fadeController.value;
            if (alpha <= 0.01) {
              return const SizedBox.expand();
            }
            return CustomPaint(
              key: const ValueKey('floating_thumb_ring'),
              size: Size.infinite,
              painter: _TieDyeWoodgrainStickPainter(
                origin: _origin,
                current: _current,
                maxRadius: _maxRadiusPx,
                opacity: alpha,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TieDyeWoodgrainStickPainter extends CustomPainter {
  const _TieDyeWoodgrainStickPainter({
    required this.origin,
    required this.current,
    required this.maxRadius,
    required this.opacity,
  });

  final Offset origin;
  final Offset current;
  final double maxRadius;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.01) return;

    final delta = current - origin;
    final dist = delta.distance;
    final clampedDelta =
        dist > maxRadius ? (delta / dist) * maxRadius : delta;
    final knobCenter = origin + clampedDelta;

    final baseRect = Rect.fromCircle(center: origin, radius: maxRadius);

    // 1. Subtle translucent 1969 tie-dye aura ring
    final tieDyePaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Color.fromRGBO(255, 190, 11, 0.24 * opacity),
          Color.fromRGBO(251, 86, 7, 0.22 * opacity),
          Color.fromRGBO(131, 56, 236, 0.22 * opacity),
          Color.fromRGBO(6, 214, 160, 0.24 * opacity),
          Color.fromRGBO(255, 190, 11, 0.24 * opacity),
        ],
      ).createShader(baseRect);
    canvas.drawCircle(origin, maxRadius, tieDyePaint);

    // 2. Warm walnut woodgrain concentric rings
    final grainRingOuter = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Color.fromRGBO(212, 154, 90, 0.48 * opacity);
    canvas.drawCircle(origin, maxRadius, grainRingOuter);

    final grainRingInner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Color.fromRGBO(244, 227, 193, 0.22 * opacity);
    canvas.drawCircle(origin, maxRadius * 0.62, grainRingInner);

    // 3. Soft directional tether
    if (clampedDelta.distance > 3.0) {
      canvas.drawLine(
        origin,
        knobCenter,
        Paint()
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..color = Color.fromRGBO(255, 209, 102, 0.44 * opacity),
      );
    }

    // 4. Tactile carved walnut shell thumb nub
    canvas.drawCircle(
      knobCenter,
      16.0,
      Paint()..color = Color.fromRGBO(42, 24, 14, 0.72 * opacity),
    );
    canvas.drawCircle(
      knobCenter,
      16.0,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = Color.fromRGBO(255, 209, 102, 0.78 * opacity),
    );
    // Tiny peace-sign emblem inside the nub
    final peacePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..color = Color.fromRGBO(255, 243, 176, 0.62 * opacity);
    canvas.drawCircle(knobCenter, 6.5, peacePaint);
    canvas.drawLine(
      knobCenter + const Offset(0, -6.5),
      knobCenter + const Offset(0, 6.5),
      peacePaint,
    );
    canvas.drawLine(
      knobCenter,
      knobCenter + Offset(-math.cos(math.pi / 4) * 6.5, math.sin(math.pi / 4) * 6.5),
      peacePaint,
    );
    canvas.drawLine(
      knobCenter,
      knobCenter + Offset(math.cos(math.pi / 4) * 6.5, math.sin(math.pi / 4) * 6.5),
      peacePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TieDyeWoodgrainStickPainter old) =>
      old.origin != origin ||
      old.current != current ||
      old.opacity != opacity;
}
