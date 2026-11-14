import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

enum OrchardShaderKind {
  none,
  walnutTrip,
  purpleHaze,
  nebula,
  preStormOvercast,
  rainstorm,
  morningMist,
  electricBlueberry,
}

class ShaderPostProcessor {
  final Map<String, FragmentProgram> _programs = {};
  final Map<String, FragmentShader> _cachedShaders = {};
  bool _loadedAttempted = false;

  /// Builds a centered, slightly overscanned 2D sinusoidal wave affine transform
  /// (`Float64List` 4x4 column-major matrix for `Canvas.transform`) so world tiles,
  /// stages, walnut actors, and trees gently undulate when Electric Purple Blueberries are active!
  static Float64List buildLiquidWaveMatrix({
    required Size viewportSize,
    required double timeSeconds,
    required double intensity,
    required double bass,
  }) {
    final eff = intensity.clamp(0.0, 1.0);
    final cx = viewportSize.width * 0.5;
    final cy = viewportSize.height * 0.5;

    final scaleX =
        1.0 + (0.068 + 0.018 * math.sin(timeSeconds * 2.1) + 0.016 * bass) * eff;
    final scaleY =
        1.0 + (0.068 + 0.018 * math.cos(timeSeconds * 1.7) + 0.016 * bass) * eff;
    final skewX = math.sin(timeSeconds * 2.35) * 0.052 * eff;
    final skewY = math.cos(timeSeconds * 1.85) * 0.042 * eff;
    final rot = math.sin(timeSeconds * 1.35) * 0.026 * eff;
    final driftX = math.sin(timeSeconds * 1.9) * 3.4 * eff;
    final driftY = math.cos(timeSeconds * 1.5) * 2.6 * eff;

    final cosR = math.cos(rot);
    final sinR = math.sin(rot);

    // Combined 2x2 linear part L = R(rot) * Shear(skewX, skewY) * Scale(scaleX, scaleY)
    final s00 = scaleX;
    final s01 = skewX * scaleY;
    final s10 = skewY * scaleX;
    final s11 = scaleY;

    final m00 = cosR * s00 - sinR * s10;
    final m01 = cosR * s01 - sinR * s11;
    final m10 = sinR * s00 + cosR * s10;
    final m11 = sinR * s01 + cosR * s11;

    final tx = cx - (m00 * cx + m01 * cy) + driftX;
    final ty = cy - (m10 * cx + m11 * cy) + driftY;

    return Float64List.fromList(<double>[
      m00, m10, 0.0, 0.0, // col 0
      m01, m11, 0.0, 0.0, // col 1
      0.0, 0.0, 1.0, 0.0, // col 2
      tx, ty, 0.0, 1.0, // col 3
    ]);
  }

  /// Builds a luminance-preserving 360-degree rainbow hue rotation + chroma-boost
  /// `ColorFilter.matrix` so the entire orchard cycles smoothly through ROYGBIV colors!
  static ColorFilter buildRainbowHueColorFilter({
    required double timeSeconds,
    required double intensity,
    required double bass,
  }) {
    final eff = intensity.clamp(0.0, 1.0);
    final blend = (0.82 * eff).clamp(0.0, 0.94);
    final theta = timeSeconds * 1.25 + bass * 0.48;
    final cosT = math.cos(theta);
    final sinT = math.sin(theta);

    // Luminance-preserving hue rotation H(theta)
    final h00 = 0.213 + 0.787 * cosT - 0.213 * sinT;
    final h01 = 0.715 - 0.715 * cosT - 0.715 * sinT;
    final h02 = 0.072 - 0.072 * cosT + 0.928 * sinT;

    final h10 = 0.213 - 0.213 * cosT + 0.143 * sinT;
    final h11 = 0.715 + 0.285 * cosT + 0.140 * sinT;
    final h12 = 0.072 - 0.072 * cosT - 0.283 * sinT;

    final h20 = 0.213 - 0.213 * cosT - 0.787 * sinT;
    final h21 = 0.715 - 0.715 * cosT + 0.715 * sinT;
    final h22 = 0.072 + 0.928 * cosT + 0.072 * sinT;

    // Chroma boost S(sat) * H(theta)
    final sat = 1.0 + 0.34 * eff + 0.12 * bass * eff;
    const wr = 0.213;
    const wg = 0.715;
    const wb = 0.072;

    double rowMix(double r, double g, double b, double own) {
      final luma = wr * r + wg * g + wb * b;
      return luma + sat * (own - luma);
    }

    final r0 = rowMix(h00, h10, h20, h00);
    final r1 = rowMix(h01, h11, h21, h01);
    final r2 = rowMix(h02, h12, h22, h02);

    final g0 = rowMix(h00, h10, h20, h10);
    final g1 = rowMix(h01, h11, h21, h11);
    final g2 = rowMix(h02, h12, h22, h12);

    final b0 = rowMix(h00, h10, h20, h20);
    final b1 = rowMix(h01, h11, h21, h21);
    final b2 = rowMix(h02, h12, h22, h22);

    double lerpId(double diag, double target) =>
        diag + (target - diag) * blend;

    // Subtle electric-purple / prismatic glow lift
    final liftR = (8.0 + 6.0 * math.sin(theta)) * blend;
    final liftG = (4.0 + 5.0 * math.sin(theta + 2.09)) * blend;
    final liftB = (12.0 + 6.0 * math.cos(theta)) * blend;

    return ColorFilter.matrix(<double>[
      lerpId(1.0, r0), lerpId(0.0, r1), lerpId(0.0, r2), 0.0, liftR,
      lerpId(0.0, g0), lerpId(1.0, g1), lerpId(0.0, g2), 0.0, liftG,
      lerpId(0.0, b0), lerpId(0.0, b1), lerpId(1.0, b2), 0.0, liftB,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ]);
  }

  Future<void> preloadShaders() async {
    if (_loadedAttempted) return;
    _loadedAttempted = true;
    const assets = <String, String>{
      'walnut_trip': 'shaders/walnut_trip.frag',
      'purple_haze': 'shaders/purple_haze.frag',
      'nebula': 'shaders/nebula.frag',
      'rain_mist': 'shaders/rain_mist.frag',
      'electric_blueberry': 'shaders/electric_blueberry.frag',
    };
    for (final entry in assets.entries) {
      try {
        final program = await FragmentProgram.fromAsset(entry.value);
        _programs[entry.key] = program;
        _cachedShaders[entry.key] = program.fragmentShader();
      } catch (_) {
        // Headless test runners or legacy software canvases use our smooth Canvas fallback
      }
    }
  }

  void dispose() {
    for (final s in _cachedShaders.values) {
      s.dispose();
    }
    _cachedShaders.clear();
  }

  void renderViewportOverlay({
    required Canvas canvas,
    required Size viewportSize,
    required OrchardShaderKind kind,
    required double timeSeconds,
    required double intensity,
    required double bass,
    required double mid,
    double rainRamp = 0.0,
  }) {
    if (kind == OrchardShaderKind.none ||
        intensity <= 0.01 ||
        viewportSize.width <= 1.0 ||
        viewportSize.height <= 1.0) {
      return;
    }

    final programKey = switch (kind) {
      OrchardShaderKind.walnutTrip => 'walnut_trip',
      OrchardShaderKind.purpleHaze => 'purple_haze',
      OrchardShaderKind.nebula => 'nebula',
      OrchardShaderKind.electricBlueberry => 'electric_blueberry',
      OrchardShaderKind.preStormOvercast ||
      OrchardShaderKind.rainstorm ||
      OrchardShaderKind.morningMist =>
        'rain_mist',
      OrchardShaderKind.none => '',
    };

    final program = _programs[programKey];
    if (program != null) {
      final shader = _cachedShaders[programKey] ??= program.fragmentShader();
      final effectiveMid = switch (kind) {
        OrchardShaderKind.rainstorm => 0.90,
        OrchardShaderKind.preStormOvercast =>
          0.52 + 0.36 * rainRamp.clamp(0.0, 1.0),
        OrchardShaderKind.morningMist => 0.15,
        _ => mid,
      };
      shader
        ..setFloat(0, viewportSize.width)
        ..setFloat(1, viewportSize.height)
        ..setFloat(2, timeSeconds)
        ..setFloat(3, intensity.clamp(0.0, 1.0))
        ..setFloat(4, bass.clamp(0.0, 1.0))
        ..setFloat(5, effectiveMid.clamp(0.0, 1.0));

      canvas.drawRect(
        Offset.zero & viewportSize,
        Paint()..shader = shader,
      );
      return;
    }

    // Graceful procedural Canvas fallback if FragmentProgram is unavailable
    _renderCanvasFallback(
      canvas: canvas,
      size: viewportSize,
      kind: kind,
      time: timeSeconds,
      intensity: intensity,
      bass: bass,
      rainRamp: rainRamp,
    );
  }

  void _renderCanvasFallback({
    required Canvas canvas,
    required Size size,
    required OrchardShaderKind kind,
    required double time,
    required double intensity,
    required double bass,
    double rainRamp = 0.0,
  }) {
    final rect = Offset.zero & size;
    switch (kind) {
      case OrchardShaderKind.walnutTrip:
        canvas.drawRect(
          rect,
          Paint()
            ..color = Color.fromRGBO(
              (160 + 80 * math.sin(time * 1.5)).round(),
              (90 + 90 * math.cos(time * 1.1)).round(),
              210,
              (0.18 * intensity).clamp(0.0, 0.35),
            ),
        );
        break;
      case OrchardShaderKind.purpleHaze:
        canvas.drawRect(
          rect,
          Paint()
            ..color = Color.fromRGBO(
              138,
              43,
              226,
              ((0.20 + 0.12 * bass) * intensity).clamp(0.0, 0.42),
            ),
        );
        break;
      case OrchardShaderKind.nebula:
        canvas.drawRect(
          rect,
          Paint()
            ..color = Color.fromRGBO(
              48,
              24,
              110,
              (0.22 * intensity).clamp(0.0, 0.38),
            ),
        );
        break;
      case OrchardShaderKind.preStormOvercast:
        canvas.drawRect(
          rect,
          Paint()
            ..color = Color.fromRGBO(
              42,
              58,
              74,
              ((0.15 + 0.08 * rainRamp) * intensity).clamp(0.0, 0.30),
            ),
        );
        if (rainRamp > 0.06) {
          final rampStreakPaint = Paint()
            ..color = Color.fromRGBO(
              180,
              216,
              250,
              (0.36 * rainRamp * intensity).clamp(0.0, 0.45),
            )
            ..strokeWidth = 1.05;
          final dropCount = (8 + 16 * rainRamp).round();
          for (var i = 0; i < dropCount; i++) {
            final rx =
                ((i * 47.0 - time * (60.0 + 45.0 * rainRamp)) % (size.width + 40))
                        .abs() -
                    20;
            final ry =
                ((i * 33.0 + time * (170.0 + 110.0 * rainRamp)) % size.height)
                    .abs();
            canvas.drawLine(
              Offset(rx, ry),
              Offset(rx - 6 * rainRamp - 2, ry + 10 + 7 * rainRamp),
              rampStreakPaint,
            );
          }
        }
        break;
      case OrchardShaderKind.rainstorm:
        canvas.drawRect(
          rect,
          Paint()
            ..color = Color.fromRGBO(
              22,
              36,
              58,
              (0.22 * intensity).clamp(0.0, 0.36),
            ),
        );
        final farPaint = Paint()
          ..color =
              Color.fromRGBO(155, 195, 235, (0.24 * intensity).clamp(0.0, 0.4))
          ..strokeWidth = 0.9;
        final nearPaint = Paint()
          ..color =
              Color.fromRGBO(205, 232, 255, (0.42 * intensity).clamp(0.0, 0.6))
          ..strokeWidth = 1.4;
        for (var i = 0; i < 24; i++) {
          final fx = ((i * 41.0 - time * 65.0) % (size.width + 40)).abs() - 20;
          final fy = ((i * 31.0 + time * 190.0) % size.height).abs();
          canvas.drawLine(Offset(fx, fy), Offset(fx - 5, fy + 11), farPaint);

          final nx = ((i * 53.0 - time * 110.0) % (size.width + 50)).abs() - 25;
          final ny = ((i * 29.0 + time * 310.0) % size.height).abs();
          canvas.drawLine(Offset(nx, ny), Offset(nx - 9, ny + 19), nearPaint);
        }
        break;
      case OrchardShaderKind.morningMist:
        canvas.drawRect(
          rect,
          Paint()
            ..color = Color.fromRGBO(
                255, 248, 220, (0.14 * intensity).clamp(0.0, 0.25)),
        );
        break;
      case OrchardShaderKind.electricBlueberry:
        // Flowing 6-ribbon sinusoidal ROYGBIV rainbow liquid waves + electric-purple aura
        const bandColors = <Color>[
          Color(0xFFFF3366), // Electric Raspberry
          Color(0xFFFF9E00), // Tangerine Sun
          Color(0xFFFFEA00), // Lemon Glow
          Color(0xFF00F5D4), // Creek Mint-Aqua
          Color(0xFF3A86FF), // Electric Sky
          Color(0xFF9D4EDD), // Electric Purple Blueberry
        ];
        final alpha = ((0.14 + 0.08 * bass) * intensity).clamp(0.0, 0.30);
        for (var b = 0; b < bandColors.length; b++) {
          final path = Path();
          final baseY = (size.height / bandColors.length) * (b + 0.5);
          final phase = time * 2.2 + b * 0.95;
          final amp = 14.0 + 10.0 * bass;
          path.moveTo(0, baseY + math.sin(phase) * amp);
          for (var x = 24.0; x <= size.width + 24.0; x += 24.0) {
            final y = baseY +
                math.sin(x * 0.022 + phase) * amp +
                math.cos(x * 0.011 - time * 1.6) * 6.0;
            path.lineTo(x, y);
          }
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = (size.height / bandColors.length) * 0.72
              ..color = bandColors[b].withValues(alpha: alpha),
          );
        }
        break;
      case OrchardShaderKind.none:
        break;
    }
  }
}
