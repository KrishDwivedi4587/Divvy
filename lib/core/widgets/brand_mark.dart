import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// The Divvy mark: two overlapping circles with a clean gap between them,
/// drawn in code so it follows light and dark mode and stays sharp at any size.
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 28, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = size * 0.72;
    final gap = size * 0.06;
    return Semantics(
      label: 'Divvy',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: d,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _Circle(diameter: d, color: c.ink),
            // The gap: a background-coloured circle just larger than the right
            // one, which cuts a crescent out of the left circle.
            Positioned(
              left: size - d - gap,
              top: -gap,
              child: _Circle(diameter: d + 2 * gap, color: c.background),
            ),
            Positioned(
              left: size - d,
              child: _Circle(diameter: d, color: c.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
