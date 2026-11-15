import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// Laid over a receipt photo while it is being read: the photo dims a little
/// and a thin line sweeps down it. With "reduce motion" on, the line stays
/// still and only the dimming remains, so the state is still visible.
class ScanSweep extends StatefulWidget {
  const ScanSweep({super.key});

  @override
  State<ScanSweep> createState() => _ScanSweepState();
}

class _ScanSweepState extends State<ScanSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      label: 'Reading your receipt',
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: ColoredBox(
            color: c.background.withValues(alpha: 0.35),
            child: LayoutBuilder(
              builder: (context, box) => AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final y = Curves.easeInOut.transform(_controller.value);
                  return Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: (box.maxHeight - 2) * y,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: c.ink,
                            boxShadow: [
                              BoxShadow(
                                color: c.ink.withValues(alpha: 0.35),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
