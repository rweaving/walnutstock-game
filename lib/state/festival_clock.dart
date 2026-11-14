import 'dart:math' as math;
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models.dart';

enum WeatherPhase {
  clear,
  preStormHumid,
  blightRainstorm,
  postStormMist,
  starryFireflies,
  purpleDustFinale;

  static WeatherPhase fromName(String? raw) {
    for (final v in WeatherPhase.values) {
      if (v.name == raw) return v;
    }
    return WeatherPhase.clear;
  }
}

enum TimeOfDayPhase {
  dawn,
  morning,
  midday,
  goldenHour,
  dusk,
  night,
}

class FestivalClockState extends Equatable {
  const FestivalClockState({
    this.day = 1,
    this.minuteOfDay = 480.0, // 8:00 AM Friday Arrival
    this.weather = WeatherPhase.clear,
    this.pureVibeMode = false,
    this.wristbandAlertsEnabled = true,
    this.encoreModeUnlocked = false,
    this.clockPaused = false,
    this.timeSpeedMultiplier = 1.0,
    this.weatherOverride,
    this.shaderOverride,
  });

  factory FestivalClockState.fromJson(Map<String, dynamic> json) {
    final rawDay = (json['day'] as num?)?.toInt() ?? 1;
    final rawMinute = (json['minuteOfDay'] as num?)?.toDouble() ?? 480.0;
    final rawOverride = json['weatherOverride'] as String?;
    final rawSpeed = (json['timeSpeedMultiplier'] as num?)?.toDouble() ?? 1.0;

    return FestivalClockState(
      day: rawDay.clamp(1, 3),
      minuteOfDay: rawMinute.clamp(300.0, 2000.0),
      weather: WeatherPhase.fromName(json['weather'] as String?),
      pureVibeMode: json['pureVibeMode'] as bool? ?? false,
      wristbandAlertsEnabled: json['wristbandAlertsEnabled'] as bool? ?? true,
      encoreModeUnlocked: json['encoreModeUnlocked'] as bool? ?? false,
      clockPaused: json['clockPaused'] as bool? ?? false,
      timeSpeedMultiplier: rawSpeed.clamp(1.0, 20.0),
      weatherOverride:
          rawOverride == null ? null : WeatherPhase.fromName(rawOverride),
      shaderOverride: json['shaderOverride'] as String?,
    );
  }

  static const double dayStartMinute = 300.0; // 5:00 AM

  final int day; // 1 = Friday, 2 = Saturday, 3 = Sunday
  final double minuteOfDay; // 300.0 (5:00 AM) .. ~1695+ (past 4:00 AM)
  final WeatherPhase weather;
  final bool pureVibeMode;
  final bool wristbandAlertsEnabled;
  final bool encoreModeUnlocked;
  final bool clockPaused;
  final double timeSpeedMultiplier;
  final WeatherPhase? weatherOverride;
  final String? shaderOverride;

  WeatherPhase get effectiveWeather => weatherOverride ?? weather;

  TimeOfDayPhase get timeOfDayPhase {
    if (minuteOfDay >= 300.0 && minuteOfDay < 410.0) {
      return TimeOfDayPhase.dawn;
    }
    if (minuteOfDay >= 410.0 && minuteOfDay < 600.0) {
      return TimeOfDayPhase.morning;
    }
    if (minuteOfDay >= 600.0 && minuteOfDay < 990.0) {
      return TimeOfDayPhase.midday;
    }
    if (minuteOfDay >= 990.0 && minuteOfDay < 1125.0) {
      return TimeOfDayPhase.goldenHour;
    }
    if (minuteOfDay >= 1125.0 && minuteOfDay < 1230.0) {
      return TimeOfDayPhase.dusk;
    }
    return TimeOfDayPhase.night;
  }

  String get timeOfDayLabel {
    switch (timeOfDayPhase) {
      case TimeOfDayPhase.dawn:
        return '🌅 Dawn';
      case TimeOfDayPhase.morning:
        return '🌤️ Morning';
      case TimeOfDayPhase.midday:
        return '☀️ Midday';
      case TimeOfDayPhase.goldenHour:
        return '🌇 Golden Hr';
      case TimeOfDayPhase.dusk:
        return '🌆 Dusk';
      case TimeOfDayPhase.night:
        return '🌙 Night';
    }
  }

  /// Normalized 0.0 (5:00 AM) .. 1.0 (~4:00 AM) progress across the festival day cycle.
  double get dayArcProgress => ((minuteOfDay - 300.0) / 1380.0).clamp(0.0, 1.0);

  String get dayLabel {
    switch (day) {
      case 1:
        return 'DAY 1 · FRI';
      case 2:
        return 'DAY 2 · SAT';
      case 3:
      default:
        return 'DAY 3 · SUN';
    }
  }

  String get formattedClock {
    final totalMins = minuteOfDay.floor() % 1440;
    final hour24 = totalMins ~/ 60;
    final min = totalMins % 60;
    final suffix = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '${hour12.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')} $suffix';
  }

  bool get isMorningDewWindow => minuteOfDay >= 300.0 && minuteOfDay <= 510.0;

  /// True at the start of Day 2 (5:00 AM Dawn through 3:00 PM) when festivalgoers
  /// share Electric Purple Blueberries beside the Willow Creek & Meadow Stage!
  bool get isDay2BlueberrySharingActive =>
      day == 2 && minuteOfDay >= 300.0 && minuteOfDay <= 900.0;

  bool get isNightOrDusk => minuteOfDay >= 1140.0 || minuteOfDay < 365.0;

  /// True during the post-rain Woodstock Mud Experience (sliding & mud fights after Day 1 Set 8 & Day 2 Storm).
  bool isMudExperienceActive([SetlistCatalog? catalog]) {
    if (weatherOverride != null) {
      return weatherOverride == WeatherPhase.postStormMist;
    }
    if (day == 1) {
      final afterSet8 = catalog?.trackByNumber(8)?.endMinute ?? 1305.44;
      return minuteOfDay >= afterSet8;
    }
    if (day == 2) {
      final afterTrack15 = catalog?.trackByNumber(16)?.startMinute ??
          catalog?.trackByNumber(15)?.endMinute ??
          1185.0;
      return minuteOfDay >= afterTrack15;
    }
    if (day == 3) {
      final mistClear = catalog?.trackByNumber(18)?.endMinute ?? 515.0;
      return minuteOfDay < mistClear;
    }
    return false;
  }

  /// True whenever orchard lanes & the Mud Pit Meadow are slick mud (during storm & post-rain mud fest).
  bool isOrchardMuddy([SetlistCatalog? catalog]) {
    final eff = effectiveWeather;
    if (eff == WeatherPhase.blightRainstorm ||
        eff == WeatherPhase.postStormMist) {
      return true;
    }
    if (weatherOverride == null && day == 1) {
      final set8Start = catalog?.trackByNumber(8)?.startMinute ?? 1171.64;
      return minuteOfDay >= set8Start;
    }
    return false;
  }

  FestivalClockState copyWith({
    int? day,
    double? minuteOfDay,
    WeatherPhase? weather,
    bool? pureVibeMode,
    bool? wristbandAlertsEnabled,
    bool? encoreModeUnlocked,
    bool? clockPaused,
    double? timeSpeedMultiplier,
    WeatherPhase? weatherOverride,
    bool clearWeatherOverride = false,
    String? shaderOverride,
    bool clearShaderOverride = false,
  }) {
    return FestivalClockState(
      day: day ?? this.day,
      minuteOfDay: minuteOfDay ?? this.minuteOfDay,
      weather: weather ?? this.weather,
      pureVibeMode: pureVibeMode ?? this.pureVibeMode,
      wristbandAlertsEnabled:
          wristbandAlertsEnabled ?? this.wristbandAlertsEnabled,
      encoreModeUnlocked: encoreModeUnlocked ?? this.encoreModeUnlocked,
      clockPaused: clockPaused ?? this.clockPaused,
      timeSpeedMultiplier: timeSpeedMultiplier ?? this.timeSpeedMultiplier,
      weatherOverride: clearWeatherOverride
          ? null
          : (weatherOverride ?? this.weatherOverride),
      shaderOverride:
          clearShaderOverride ? null : (shaderOverride ?? this.shaderOverride),
    );
  }

  Map<String, dynamic> toJson() => {
        'day': day,
        'minuteOfDay': minuteOfDay,
        'weather': weather.name,
        'pureVibeMode': pureVibeMode,
        'wristbandAlertsEnabled': wristbandAlertsEnabled,
        'encoreModeUnlocked': encoreModeUnlocked,
        'clockPaused': clockPaused,
        if (timeSpeedMultiplier != 1.0)
          'timeSpeedMultiplier': timeSpeedMultiplier,
        if (weatherOverride != null) 'weatherOverride': weatherOverride!.name,
        if (shaderOverride != null) 'shaderOverride': shaderOverride,
      };

  @override
  List<Object?> get props => [
        day,
        minuteOfDay,
        weather,
        pureVibeMode,
        wristbandAlertsEnabled,
        encoreModeUnlocked,
        clockPaused,
        timeSpeedMultiplier,
        weatherOverride,
        shaderOverride,
      ];
}

class FestivalClockNotifier extends StateNotifier<FestivalClockState> {
  FestivalClockNotifier(this._catalog) : super(const FestivalClockState()) {
    state = state.copyWith(
      weather: deriveWeather(state.day, state.minuteOfDay, _catalog),
    );
  }

  SetlistCatalog? _catalog;

  void attachCatalog(SetlistCatalog catalog) {
    _catalog = catalog;
    state = state.copyWith(
      weather: deriveWeather(state.day, state.minuteOfDay, _catalog),
    );
  }

  void hydrate(FestivalClockState loaded) {
    state = loaded.copyWith(
      weather: deriveWeather(loaded.day, loaded.minuteOfDay, _catalog),
    );
  }

  /// Dynamic schedule-driven day upper bound: fixes v0.1.0 Track 10/25/26 truncation!
  double dayEndMinuteFor(int day) {
    final lastTrackEnd = _catalog?.lastEndMinuteForDay(day) ?? 1590.0;
    return math.max(1590.0, lastTrackEnd + 18.0);
  }

  /// Schedule-synced weather derivation (including Day 1 Set 7 rain ramp -> Set 8 storm -> post-Set-8 mud!).
  static WeatherPhase deriveWeather(
    int day,
    double minute,
    SetlistCatalog? catalog,
  ) {
    final track7 = catalog?.trackByNumber(7); // Day 1 Set 7: Rain starts ramping!
    final track8 = catalog?.trackByNumber(8); // Day 1 Set 8: Santana-Shell Rainstorm!
    final track10 = catalog?.trackByNumber(10); // Day 1 Set 10: Fireflies over mud!
    final track15 = catalog?.trackByNumber(15); // Bad Moon Risin'
    final track16 = catalog?.trackByNumber(16); // Talkin' 'Bout My Dehiscence
    final track18 = catalog?.trackByNumber(18); // Sun Through the Mist
    final track25 = catalog?.trackByNumber(25); // Purple Haze

    if (day == 1) {
      final rainRampStart = track7?.startMinute ?? 1139.61;
      final stormStart = track8?.startMinute ?? 1171.64;
      final stormEnd = track8?.endMinute ?? 1305.44;
      final fireflyStart = track10?.startMinute ?? 1466.25;

      if (minute >= rainRampStart && minute < stormStart) {
        return WeatherPhase.preStormHumid;
      }
      if (minute >= stormStart && minute < stormEnd) {
        return WeatherPhase.blightRainstorm;
      }
      if (minute >= stormEnd && minute < fireflyStart) {
        return WeatherPhase.postStormMist;
      }
      if (minute >= fireflyStart) {
        return WeatherPhase.starryFireflies;
      }
      return WeatherPhase.clear;
    }

    if (day == 2) {
      final stormStart = track15?.startMinute ?? 1070.0;
      // Rain pours during Track 15 ("Bad Moon Risin'"), then transitions to post-storm
      // mud-pit mist right as Track 16 ("Talkin' 'Bout My Dehiscence") kicks off!
      final stormEnd =
          track16?.startMinute ?? track15?.endMinute ?? (stormStart + 115.0);
      final warningStart = stormStart - 180.0; // 3 in-game hours early!
      if (minute >= warningStart && minute < stormStart) {
        return WeatherPhase.preStormHumid;
      }
      if (minute >= stormStart && minute < stormEnd) {
        return WeatherPhase.blightRainstorm;
      }
      if (minute >= stormEnd) {
        return WeatherPhase.postStormMist;
      }
      return WeatherPhase.clear;
    }

    if (day == 3) {
      final mistClear = track18?.endMinute ?? 515.0;
      final purpleStart = track25?.startMinute ?? 1400.0;
      if (minute < mistClear) {
        return WeatherPhase.postStormMist;
      }
      if (minute >= purpleStart) {
        return WeatherPhase.purpleDustFinale;
      }
      return WeatherPhase.clear;
    }

    return WeatherPhase.clear;
  }

  /// Returns true when dirt orchard lanes & the Mud Pit Meadow are wet & momentum-slippery!
  bool get areDirtPathsMuddy => state.isOrchardMuddy(_catalog);

  /// Returns true during the post-rain Woodstock Mud Experience (after Day 1 Set 8 & Day 2 Storm)!
  bool get isMudExperienceActive => state.isMudExperienceActive(_catalog);

  void tickRealSeconds(double dtSeconds) {
    if (dtSeconds <= 0 || state.clockPaused) return;
    final rate = _catalog?.clockMinutesPerRealSecond ?? 0.55;
    advanceMinutes(dtSeconds * rate * state.timeSpeedMultiplier);
  }

  void advanceMinutes(double deltaMinutes) {
    if (deltaMinutes <= 0) return;
    var d = state.day;
    var m = state.minuteOfDay + deltaMinutes;
    var encoreUnlocked = state.encoreModeUnlocked;

    while (m >= dayEndMinuteFor(d)) {
      if (d < 3) {
        m = FestivalClockState.dayStartMinute + (m - dayEndMinuteFor(d));
        d += 1;
      } else {
        // Completed Sunday Night Finale -> unlock Endless Encore Mode & wrap gently to Sunrise!
        encoreUnlocked = true;
        m = FestivalClockState.dayStartMinute;
        d = 1;
        break;
      }
    }

    state = state.copyWith(
      day: d,
      minuteOfDay: m,
      weather: deriveWeather(d, m, _catalog),
      encoreModeUnlocked: encoreUnlocked,
    );
  }

  void setClockDirect({required int day, required double minuteOfDay}) {
    final clampedDay = day.clamp(1, 3);
    final clampedMin = minuteOfDay.clamp(
      FestivalClockState.dayStartMinute,
      dayEndMinuteFor(clampedDay),
    );
    state = state.copyWith(
      day: clampedDay,
      minuteOfDay: clampedMin,
      weather: deriveWeather(clampedDay, clampedMin, _catalog),
    );
  }

  ScheduledTrack? jumpToNextScheduledSet() {
    final catalog = _catalog;
    if (catalog == null) return null;
    final next = catalog.nextUpcomingTrack(state.day, state.minuteOfDay);
    if (next == null) return null;
    setClockDirect(day: next.day, minuteOfDay: next.startMinute + 0.05);
    return next;
  }

  void jumpToTrack(ScheduledTrack track) {
    setClockDirect(day: track.day, minuteOfDay: track.startMinute + 0.05);
  }

  void restUntilSunrise() {
    final nextDay = state.minuteOfDay > 420.0
        ? (state.day < 3 ? state.day + 1 : 2)
        : state.day;
    setClockDirect(day: nextDay, minuteOfDay: 305.0); // 5:05 AM Morning Dew!
  }

  void restUntilGoldenHour() {
    final targetDay = state.minuteOfDay >= 1130.0
        ? (state.day < 3 ? state.day + 1 : 1)
        : state.day;
    setClockDirect(day: targetDay, minuteOfDay: 1080.0); // 6:00 PM Sunset Glow!
  }

  void restUntilStarryNight() {
    final targetDay = state.minuteOfDay >= 1380.0
        ? (state.day < 3 ? state.day + 1 : 1)
        : state.day;
    setClockDirect(day: targetDay, minuteOfDay: 1320.0); // 10:00 PM Night!
  }

  void restUntilSaturdayStorm() {
    final stormTrack = _catalog?.trackByNumber(15);
    final minute = stormTrack?.startMinute ?? 1070.0;
    setClockDirect(day: 2, minuteOfDay: minute + 0.1);
  }

  void restUntilDay1RainRamp() {
    final track7 = _catalog?.trackByNumber(7);
    final minute = track7?.startMinute ?? 1139.61;
    setClockDirect(day: 1, minuteOfDay: minute + 0.2);
  }

  void restUntilMudExperience() {
    final track8 = _catalog?.trackByNumber(8);
    final minute = track8?.endMinute ?? 1305.44;
    setClockDirect(day: 1, minuteOfDay: minute + 0.5);
  }

  void restUntilDay2Blueberries() {
    setWeatherOverride(null);
    setClockDirect(day: 2, minuteOfDay: 305.0);
  }

  void cycleTimeSpeed() {
    final next = state.timeSpeedMultiplier < 2.0
        ? 4.0
        : (state.timeSpeedMultiplier < 8.0 ? 10.0 : 1.0);
    state = state.copyWith(timeSpeedMultiplier: next, clockPaused: false);
  }

  void setTimeSpeed(double speed) {
    state = state.copyWith(timeSpeedMultiplier: speed.clamp(1.0, 20.0));
  }

  void togglePureVibeMode() {
    state = state.copyWith(pureVibeMode: !state.pureVibeMode);
  }

  void setPureVibeMode(bool enabled) {
    state = state.copyWith(pureVibeMode: enabled);
  }

  void toggleWristbandAlerts() {
    state = state.copyWith(
      wristbandAlertsEnabled: !state.wristbandAlertsEnabled,
    );
  }

  void unlockEncoreMode() {
    if (!state.encoreModeUnlocked) {
      state = state.copyWith(encoreModeUnlocked: true);
    }
  }

  void toggleClockPaused() {
    state = state.copyWith(clockPaused: !state.clockPaused);
  }

  void setWeatherOverride(WeatherPhase? override) {
    if (override == null) {
      state = state.copyWith(clearWeatherOverride: true);
    } else {
      state = state.copyWith(weatherOverride: override);
    }
  }

  void setShaderOverride(String? shaderKey) {
    if (shaderKey == null) {
      state = state.copyWith(clearShaderOverride: true);
    } else {
      state = state.copyWith(shaderOverride: shaderKey);
    }
  }
}
