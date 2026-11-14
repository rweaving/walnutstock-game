import 'dart:async';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/dialogue_and_overlay_state.dart';
import '../state/providers.dart';

class DialogueBoxOverlay extends ConsumerStatefulWidget {
  const DialogueBoxOverlay({
    super.key,
    required this.session,
    required this.onAdvance,
  });

  final DialogueSession session;
  final VoidCallback onAdvance;

  @override
  ConsumerState<DialogueBoxOverlay> createState() => _DialogueBoxOverlayState();
}

class _DialogueBoxOverlayState extends ConsumerState<DialogueBoxOverlay> {
  Timer? _typeTimer;
  int _visibleChars = 0;

  @override
  void initState() {
    super.initState();
    _startTypewriter();
  }

  @override
  void didUpdateWidget(covariant DialogueBoxOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.pageIndex != widget.session.pageIndex ||
        oldWidget.session.speakerName != widget.session.speakerName) {
      _startTypewriter();
    }
  }

  void _startTypewriter() {
    _typeTimer?.cancel();
    final full = widget.session.currentLine;
    final speed = ref.read(settingsProvider).textSpeedMultiplier;
    if (speed >= 2.2) {
      setState(() => _visibleChars = full.length);
      return;
    }
    setState(() => _visibleChars = 0);
    final msPerChar = (18 / speed).round().clamp(6, 40);
    _typeTimer = Timer.periodic(Duration(milliseconds: msPerChar), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_visibleChars >= full.length) {
        t.cancel();
      } else {
        setState(
            () => _visibleChars = (_visibleChars + 2).clamp(0, full.length));
      }
    });
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    final full = widget.session.currentLine;
    if (_visibleChars < full.length) {
      _typeTimer?.cancel();
      setState(() => _visibleChars = full.length);
      return;
    }
    widget.onAdvance();
  }

  @override
  Widget build(BuildContext context) {
    final fullLine = widget.session.currentLine;
    final shown =
        fullLine.substring(0, _visibleChars.clamp(0, fullLine.length));
    final screen = MediaQuery.sizeOf(context);
    final isTouchCompact = screen.shortestSide < 560;
    final portraitBox = isTouchCompact ? 54.0 : 64.0;

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isTouchCompact ? 12 : 16,
            8,
            isTouchCompact ? 12 : 16,
            isTouchCompact ? 16 : 26,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 680,
              maxHeight: (screen.height * 0.45).clamp(150.0, 280.0),
            ),
            child: GestureDetector(
              key: const ValueKey('dialogue_box_card'),
              behavior: HitTestBehavior.opaque,
              onTap: _handleTap,
              child: Container(
                padding: EdgeInsets.all(isTouchCompact ? 12 : 14),
                decoration: BoxDecoration(
                  color: const Color(0xF523170E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFFFD166),
                    width: 2.5,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black87, blurRadius: 18),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: portraitBox,
                      height: portraitBox,
                      decoration: BoxDecoration(
                        color: const Color(0xFF140D08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD49A5A)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          widget.session.portraitAsset,
                          filterQuality: FilterQuality.none,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    SizedBox(width: isTouchCompact ? 10 : 14),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${widget.session.speakerName} · ${widget.session.speakerTitle}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFFFD166),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.session.hasNextPage
                                      ? (isTouchCompact
                                          ? '▼ TAP'
                                          : '▼ NEXT [E]')
                                      : (isTouchCompact
                                          ? '✓ DONE'
                                          : '✓ DONE [E]'),
                                  style: const TextStyle(
                                    color: Color(0xFF80FFDB),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              shown,
                              style: const TextStyle(
                                color: Color(0xFFF4E3C1),
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
