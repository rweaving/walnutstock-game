class CrowdSwayController {
  double aura = 0.0;

  /// Updates the stage-front Crowd Resonance aura (`0.0..1.0`) and returns target camera zoom.
  double update({
    required double dt,
    required double audibleStageGain,
    required bool playerSwaying,
    bool playerDancing = false,
    required bool pureVibeMode,
    required bool justListenMode,
  }) {
    if (justListenMode) {
      aura = (aura - dt * 0.4).clamp(0.0, 1.0);
      return 1.0;
    }

    final nearActiveStage = audibleStageGain >= 0.36;
    if (nearActiveStage && (playerDancing || playerSwaying || pureVibeMode)) {
      final rate = playerDancing ? 0.30 : 0.22;
      aura = (aura + dt * rate).clamp(0.0, 1.0);
    } else if (playerDancing) {
      // Dancing anywhere in the orchard still builds a joyful groove aura!
      final target = 0.42;
      if (aura < target) {
        aura = (aura + dt * 0.16).clamp(0.0, target);
      } else {
        aura = (aura - dt * 0.08).clamp(target, 1.0);
      }
    } else {
      aura = (aura - dt * 0.14).clamp(0.0, 1.0);
    }

    // Unlock wide concert "stage-dive" camera zoom when Crowd Resonance peaks!
    if (aura > 0.65) {
      final t = ((aura - 0.65) / 0.35).clamp(0.0, 1.0);
      return 1.0 - 0.12 * t; // Smoothly zooms out from 1.0 -> 0.88
    }
    return 1.0;
  }
}
