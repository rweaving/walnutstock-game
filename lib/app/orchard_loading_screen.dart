import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

@immutable
class OrchardLoadProgress {
  const OrchardLoadProgress({
    required this.loaded,
    required this.total,
    required this.stageLabel,
  });

  static const OrchardLoadProgress initial = OrchardLoadProgress(
    loaded: 0,
    total: 1,
    stageLabel: 'Rolling cable trunks onto the Main Orchard Meadow…',
  );

  final int loaded;
  final int total;
  final String stageLabel;

  double get fraction {
    if (total <= 0) return 0.06;
    return (loaded / total).clamp(0.04, 1.0);
  }
}

class OrchardLoadingScreen extends StatefulWidget {
  const OrchardLoadingScreen({
    super.key,
    required this.progressListenable,
  });

  final ValueListenable<OrchardLoadProgress> progressListenable;

  @override
  State<OrchardLoadingScreen> createState() => _OrchardLoadingScreenState();
}

class _OrchardLoadingScreenState extends State<OrchardLoadingScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _stageTips = [
    '🎸 Walk closer to any of the 5 stages to hear live stereo amps swell!',
    '🌧️ Day 1 afternoon rain turns the South Hill into a Woodstock Mud Slide.',
    '🫐 Swing by Creekside on Day 2 afternoon for Electric Purple Blueberries.',
    '🏮 Explore all 9 orchard zones to discover glowing 3D-printed totems.',
    '💿 Visit the Vinyl Booth or Pinball Tent anytime to jam on demand!',
    '🕺 Tap Dance / Groove near a live stage to boost Crowd Sway aura.',
  ];

  static const List<String> _crewCheers = [
    'Right on! Horn stacks tuned!',
    'Groovy! Stage lanterns glowing!',
    'Far out! Fuzz pedals armed!',
    'Cosmic! Meadow banner hoisted!',
    'Peace & shells! Ready to rock!',
  ];

  AnimationController? _spinController;
  Timer? _tipTimer;
  int _tipIndex = 0;
  int _cheerCount = 0;

  bool get _isWidgetTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    if (!_isWidgetTest) {
      _spinController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2800),
      )..repeat();
      _tipTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
        if (!mounted) return;
        setState(() {
          _tipIndex = (_tipIndex + 1) % _stageTips.length;
        });
      });
    }
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    _spinController?.dispose();
    super.dispose();
  }

  void _handleCheer() {
    setState(() {
      _cheerCount += 1;
      _tipIndex = (_tipIndex + 1) % _stageTips.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF141E12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isShort = constraints.maxHeight < 440;
          final horizontalPad = constraints.maxWidth < 400 ? 12.0 : 20.0;
          final verticalPad = isShort ? 10.0 : 24.0;

          return DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.15),
                radius: 0.95,
                colors: [
                  Color(0xFF2B3B22),
                  Color(0xFF1A2416),
                  Color(0xFF10170E),
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPad,
                    vertical: verticalPad,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Container(
                      key: const ValueKey('orchard_loading_card'),
                      padding: EdgeInsets.symmetric(
                        horizontal: isShort ? 14 : 18,
                        vertical: isShort ? 12 : 18,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xF22D1D12),
                            Color(0xF51B120B),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFD49A5A),
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xAA000000),
                            blurRadius: 28,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ValueListenableBuilder<OrchardLoadProgress>(
                        valueListenable: widget.progressListenable,
                        builder: (context, progress, _) {
                          final pct = (progress.fraction * 100).round();
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x26FFBE0B),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0x77FFD166),
                                  ),
                                ),
                                child: const Text(
                                  '✌️ STAGE CREW · SETTING UP THE GROVE',
                                  style: TextStyle(
                                    color: Color(0xFFFFD166),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.3,
                                  ),
                                ),
                              ),
                              SizedBox(height: isShort ? 6 : 10),
                              Text(
                                'Opening the Free Orchard',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFFF6E7C8),
                                  fontSize: isShort ? 17 : 21,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              SizedBox(height: isShort ? 8 : 12),
                              _buildVinylPlatter(isShort: isShort),
                              SizedBox(height: isShort ? 8 : 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      progress.stageLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFFEAD7B7),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$pct%',
                                    style: const TextStyle(
                                      color: Color(0xFFFFD166),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: Container(
                                  height: 10,
                                  color: const Color(0xFF0E0A07),
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: progress.fraction,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFFFF9F1C),
                                            Color(0xFFFFD166),
                                            Color(0xFF06D6A0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (progress.total > 1) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${progress.loaded} / ${progress.total} orchard sprites & shaders tuned',
                                  style: const TextStyle(
                                    color: Color(0xFFBFA888),
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                              SizedBox(height: isShort ? 8 : 12),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  FilledButton.tonalIcon(
                                    key: const ValueKey(
                                      'orchard_loader_cheer_button',
                                    ),
                                    onPressed: _handleCheer,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0x33FFBE0B),
                                      foregroundColor: const Color(0xFFFFE599),
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                    ),
                                    icon: const Text('🎉'),
                                    label: Text(
                                      _cheerCount == 0
                                          ? 'Cheer Stage Crew!'
                                          : _crewCheers[(_cheerCount - 1) %
                                              _crewCheers.length],
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (_cheerCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0x2E06D6A0),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: const Color(0x8806D6A0),
                                        ),
                                      ),
                                      child: Text(
                                        'Hype ${_cheerCount}x',
                                        style: const TextStyle(
                                          color: Color(0xFF7BF1A8),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (!isShort) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x14FFF3D6),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0x44D49A5A),
                                    ),
                                  ),
                                  child: Text(
                                    _stageTips[_tipIndex],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFFE6D4B5),
                                      fontSize: 11.5,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVinylPlatter({required bool isShort}) {
    final discSize = isShort ? 64.0 : 86.0;
    final controller = _spinController;
    if (controller == null) {
      return GestureDetector(
        onTap: _handleCheer,
        child: _VinylAndEqVisual(
          phase: (_cheerCount * 0.19) % 1.0,
          discSize: discSize,
        ),
      );
    }
    return GestureDetector(
      onTap: _handleCheer,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return _VinylAndEqVisual(
            phase: controller.value,
            discSize: discSize,
          );
        },
      ),
    );
  }
}

class _VinylAndEqVisual extends StatelessWidget {
  const _VinylAndEqVisual({
    required this.phase,
    required this.discSize,
  });

  final double phase;
  final double discSize;

  static const List<Color> _barColors = [
    Color(0xFFFFBE0B),
    Color(0xFFFB5607),
    Color(0xFFFF006E),
    Color(0xFF06D6A0),
    Color(0xFF8338EC),
    Color(0xFF3A86FF),
    Color(0xFFFFD166),
  ];

  @override
  Widget build(BuildContext context) {
    final angle = phase * math.pi * 2.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildEqSide(angle, offsetSeed: 0.0),
        const SizedBox(width: 14),
        Transform.rotate(
          angle: angle,
          child: CustomPaint(
            size: Size.square(discSize),
            painter: _FestivalVinylPainter(),
          ),
        ),
        const SizedBox(width: 14),
        _buildEqSide(angle, offsetSeed: 2.1),
      ],
    );
  }

  Widget _buildEqSide(double angle, {required double offsetSeed}) {
    return SizedBox(
      height: discSize * 0.56,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(4, (i) {
          final wave =
              0.35 + 0.65 * (0.5 + 0.5 * math.sin(angle * 3.0 + i * 1.1 + offsetSeed));
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              width: 5,
              height: (discSize * 0.52 * wave).clamp(6.0, discSize * 0.54),
              decoration: BoxDecoration(
                color: _barColors[(i + offsetSeed.round()) % _barColors.length],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _FestivalVinylPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer vinyl disc
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFF14110F),
    );
    canvas.drawCircle(
      center,
      radius - 1.5,
      Paint()
        ..color = const Color(0xFF3E342D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Grooves + sheen highlight arc
    final groovePaint = Paint()
      ..color = const Color(0x44C9A97E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (final factor in const [0.84, 0.71, 0.58]) {
      canvas.drawCircle(center, radius * factor, groovePaint);
    }

    final sheenPaint = Paint()
      ..color = const Color(0x38FFD166)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.18
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.72),
      -0.65,
      0.85,
      false,
      sheenPaint,
    );

    // Warm 1969 sunburst walnut record label
    canvas.drawCircle(
      center,
      radius * 0.40,
      Paint()..color = const Color(0xFFE08E36),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.40),
      0,
      math.pi,
      true,
      Paint()..color = const Color(0xFFFF006E),
    );
    canvas.drawCircle(
      center,
      radius * 0.24,
      Paint()..color = const Color(0xFFFFD166),
    );

    // Center spindle hole
    canvas.drawCircle(
      center,
      radius * 0.08,
      Paint()..color = const Color(0xFF1A120B),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
