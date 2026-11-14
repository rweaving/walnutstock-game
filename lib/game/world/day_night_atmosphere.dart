import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../state/festival_clock.dart';
import 'tiled_map_parser.dart';

/// Immutable continuous astronomical Day/Night + Weather/Rainstorm lighting metrics.
class DayNightMetrics {
  const DayNightMetrics({
    required this.sunAltitude,
    required this.shadowOffset,
    required this.shadowAlpha,
    required this.ambientTint,
    required this.ambientTintStrength,
    required this.darknessFactor,
    required this.stormBuildUp,
    required this.rainIntensity,
    required this.wetness,
    required this.mistIntensity,
    required this.sunbeamIntensity,
    required this.windStrength,
    required this.lightningFlash,
    required this.starlightAlpha,
    required this.lanternGlowStrength,
  });

  /// -1.0 (midnight nadir) .. 0.0 (sunrise/sunset horizon) .. +1.0 (solar noon).
  final double sunAltitude;

  /// Directional 3D shadow vector in world pixels (West at dawn -> compact noon -> East at sunset).
  final Offset shadowOffset;
  final double shadowAlpha;

  /// Atmospheric color grade (peach dawn, clear day, amber golden hour, violet dusk, indigo night, slate storm).
  final Color ambientTint;
  final double ambientTintStrength;

  /// Overall sky darkness (0.0 at high noon .. ~0.58 at midnight or heavy rainstorm).
  final double darknessFactor;

  /// 0.0 .. 1.0 progressive storm cloud build-up (ramps in `preStormHumid`, 1.0 in `blightRainstorm`).
  final double stormBuildUp;
  final double rainIntensity;
  final double wetness;
  final double mistIntensity;
  final double sunbeamIntensity;
  final double windStrength;
  final double lightningFlash;
  final double starlightAlpha;
  final double lanternGlowStrength;

  static const DayNightMetrics middayDefault = DayNightMetrics(
    sunAltitude: 1.0,
    shadowOffset: Offset(1.0, 2.2),
    shadowAlpha: 0.32,
    ambientTint: Color(0xFFFFFFFF),
    ambientTintStrength: 0.0,
    darknessFactor: 0.0,
    stormBuildUp: 0.0,
    rainIntensity: 0.0,
    wetness: 0.0,
    mistIntensity: 0.0,
    sunbeamIntensity: 0.0,
    windStrength: 0.16,
    lightningFlash: 0.0,
    starlightAlpha: 0.0,
    lanternGlowStrength: 0.0,
  );

  static DayNightMetrics compute(
    FestivalClockState clock, {
    required double timeSeconds,
    double bass = 0.0,
    double shaderIntensity = 0.85,
    double stormStartMinute = 1070.0,
    double day1RainRampStartMinute = 1139.61,
    double day1StormStartMinute = 1171.64,
  }) {
    final m = clock.minuteOfDay;
    final weather = clock.effectiveWeather;

    // 1. Continuous solar altitude & azimuth across 300 (5:00 AM) .. 1700 (~4:20 AM)
    double sunAlt;
    if (m >= 335.0 && m <= 1155.0) {
      final t = (m - 335.0) / (1155.0 - 335.0);
      sunAlt = math.sin(t * math.pi);
    } else {
      final nightM = m < 335.0 ? m + 1440.0 : m;
      final t = ((nightM - 1155.0) / (1775.0 - 1155.0)).clamp(0.0, 1.0);
      sunAlt = -math.sin(t * math.pi);
    }

    // Shadow vector:
    //   5:35 AM Dawn (East sun) -> long shadow West (-8.8, 2.6)
    //   12:30 PM Midday -> compact shadow (0.6, 2.1)
    //   6:00 PM Golden Hour (West sun) -> long warm shadow East (+9.4, 3.2)
    //   Night -> gentle lunar contact shadow (-2.2, 2.0)
    Offset rawShadow;
    double rawShadowAlpha;
    if (m >= 335.0 && m <= 1165.0) {
      final dayT = ((m - 335.0) / (1165.0 - 335.0)).clamp(0.0, 1.0);
      final sx = -8.8 + dayT * 18.4; // -8.8 -> +9.6
      final sy = 2.1 + (1.0 - sunAlt.clamp(0.0, 1.0)) * 1.3;
      rawShadow = Offset(sx, sy);
      rawShadowAlpha = 0.24 + 0.16 * sunAlt.clamp(0.0, 1.0);
    } else {
      rawShadow = const Offset(-2.2, 2.0);
      rawShadowAlpha = 0.22;
    }

    // 2. Smooth keyframe sky color grade & base astronomical darkness
    final (skyColor, skyTintAlpha, baseDarkness) = _sampleSkyKeyframes(m);

    // 3. Couple Weather / Rainstorm progression smoothly into atmosphere
    var stormBuild = 0.0;
    var rain = 0.0;
    var wet = 0.0;
    var mist = 0.0;
    var wind = 0.16;
    var lightning = 0.0;

    switch (weather) {
      case WeatherPhase.clear:
        wind = 0.16;
        break;
      case WeatherPhase.preStormHumid:
        if (clock.weatherOverride == WeatherPhase.preStormHumid) {
          stormBuild = 0.72;
          rain = 0.28;
          wet = 0.36;
          wind = 0.58;
        } else if (clock.day == 1) {
          // Day 1 Set 7: Rain visibly & continuously ramps up toward Set 8's downpour!
          final span =
              math.max(8.0, day1StormStartMinute - day1RainRampStartMinute);
          final rampT =
              ((m - day1RainRampStartMinute) / span).clamp(0.0, 1.0);
          stormBuild = (0.30 + 0.66 * rampT).clamp(0.30, 0.96);
          rain = (0.14 + 0.64 * rampT).clamp(0.14, 0.78);
          wet = (0.22 + 0.66 * rampT).clamp(0.22, 0.88);
          wind = 0.30 + 0.58 * rampT;
          if (rampT > 0.55) {
            final horizonPulse = math
                .pow(
                  math.max(
                      0.0, math.sin(timeSeconds * 0.53) * math.sin(timeSeconds * 2.41)),
                  16,
                )
                .toDouble();
            lightning = (horizonPulse * 0.45 * shaderIntensity).clamp(0.0, 0.5);
          }
        } else {
          final warningStart = stormStartMinute - 180.0;
          stormBuild = (0.24 +
                  0.72 *
                      ((m - warningStart) / 180.0).clamp(0.0, 1.0))
              .clamp(0.24, 0.96);
          wet = stormBuild * 0.22;
          wind = 0.26 + 0.46 * stormBuild;
        }
        break;
      case WeatherPhase.blightRainstorm:
        stormBuild = 1.0;
        rain = 1.0;
        wet = 1.0;
        wind = 1.0;
        final strikeA =
            math.pow(math.max(0.0, math.sin(timeSeconds * 0.67) * math.sin(timeSeconds * 2.93)), 14).toDouble();
        final strikeB =
            math.pow(math.max(0.0, math.sin(timeSeconds * 0.41 + 1.7) * math.sin(timeSeconds * 3.71)), 18).toDouble();
        lightning = ((strikeA + strikeB * 0.8) * shaderIntensity).clamp(0.0, 1.0);
        break;
      case WeatherPhase.postStormMist:
        stormBuild = 0.16;
        if (clock.day == 1) {
          // Post-Set-8 Woodstock Mud Experience: rain cleared, warm mist over slick mud!
          wet = 0.88;
          mist = 0.42;
        } else if (clock.day == 2) {
          wet = 0.86;
          mist = 0.58;
        } else {
          final dryProgress = ((m - 300.0) / 225.0).clamp(0.0, 1.0);
          wet = (0.82 * (1.0 - dryProgress)).clamp(0.10, 0.82);
          mist = (0.85 * (1.0 - dryProgress * 0.65)).clamp(0.18, 0.85);
        }
        wind = 0.22;
        break;
      case WeatherPhase.starryFireflies:
        if (clock.day == 1 && m >= 1300.0) {
          wet = 0.72; // Mud pit puddles still glisten beneath the fireflies!
        }
        wind = 0.12;
        break;
      case WeatherPhase.purpleDustFinale:
        wind = 0.28;
        break;
    }

    // Overcast storm diffuses sharp sun shadows into soft ambient contact shadows
    final overcastDiffusion = (stormBuild * 0.78).clamp(0.0, 0.78);
    final shadowOffset = Offset(
      rawShadow.dx * (1.0 - overcastDiffusion),
      rawShadow.dy * (1.0 - overcastDiffusion * 0.35),
    );
    final shadowAlpha = rawShadowAlpha * (1.0 - overcastDiffusion * 0.38);

    // Blend storm/weather tint into astronomical sky tint
    var finalTint = skyColor;
    var finalTintStrength = skyTintAlpha;
    var finalDarkness = baseDarkness;

    if (stormBuild > 0.01) {
      final stormTint = rain > 0.5
          ? const Color(0xFF16283D)
          : const Color(0xFF354B59);
      finalTint = Color.lerp(finalTint, stormTint, (stormBuild * 0.78).clamp(0.0, 1.0))!;
      finalTintStrength =
          math.max(finalTintStrength, 0.12 + 0.20 * stormBuild);
      final stormDarkFloor = rain > 0.5 ? 0.55 : (0.10 + 0.26 * stormBuild);
      finalDarkness = math.max(
        finalDarkness + stormBuild * 0.14,
        stormDarkFloor,
      );
    }

    if (weather == WeatherPhase.purpleDustFinale) {
      finalTint = Color.lerp(finalTint, const Color(0xFF5A189A), 0.45)!;
      finalTintStrength = math.max(finalTintStrength, 0.20 + bass * 0.08);
    }

    // Lightning flash briefly lifts darkness!
    if (lightning > 0.02) {
      finalDarkness = (finalDarkness * (1.0 - lightning * 0.72)).clamp(0.04, 0.72);
    } else {
      finalDarkness = finalDarkness.clamp(0.0, 0.64);
    }

    // Sunbeams stream down during morning / post-storm mist when sun is above horizon
    var sunbeams = 0.0;
    if (mist > 0.05 && sunAlt > 0.02) {
      sunbeams = (mist * (0.45 + 0.55 * sunAlt)).clamp(0.0, 1.0);
    } else if (m >= 345.0 && m <= 470.0 && rain < 0.1 && stormBuild < 0.4) {
      sunbeams = (0.38 * (1.0 - ((m - 395.0).abs() / 75.0).clamp(0.0, 1.0)))
          .clamp(0.0, 0.38);
    }

    // Lanterns & stage glows ramp smoothly on during Golden Hour -> Dusk -> Night -> Dawn, and during dark storms!
    double lanternGlow = 0.0;
    if (m >= 1035.0) {
      lanternGlow = ((m - 1035.0) / 135.0).clamp(0.0, 1.0);
    } else if (m < 395.0) {
      lanternGlow = (1.0 - ((m - 325.0) / 70.0).clamp(0.0, 1.0)).clamp(0.0, 1.0);
    }
    if (rain > 0.2 || stormBuild > 0.55) {
      lanternGlow = math.max(lanternGlow, ((stormBuild - 0.45) * 1.8).clamp(0.0, 1.0));
    }

    final starlight = (rain < 0.2 && stormBuild < 0.5 && sunAlt < -0.15)
        ? ((-sunAlt - 0.15) / 0.65).clamp(0.0, 1.0)
        : 0.0;

    return DayNightMetrics(
      sunAltitude: sunAlt,
      shadowOffset: shadowOffset,
      shadowAlpha: shadowAlpha,
      ambientTint: finalTint,
      ambientTintStrength: finalTintStrength,
      darknessFactor: finalDarkness,
      stormBuildUp: stormBuild,
      rainIntensity: rain,
      wetness: wet,
      mistIntensity: mist,
      sunbeamIntensity: sunbeams,
      windStrength: wind,
      lightningFlash: lightning,
      starlightAlpha: starlight,
      lanternGlowStrength: lanternGlow,
    );
  }

  static (Color, double, double) _sampleSkyKeyframes(double m) {
    // Keyframes: (minute, color, tintStrength, darkness)
    const keys = <(double, Color, double, double)>[
      (300.0, Color(0xFF3B2B5C), 0.22, 0.34), // 5:00 AM Pre-Dawn Lavender
      (355.0, Color(0xFFFF9671), 0.24, 0.13), // 5:55 AM Rose-Peach Sunrise
      (425.0, Color(0xFFFFE5A3), 0.10, 0.03), // 7:05 AM Fresh Golden Morning
      (540.0, Color(0xFFFFFFFF), 0.00, 0.00), // 9:00 AM Crisp Sunlit Day
      (960.0, Color(0xFFFFF4D2), 0.04, 0.00), // 4:00 PM Warm Afternoon
      (1055.0, Color(0xFFFFA647), 0.20, 0.09), // 5:35 PM Golden Hour Start
      (1110.0, Color(0xFFFF7B39), 0.26, 0.19), // 6:30 PM Deep Sunset Amber
      (1165.0, Color(0xFF7A3B8E), 0.25, 0.35), // 7:25 PM Violet-Rose Dusk
      (1235.0, Color(0xFF1B214E), 0.18, 0.51), // 8:35 PM Deep Twilight
      (1380.0, Color(0xFF0E1433), 0.16, 0.57), // 11:00 PM Starry Midnight
      (1620.0, Color(0xFF15193D), 0.18, 0.54), // 3:00 AM Late Festival Night
      (1740.0, Color(0xFF3B2B5C), 0.22, 0.36), // 5:00 AM Wrap
    ];

    if (m <= keys.first.$1) {
      return (keys.first.$2, keys.first.$3, keys.first.$4);
    }
    for (var i = 0; i < keys.length - 1; i++) {
      final a = keys[i];
      final b = keys[i + 1];
      if (m >= a.$1 && m <= b.$1) {
        final t = ((m - a.$1) / (b.$1 - a.$1)).clamp(0.0, 1.0);
        // Smoothstep easing for silky natural sky transitions
        final s = t * t * (3.0 - 2.0 * t);
        return (
          Color.lerp(a.$2, b.$2, s)!,
          lerpDouble(a.$3, b.$3, s)!,
          lerpDouble(a.$4, b.$4, s)!,
        );
      }
    }
    return (keys.last.$2, keys.last.$3, keys.last.$4);
  }
}

/// World-space 3D light emitter that carves warm volumetric pools out of dusk/night/storm darkness.
class LightSource3D {
  const LightSource3D({
    required this.position,
    required this.radius,
    required this.color,
    this.intensity = 1.0,
  });

  final Offset position;
  final double radius;
  final Color color;
  final double intensity;
}

/// World-space weather, cloud shadows, raindrop splashes, puddle ripples, sunbeams, and fireflies.
class WorldWeatherParticlesComponent extends Component {
  WorldWeatherParticlesComponent({
    required this.map,
    required this.metricsGetter,
    required this.cameraCenterGetter,
    required this.timeGetter,
    required this.firefliesEnabledGetter,
    this.viewBoundsGetter,
    super.priority = 7500,
  });

  final OrchardMapData map;
  final DayNightMetrics Function() metricsGetter;
  final Offset Function() cameraCenterGetter;
  final double Function() timeGetter;
  final bool Function() firefliesEnabledGetter;
  final Rect Function()? viewBoundsGetter;

  @override
  void render(Canvas canvas) {
    final metrics = metricsGetter();
    final cam = cameraCenterGetter();
    final t = timeGetter();
    final viewRect = viewBoundsGetter?.call().inflate(48.0) ??
        Rect.fromCenter(center: cam, width: 720, height: 680);

    // 1. Drifting 3D Cumulus / Storm Cloud Shadows over the orchard
    final cloudAlpha = metrics.rainIntensity > 0.5
        ? 0.22
        : (metrics.stormBuildUp > 0.05
            ? 0.08 + 0.16 * metrics.stormBuildUp
            : (metrics.sunAltitude > 0.25 ? 0.055 : 0.0));
    if (cloudAlpha > 0.01) {
      final cloudSpeed = 14.0 + 34.0 * metrics.windStrength;
      final cloudPaint = Paint()
        ..color = Color.fromRGBO(12, 20, 32, cloudAlpha.clamp(0.0, 0.28))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      for (var i = 0; i < 6; i++) {
        final cx = ((i * 390.0 + t * cloudSpeed + i * 73.0) % (map.pixelWidth + 320.0)) - 160.0;
        final cy = ((i * 270.0 + math.sin(t * 0.08 + i) * 40.0 + 180.0) % map.pixelHeight);
        final cloudRect = Rect.fromCenter(
          center: Offset(cx, cy),
          width: 210.0 + (i % 3) * 65.0,
          height: 92.0 + (i % 2) * 38.0,
        );
        if (cloudRect.overlaps(viewRect.inflate(90))) {
          canvas.drawOval(cloudRect, cloudPaint);
        }
      }
    }

    // 2. Rainstorm World-Space Ground Splashes, Puddle Ripples & Wind-Whipped Leaves
    if (metrics.rainIntensity > 0.05) {
      _renderRainstormWorldDetails(canvas, viewRect, t, metrics);
    }

    // 3. Post-Storm Morning Crepuscular Sunbeams ("Sun Through the Mist")
    if (metrics.sunbeamIntensity > 0.04) {
      _renderCrepuscularSunbeams(canvas, viewRect, t, metrics.sunbeamIntensity);
    }

    // 4. Sunlit Daytime / Golden Hour Floating Orchard Pollen Spores
    if (metrics.rainIntensity < 0.05 &&
        metrics.sunAltitude > 0.08 &&
        metrics.stormBuildUp < 0.55) {
      final isGolden = metrics.sunAltitude < 0.45;
      final sporeColor = isGolden
          ? const Color(0x88FFD166)
          : const Color(0x66FFF3B0);
      final sporePaint = Paint()..color = sporeColor;
      final baseTileX = (viewRect.left / 64.0).floor();
      final baseTileY = (viewRect.top / 64.0).floor();
      final cols = (viewRect.width / 64.0).ceil() + 2;
      final rows = (viewRect.height / 64.0).ceil() + 2;
      for (var gy = 0; gy < rows; gy++) {
        for (var gx = 0; gx < cols; gx++) {
          final cellX = baseTileX + gx;
          final cellY = baseTileY + gy;
          final seed = (cellX * 73856093) ^ (cellY * 19349663);
          if ((seed & 3) != 0) continue;
          final px = cellX * 64.0 + (seed.abs() % 56) + math.sin(t * 0.9 + seed) * 9.0;
          final py = cellY * 64.0 + ((seed >> 4).abs() % 56) + math.cos(t * 0.7 + seed) * 6.0;
          if (viewRect.contains(Offset(px, py))) {
            canvas.drawCircle(Offset(px, py), 1.1, sporePaint);
          }
        }
      }
    }

    // 5. World-Space Bioluminescent Dusk/Night Fireflies
    if (firefliesEnabledGetter() && metrics.rainIntensity < 0.25) {
      final glowPaint = Paint()
        ..color = const Color(0x559EF01A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      final corePaint = Paint()..color = const Color(0xEECCFF33);
      final baseCellX = (viewRect.left / 72.0).floor();
      final baseCellY = (viewRect.top / 72.0).floor();
      final cols = (viewRect.width / 72.0).ceil() + 2;
      final rows = (viewRect.height / 72.0).ceil() + 2;
      for (var gy = 0; gy < rows; gy++) {
        for (var gx = 0; gx < cols; gx++) {
          final cx = baseCellX + gx;
          final cy = baseCellY + gy;
          final seed = (cx * 83492791) ^ (cy * 2971215073);
          if ((seed & 1) != 0) continue;
          final pulse = 0.5 + 0.5 * math.sin(t * 2.4 + (seed % 17));
          if (pulse < 0.25) continue;
          final fx = cx * 72.0 + (seed.abs() % 60) + math.sin(t * 0.85 + seed) * 14.0;
          final fy = cy * 72.0 + ((seed >> 5).abs() % 60) + math.cos(t * 0.65 + seed) * 11.0;
          final pos = Offset(fx, fy);
          if (viewRect.contains(pos)) {
            canvas.drawCircle(pos, 4.2 * pulse, glowPaint);
            canvas.drawCircle(pos, 1.3, corePaint);
          }
        }
      }
    }
  }

  void _renderRainstormWorldDetails(
    Canvas canvas,
    Rect viewRect,
    double t,
    DayNightMetrics metrics,
  ) {
    final ripplePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85;
    final splashPaint = Paint()
      ..color = Color.fromRGBO(205, 234, 255, 0.55 * metrics.rainIntensity)
      ..strokeWidth = 0.9;
    final streakPaint = Paint()
      ..color = Color.fromRGBO(185, 222, 255, 0.34 * metrics.rainIntensity)
      ..strokeWidth = 0.85;

    // Deterministic world-locked puddle ripples & splash crowns so they stay anchored to the ground!
    final startCellX = (viewRect.left / 40.0).floor();
    final startCellY = (viewRect.top / 40.0).floor();
    final cols = (viewRect.width / 40.0).ceil() + 1;
    final rows = (viewRect.height / 40.0).ceil() + 1;
    for (var gy = 0; gy <= rows; gy++) {
      for (var gx = 0; gx <= cols; gx++) {
        final cx = startCellX + gx;
        final cy = startCellY + gy;
        final seed = ((cx * 92837111) ^ (cy * 689287499)).abs();
        final wx = cx * 40.0 + (seed % 34) + 3.0;
        final wy = cy * 40.0 + ((seed >> 6) % 34) + 3.0;
        if (!viewRect.contains(Offset(wx, wy))) continue;

        final cycle = (t * (1.5 + (seed % 5) * 0.22) + (seed % 100) * 0.01) % 1.0;
        final surface = map.surfaceAtWorld(wx, wy);
        final isWetPool = surface == 'mud' || surface == 'dirt' || surface == 'asphalt';

        if (isWetPool) {
          // Concentric 3D foreshortened puddle ring!
          final r = 1.5 + cycle * 7.5;
          final alpha = (1.0 - cycle) * 0.52 * metrics.rainIntensity;
          ripplePaint.color = Color.fromRGBO(196, 228, 255, alpha.clamp(0.0, 0.6));
          canvas.drawOval(
            Rect.fromCenter(center: Offset(wx, wy), width: r * 2.1, height: r * 1.05),
            ripplePaint,
          );
        } else if ((seed & 1) == 0 && cycle < 0.35) {
          // Tiny V-shaped raindrop ground splash crown on grass/wood!
          final pop = (cycle / 0.35);
          final h = 2.6 * math.sin(pop * math.pi);
          canvas.drawLine(Offset(wx, wy), Offset(wx - 2.0 * pop, wy - h), splashPaint);
          canvas.drawLine(Offset(wx, wy), Offset(wx + 2.0 * pop, wy - h), splashPaint);
        }
      }
    }

    // World-space slanted 3D rain streaks & wind-blown orchard leaves
    for (var i = 0; i < 32; i++) {
      final rx = viewRect.left + ((i * 47.0 - t * 145.0) % viewRect.width).abs();
      final ry = viewRect.top + ((i * 31.0 + t * 320.0) % viewRect.height).abs();
      canvas.drawLine(Offset(rx, ry), Offset(rx - 5.5, ry + 13.5), streakPaint);
    }

    final leafPaint = Paint()..color = const Color(0xCC588157);
    for (var i = 0; i < 6; i++) {
      final lx = viewRect.right - ((i * 97.0 + t * 115.0) % (viewRect.width + 40.0));
      final ly = viewRect.top + ((i * 53.0 + t * 58.0 + math.sin(t * 4.0 + i) * 8.0) % viewRect.height);
      canvas.save();
      canvas.translate(lx, ly);
      canvas.rotate(t * 5.0 + i);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 4.5, height: 2.2),
        leafPaint,
      );
      canvas.restore();
    }
  }

  void _renderCrepuscularSunbeams(
    Canvas canvas,
    Rect viewRect,
    double t,
    double intensity,
  ) {
    canvas.save();
    for (var i = 0; i < 5; i++) {
      final pulse = 0.65 + 0.35 * math.sin(t * 0.55 + i * 1.4);
      final alpha = (0.09 * intensity * pulse).clamp(0.0, 0.16);
      final xStart = viewRect.left + 40.0 + i * 115.0 + math.sin(t * 0.2 + i) * 18.0;
      final path = Path()
        ..moveTo(xStart - 26.0, viewRect.top - 20.0)
        ..lineTo(xStart + 22.0, viewRect.top - 20.0)
        ..lineTo(xStart + 135.0, viewRect.bottom + 20.0)
        ..lineTo(xStart + 55.0, viewRect.bottom + 20.0)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = Color.fromRGBO(255, 238, 168, alpha)
          ..blendMode = BlendMode.plus
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
    canvas.restore();
  }
}

/// Renders continuous Day/Night/Storm sky color grade + darkness layer with punched-out 3D light pools.
class DayNightLightmapComponent extends Component {
  DayNightLightmapComponent({
    required this.metricsGetter,
    required this.cameraCenterGetter,
    required this.lightsGetter,
    this.viewBoundsGetter,
    super.priority = 9400,
  });

  final DayNightMetrics Function() metricsGetter;
  final Offset Function() cameraCenterGetter;
  final List<LightSource3D> Function(Rect visibleWorldRect) lightsGetter;
  final Rect Function()? viewBoundsGetter;

  @override
  void render(Canvas canvas) {
    final metrics = metricsGetter();
    final cam = cameraCenterGetter();
    final bounds = viewBoundsGetter?.call().inflate(100.0) ??
        Rect.fromCenter(center: cam, width: 780, height: 740);

    // 1. Warm Dawn / Golden Hour / Humid Storm atmospheric tint wash
    if (metrics.ambientTintStrength > 0.01) {
      final tintAlpha = (metrics.ambientTintStrength * 0.52).clamp(0.0, 0.28);
      canvas.drawRect(
        bounds,
        Paint()
          ..color = metrics.ambientTint.withValues(alpha: tintAlpha)
          ..blendMode = BlendMode.srcOver,
      );
    }

    // 2. Darkness veil with punched-out 3D light pools (Dusk, Night, Pre-Storm, Rainstorm)
    final visibleLights = lightsGetter(bounds.inflate(140.0));
    if (metrics.darknessFactor > 0.015) {
      canvas.saveLayer(bounds, Paint());

      final darkBase = Color.lerp(
        const Color(0xFF0A0F29),
        metrics.ambientTint,
        0.28,
      )!;
      canvas.drawRect(
        bounds,
        Paint()..color = darkBase.withValues(alpha: metrics.darknessFactor),
      );

      // Punch smooth radial pools out of the darkness around lanterns, stages, headlights & altars!
      for (final light in visibleLights) {
        if (light.intensity <= 0.02 || light.radius <= 2.0) continue;
        final punchAlpha = (0.88 * light.intensity).clamp(0.0, 0.94);
        final grad = Gradient.radial(
          light.position,
          light.radius,
          <Color>[
            Color.fromRGBO(0, 0, 0, punchAlpha),
            Color.fromRGBO(0, 0, 0, punchAlpha * 0.45),
            const Color.fromRGBO(0, 0, 0, 0.0),
          ],
          const <double>[0.0, 0.52, 1.0],
        );
        canvas.drawCircle(
          light.position,
          light.radius,
          Paint()
            ..shader = grad
            ..blendMode = BlendMode.dstOut,
        );
      }

      canvas.restore();
    }

    // 3. Warm colored 3D additive light bloom halos around active emitters
    if (metrics.lanternGlowStrength > 0.04 || metrics.darknessFactor > 0.06) {
      final haloScale =
          math.max(metrics.lanternGlowStrength, metrics.darknessFactor * 1.35)
              .clamp(0.0, 1.0);
      for (final light in visibleLights) {
        if (light.intensity <= 0.02) continue;
        final a = (0.24 * light.intensity * haloScale).clamp(0.0, 0.36);
        if (a <= 0.01) continue;
        final haloGrad = Gradient.radial(
          light.position,
          light.radius * 0.85,
          <Color>[
            light.color.withValues(alpha: a),
            light.color.withValues(alpha: a * 0.32),
            light.color.withValues(alpha: 0.0),
          ],
          const <double>[0.0, 0.48, 1.0],
        );
        canvas.drawCircle(
          light.position,
          light.radius * 0.85,
          Paint()
            ..shader = haloGrad
            ..blendMode = BlendMode.plus,
        );
      }
    }

    // 4. Dramatic Rainstorm Lightning Flash Veil
    if (metrics.lightningFlash > 0.03) {
      canvas.drawRect(
        bounds,
        Paint()
          ..color = Color.fromRGBO(
            215,
            234,
            255,
            (metrics.lightningFlash * 0.34).clamp(0.0, 0.40),
          )
          ..blendMode = BlendMode.plus,
      );
    }
  }
}
