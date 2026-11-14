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

GamepadSample pollHtml5Gamepad() => const GamepadSample();
