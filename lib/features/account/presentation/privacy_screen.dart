import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/widgets/screen_scaffold.dart';

/// What Divvy does with your information, in plain words. Every statement here
/// describes what the app actually does; it is not boilerplate.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const List<(String, String)> sections = [
    (
      'Everything stays on this phone',
      'Your bills, people and receipt photos are stored only on this device. '
          'Divvy has no accounts and no server, and it does not upload your '
          'data anywhere.',
    ),
    (
      'Receipt photos',
      'When you photograph or choose a receipt, Divvy reads it on the phone '
          'using Google ML Kit text recognition. The photo is kept inside '
          "Divvy's private storage only if you save the bill, and is deleted "
          'with the bill.',
    ),
    (
      'Camera and photos',
      'Divvy asks for the camera only when you tap Take photo. Choosing from '
          'your library uses the system photo picker, so Divvy only ever '
          'receives the one photo you pick. If you turned the camera off, '
          'open Settings, then Divvy, and allow Camera.',
    ),
    (
      'Your control',
      'You can delete any bill from its page, remove a person from People, '
          'or erase everything from Account. Deleting is permanent: there is '
          'no copy to recover.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return ScreenScaffold(
      title: 'Privacy',
      children: [
        for (final (title, body) in sections) ...[
          Text(title, style: t.titleMedium),
          const SizedBox(height: Space.xs),
          Text(
            body,
            style: t.bodyMedium?.copyWith(color: c.textSecondary, height: 1.5),
          ),
          const SizedBox(height: Space.xl),
        ],
      ],
    );
  }
}
