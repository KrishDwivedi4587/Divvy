import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../features/people/domain/person_rules.dart';

/// A person's initials on a neutral tone. The tone only helps tell people apart
/// at a glance; the initials always carry the identity, so nothing depends on
/// colour perception.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    required this.name,
    this.tone = 0,
    this.size = 40,
    this.outlined = false,
    this.singleInitial = false,
    super.key,
  });

  final String name;
  final int tone;
  final double size;

  /// Draws a ring in the surface colour, for stacking avatars.
  final bool outlined;

  /// Shows only the first initial, for avatars too small for two letters.
  final bool singleInitial;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (background, foreground) = c.avatar(tone);
    return Semantics(
      label: name,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: outlined ? Border.all(color: c.surface, width: 2) : null,
        ),
        child: Text(
          singleInitial
              ? initialsFor(name).characters.first
              : initialsFor(name),
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: foreground, fontSize: size * 0.36, height: 1),
        ),
      ),
    );
  }
}

/// Overlapping avatars for a bill's participants, with a "+N" for the rest.
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    required this.names,
    this.tones,
    this.size = 28,
    this.max = 4,
    super.key,
  });

  final List<String> names;
  final List<int>? tones;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = names.take(max).toList();
    final extra = names.length - shown.length;
    final step = size * 0.78;
    final slots = shown.length + (extra > 0 ? 1 : 0);

    return SizedBox(
      height: size,
      width: size + (slots - 1) * step,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * step,
              child: PersonAvatar(
                name: shown[i],
                tone: tones != null ? tones![i] : i,
                size: size,
                outlined: true,
                singleInitial: size < 32,
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * step,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surfaceMuted,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.surface, width: 2),
                ),
                child: Text(
                  '+$extra',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: c.textSecondary, letterSpacing: 0),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
