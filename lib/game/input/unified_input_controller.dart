import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'gamepad_poller.dart';

class UnifiedInputController {
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  final Vector2 _virtualDpad = Vector2.zero();

  bool _prevPadInteract = false;
  bool _prevPadSway = false;
  bool _prevPadJournal = false;

  void setVirtualDpad(double dx, double dy) {
    _virtualDpad.setValues(dx.clamp(-1.0, 1.0), dy.clamp(-1.0, 1.0));
  }

  void clearAll() {
    _pressedKeys.clear();
    _virtualDpad.setZero();
  }

  /// Handles keyboard events; returns action trigger ('interact', 'use_gadget', 'dance', 'dance_style', 'sway', 'journal', 'mud_toss', 'mud_slide', or null).
  String? handleKeyEvent(KeyEvent event) {
    final key = event.logicalKey;
    if (event is KeyDownEvent) {
      final isFreshPress = _pressedKeys.add(key);
      if (isFreshPress) {
        if (key == LogicalKeyboardKey.keyE ||
            key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.enter) {
          return 'interact';
        }
        if (key == LogicalKeyboardKey.keyQ) {
          return 'use_gadget';
        }
        if (key == LogicalKeyboardKey.keyB ||
            key == LogicalKeyboardKey.keyG) {
          return 'dance';
        }
        if (key == LogicalKeyboardKey.keyN) {
          return 'dance_style';
        }
        if (key == LogicalKeyboardKey.keyF) {
          return 'mud_toss';
        }
        if (key == LogicalKeyboardKey.shiftLeft ||
            key == LogicalKeyboardKey.shiftRight ||
            key == LogicalKeyboardKey.keyC) {
          return 'mud_slide';
        }
        if (key == LogicalKeyboardKey.keyM) {
          return 'sway';
        }
        if (key == LogicalKeyboardKey.tab || key == LogicalKeyboardKey.keyJ) {
          return 'journal';
        }
      }
    } else if (event is KeyUpEvent) {
      _pressedKeys.remove(key);
    }
    return null;
  }

  /// Combines Keyboard + Virtual Touch D-Pad + HTML5 Gamepad sticks/buttons.
  ({Vector2 move, String? gamepadAction}) sampleMovementAndGamepad() {
    var dx = _virtualDpad.x;
    var dy = _virtualDpad.y;

    if (_pressedKeys.contains(LogicalKeyboardKey.keyA) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowLeft)) {
      dx -= 1.0;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyD) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowRight)) {
      dx += 1.0;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyW) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowUp)) {
      dy -= 1.0;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyS) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowDown)) {
      dy += 1.0;
    }

    final pad = pollHtml5Gamepad();
    dx += pad.dx;
    dy += pad.dy;

    String? padAction;
    if (pad.interactPressed && !_prevPadInteract) padAction = 'interact';
    if (pad.swayPressed && !_prevPadSway) padAction = 'sway';
    if (pad.journalPressed && !_prevPadJournal) padAction = 'journal';
    _prevPadInteract = pad.interactPressed;
    _prevPadSway = pad.swayPressed;
    _prevPadJournal = pad.journalPressed;

    return (
      move: Vector2(dx.clamp(-1.0, 1.0), dy.clamp(-1.0, 1.0)),
      gamepadAction: padAction,
    );
  }
}
