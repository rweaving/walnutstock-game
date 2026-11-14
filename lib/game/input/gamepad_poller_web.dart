import 'dart:js_interop';

@JS('navigator')
external _JsNavigator? get _navigator;

extension type _JsNavigator._(JSObject _) implements JSObject {
  external JSArray<_JsGamepad?>? getGamepads();
}

extension type _JsGamepad._(JSObject _) implements JSObject {
  external bool get connected;
  external JSArray<JSNumber> get axes;
  external JSArray<_JsGamepadButton?> get buttons;
}

extension type _JsGamepadButton._(JSObject _) implements JSObject {
  external bool get pressed;
}

class GamepadSample {
  const GamepadSample({
    this.dx = 0.0,
    this.dy = 0.0,
    this.interactPressed = false,
    this.swayPressed = false,
    this.journalPressed = false,
  });

  final double dx;
  final double dy;
  final bool interactPressed;
  final bool swayPressed;
  final bool journalPressed;
}

GamepadSample pollHtml5Gamepad() {
  try {
    final nav = _navigator;
    if (nav == null) return const GamepadSample();
    final pads = nav.getGamepads();
    if (pads == null) return const GamepadSample();

    final padList = pads.toDart;
    for (final pad in padList) {
      if (pad == null || !pad.connected) continue;
      final axes = pad.axes.toDart;
      final buttons = pad.buttons.toDart;

      var dx = axes.isNotEmpty ? axes[0].toDartDouble : 0.0;
      var dy = axes.length > 1 ? axes[1].toDartDouble : 0.0;

      bool btnPressed(int idx) =>
          idx < buttons.length && (buttons[idx]?.pressed ?? false);

      if (btnPressed(14)) dx = -1.0;
      if (btnPressed(15)) dx = 1.0;
      if (btnPressed(12)) dy = -1.0;
      if (btnPressed(13)) dy = 1.0;

      return GamepadSample(
        dx: dx.abs() > 0.2 ? dx : 0.0,
        dy: dy.abs() > 0.2 ? dy : 0.0,
        interactPressed: btnPressed(0),
        swayPressed: btnPressed(1),
        journalPressed: btnPressed(3),
      );
    }
    return const GamepadSample();
  } catch (_) {
    return const GamepadSample();
  }
}
