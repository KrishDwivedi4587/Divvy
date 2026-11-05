import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// The Divvy mark: two overlapping circles, one solid and one outlined, drawn
/// in code so it follows light and dark mode and stays sharp at any size.
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 28, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = size * 0.72;
    return Semantics(
      label: 'Divvy',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: d,
        child: Stack(
          children: [
            Container(
              width: d,
              height: d,
              decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
            ),
            Positioned(
              left: size - d,
              child: Container(
                width: d,
                height: d,
                decoration: BoxDecoration(
                  color: c.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.ink, width: size * 0.07),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
