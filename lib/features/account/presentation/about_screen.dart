import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_info.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/screen_scaffold.dart';
import 'account_widgets.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return ScreenScaffold(
      title: 'About',
      children: [
        const SizedBox(height: Space.lg),
        const Center(child: BrandMark(size: 56)),
        const SizedBox(height: Space.lg),
        Center(child: Text(AppInfo.name, style: t.headlineMedium)),
        const SizedBox(height: Space.xs),
        Center(
          child: Text(
            'Version ${AppInfo.appVersion}',
            style: t.bodyMedium?.copyWith(color: c.textSecondary),
          ),
        ),
        const SizedBox(height: Space.lg),
        Text(
          AppInfo.tagline,
          textAlign: TextAlign.center,
          style: t.bodyLarge?.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: Space.xl),
        Text(
          'Photograph a receipt, add the people who were there, and Divvy '
          'works out exactly what each person owes. The amounts are kept in '
          'whole paise and always add up to the bill total.',
          textAlign: TextAlign.center,
          style: t.bodyMedium?.copyWith(color: c.textSecondary, height: 1.5),
        ),
        const SizedBox(height: Space.xxl),
        AppCard(
          padding: EdgeInsets.zero,
          child: AccountRow(
            icon: Icons.description_outlined,
            title: 'Open-source licences',
            onTap: () => showLicensePage(
              context: context,
              applicationName: AppInfo.name,
              applicationVersion: AppInfo.appVersion,
            ),
          ),
        ),
      ],
    );
  }
}
