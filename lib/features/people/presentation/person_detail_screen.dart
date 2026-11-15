import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/navigation.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/states.dart';
import '../../../shared/providers/data_providers.dart';
import '../../history/presentation/bill_tile.dart';
import '../domain/saved_person.dart';
import 'balance_text.dart';
import 'person_editor_sheet.dart';

class PersonDetailScreen extends ConsumerWidget {
  const PersonDetailScreen({required this.personId, super.key});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(personProvider(personId));

    return person.when(
      loading: () =>
          const ScreenScaffold(title: 'Person', body: LoadingState()),
      error: (e, _) => ScreenScaffold(
        title: 'Person',
        body: ErrorState(
          message: "This person couldn't be loaded.",
          onRetry: () => ref.invalidate(personProvider(personId)),
        ),
      ),
      data: (p) => p == null
          ? const ScreenScaffold(
              title: 'Person',
              body: EmptyState(
                icon: Icons.person_off_outlined,
                title: 'Person not found',
                message: 'They may have been removed.',
              ),
            )
          : _Loaded(person: p),
    );
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({required this.person});

  final SavedPerson person;

  Future<void> _remove(BuildContext context, WidgetRef ref, int bills) async {
    final ok = await confirmAction(
      context,
      title: 'Remove ${person.name}?',
      message: bills == 0
          ? '${person.name} is not on any bills, so they will be deleted.'
          : '${person.name} will be hidden from your list. Their name and '
                'shares stay on the $bills past ${bills == 1 ? 'bill' : 'bills'} '
                'they were part of.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await ref.read(peopleActionsProvider).remove(person.id);
    if (context.mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final bills = ref.watch(personBillsProvider(person.id));
    final balance = ref.watch(balancesProvider).value?[person.id];
    final lines = describeBalance(balance);
    final count = bills.value?.length ?? 0;

    return ScreenScaffold(
      title: person.name,
      children: [
        Center(
          child: Column(
            children: [
              PersonAvatar(
                name: person.name,
                tone: person.colorIndex,
                size: 72,
              ),
              const SizedBox(height: Space.md),
              Text(person.name, style: t.headlineMedium),
              Text(
                person.isSelf
                    ? 'Your account'
                    : count == 0
                    ? 'Not on any bills yet'
                    : 'On $count ${count == 1 ? 'bill' : 'bills'}',
                style: t.bodyMedium?.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
        if (!person.isSelf) ...[
          const SizedBox(height: Space.xl),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Balance',
                  style: t.bodySmall?.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: Space.xs),
                if (lines.isEmpty)
                  Text('Settled up', style: t.titleLarge)
                else
                  for (final line in lines) Text(line, style: t.titleLarge),
              ],
            ),
          ),
        ],
        const SizedBox(height: Space.xl),
        const SectionHeader('Bills together'),
        bills.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Space.xl),
            child: LoadingState(),
          ),
          error: (e, _) => ErrorState(
            message: "Their bills couldn't be loaded.",
            onRetry: () => ref.invalidate(personBillsProvider(person.id)),
          ),
          data: (list) => list.isEmpty
              ? AppCard(
                  child: Text(
                    'No bills with ${person.name} yet.',
                    style: t.bodyMedium?.copyWith(color: c.textSecondary),
                  ),
                )
              : AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0) const Hairline(),
                        BillTile(
                          bill: list[i],
                          onTap: () => context.open(AppRoutes.bill(list[i].id)),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
        const SizedBox(height: Space.xl),
        AppButton(
          label: 'Edit name',
          icon: Icons.edit_outlined,
          kind: AppButtonKind.secondary,
          onPressed: () => showPersonEditor(context, existing: person),
        ),
        if (!person.isSelf) ...[
          const SizedBox(height: Space.md),
          AppButton(
            label: 'Remove from People',
            icon: Icons.person_remove_outlined,
            kind: AppButtonKind.text,
            destructive: true,
            onPressed: () => _remove(context, ref, count),
          ),
        ],
      ],
    );
  }
}
