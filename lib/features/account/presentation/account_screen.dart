import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/navigation.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_info.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../shared/providers/data_providers.dart';
import '../../people/presentation/person_editor_sheet.dart';
import '../domain/app_settings.dart';
import 'account_widgets.dart';

String themeLabel(AppThemeMode m) => switch (m) {
  AppThemeMode.system => 'System',
  AppThemeMode.light => 'Light',
  AppThemeMode.dark => 'Dark',
};

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final me = ref.watch(selfPersonProvider).value;
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final bills = ref.watch(billCountProvider).value ?? 0;

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.lg,
              Space.gutter,
              Space.xxl,
            ),
            children: [
              Text('Account', style: t.headlineLarge),
              const SizedBox(height: Space.xl),
              if (me != null)
                AppCard(
                  onTap: () => showPersonEditor(context, existing: me),
                  child: Row(
                    children: [
                      PersonAvatar(
                        name: me.name,
                        tone: me.colorIndex,
                        size: 56,
                      ),
                      const SizedBox(width: Space.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(me.name, style: t.titleLarge),
                            Text(
                              'Tap to change your name',
                              style: t.bodySmall?.copyWith(
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.edit_outlined,
                        color: c.textTertiary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: Space.xl),
              const SectionHeader('Preferences'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    AccountRow(
                      icon: Icons.payments_outlined,
                      title: 'Currency',
                      detail:
                          '${settings.currency.symbol} ${settings.currency.code}',
                      onTap: () => _pickCurrency(context, ref, settings),
                    ),
                    const Hairline(indent: Space.lg),
                    AccountRow(
                      icon: Icons.contrast_rounded,
                      title: 'Appearance',
                      detail: themeLabel(settings.themeMode),
                      onTap: () => _pickTheme(context, ref, settings),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xl),
              const SectionHeader('About'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    AccountRow(
                      icon: Icons.lock_outline_rounded,
                      title: 'Privacy',
                      onTap: () => context.open(AppRoutes.privacy),
                    ),
                    const Hairline(indent: Space.lg),
                    AccountRow(
                      icon: Icons.info_outline_rounded,
                      title: 'About ${AppInfo.name}',
                      detail: 'Version ${AppInfo.appVersion}',
                      onTap: () => context.open(AppRoutes.about),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xl),
              const SectionHeader('Your data'),
              AppCard(
                padding: EdgeInsets.zero,
                child: AccountRow(
                  icon: Icons.delete_outline_rounded,
                  title: 'Delete all data',
                  detail: '$bills ${bills == 1 ? 'bill' : 'bills'}',
                  destructive: true,
                  onTap: () => _deleteAll(context, ref),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickCurrency(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final chosen = await showAppSheet<Currency>(
      context,
      builder: (context) => ChoiceList<Currency>(
        title: 'Currency',
        note: 'New bills start in this currency. Saved bills keep theirs.',
        values: Currency.values,
        selected: settings.currency,
        label: (c) => '${c.symbol}  ${c.label}',
      ),
    );
    if (chosen != null) {
      await ref.read(settingsProvider.notifier).setCurrency(chosen);
    }
  }

  Future<void> _pickTheme(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final chosen = await showAppSheet<AppThemeMode>(
      context,
      builder: (context) => ChoiceList<AppThemeMode>(
        title: 'Appearance',
        values: AppThemeMode.values,
        selected: settings.themeMode,
        label: themeLabel,
      ),
    );
    if (chosen != null) {
      await ref.read(settingsProvider.notifier).setThemeMode(chosen);
    }
  }

  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final ok = await confirmAction(
      context,
      title: 'Delete all data?',
      message:
          'Every bill, receipt photo, saved person and setting is erased '
          'from this phone. This cannot be undone.',
      confirmLabel: 'Delete everything',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await ref.read(billActionsProvider).deleteEverything();
    if (context.mounted) showMessage(context, 'All data deleted');
  }
}
