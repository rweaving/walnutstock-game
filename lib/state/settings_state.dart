import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TouchControlsLayout {
  auto,
  landscapeDpad,
  portraitGameBoy,
  hidden;

  static TouchControlsLayout fromName(String? raw) {
    for (final v in TouchControlsLayout.values) {
      if (v.name == raw) return v;
    }
    return TouchControlsLayout.auto;
  }
}

class SettingsState extends Equatable {
  const SettingsState({
    this.shaderIntensity = 0.85,
    this.textSpeedMultiplier = 1.0,
    this.masterVolume = 0.9,
    this.musicVolume = 0.85,
    this.sfxVolume = 0.85,
    this.touchLayout = TouchControlsLayout.auto,
    this.vinylCrackleEnabled = true,
    this.fogVisualAssist = true,
    this.minimapExpanded = false,
  });

  factory SettingsState.fromJson(Map<String, dynamic> json) {
    return SettingsState(
      shaderIntensity: ((json['shaderIntensity'] as num?)?.toDouble() ?? 0.85)
          .clamp(0.0, 1.0),
      textSpeedMultiplier:
          ((json['textSpeedMultiplier'] as num?)?.toDouble() ?? 1.0)
              .clamp(0.5, 2.5),
      masterVolume:
          ((json['masterVolume'] as num?)?.toDouble() ?? 0.9).clamp(0.0, 1.0),
      musicVolume:
          ((json['musicVolume'] as num?)?.toDouble() ?? 0.85).clamp(0.0, 1.0),
      sfxVolume:
          ((json['sfxVolume'] as num?)?.toDouble() ?? 0.85).clamp(0.0, 1.0),
      touchLayout: TouchControlsLayout.fromName(json['touchLayout'] as String?),
      vinylCrackleEnabled: json['vinylCrackleEnabled'] as bool? ?? true,
      fogVisualAssist: json['fogVisualAssist'] as bool? ?? true,
      minimapExpanded: json['minimapExpanded'] as bool? ?? false,
    );
  }

  final double shaderIntensity;
  final double textSpeedMultiplier;
  final double masterVolume;
  final double musicVolume;
  final double sfxVolume;
  final TouchControlsLayout touchLayout;
  final bool vinylCrackleEnabled;
  final bool fogVisualAssist;
  final bool minimapExpanded;

  SettingsState copyWith({
    double? shaderIntensity,
    double? textSpeedMultiplier,
    double? masterVolume,
    double? musicVolume,
    double? sfxVolume,
    TouchControlsLayout? touchLayout,
    bool? vinylCrackleEnabled,
    bool? fogVisualAssist,
    bool? minimapExpanded,
  }) {
    return SettingsState(
      shaderIntensity: shaderIntensity ?? this.shaderIntensity,
      textSpeedMultiplier: textSpeedMultiplier ?? this.textSpeedMultiplier,
      masterVolume: masterVolume ?? this.masterVolume,
      musicVolume: musicVolume ?? this.musicVolume,
      sfxVolume: sfxVolume ?? this.sfxVolume,
      touchLayout: touchLayout ?? this.touchLayout,
      vinylCrackleEnabled: vinylCrackleEnabled ?? this.vinylCrackleEnabled,
      fogVisualAssist: fogVisualAssist ?? this.fogVisualAssist,
      minimapExpanded: minimapExpanded ?? this.minimapExpanded,
    );
  }

  Map<String, dynamic> toJson() => {
        'shaderIntensity': shaderIntensity,
        'textSpeedMultiplier': textSpeedMultiplier,
        'masterVolume': masterVolume,
        'musicVolume': musicVolume,
        'sfxVolume': sfxVolume,
        'touchLayout': touchLayout.name,
        'vinylCrackleEnabled': vinylCrackleEnabled,
        'fogVisualAssist': fogVisualAssist,
        'minimapExpanded': minimapExpanded,
      };

  @override
  List<Object?> get props => [
        shaderIntensity,
        textSpeedMultiplier,
        masterVolume,
        musicVolume,
        sfxVolume,
        touchLayout,
        vinylCrackleEnabled,
        fogVisualAssist,
        minimapExpanded,
      ];
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState());

  void hydrate(SettingsState s) => state = s;

  void setShaderIntensity(double v) =>
      state = state.copyWith(shaderIntensity: v.clamp(0.0, 1.0));

  void setTextSpeed(double v) =>
      state = state.copyWith(textSpeedMultiplier: v.clamp(0.5, 2.5));

  void setMasterVolume(double v) =>
      state = state.copyWith(masterVolume: v.clamp(0.0, 1.0));

  void setMusicVolume(double v) =>
      state = state.copyWith(musicVolume: v.clamp(0.0, 1.0));

  void setSfxVolume(double v) =>
      state = state.copyWith(sfxVolume: v.clamp(0.0, 1.0));

  void setTouchLayout(TouchControlsLayout layout) =>
      state = state.copyWith(touchLayout: layout);

  void toggleVinylCrackle() =>
      state = state.copyWith(vinylCrackleEnabled: !state.vinylCrackleEnabled);

  void toggleFogVisualAssist() =>
      state = state.copyWith(fogVisualAssist: !state.fogVisualAssist);

  void toggleMinimapExpanded() =>
      state = state.copyWith(minimapExpanded: !state.minimapExpanded);
}
