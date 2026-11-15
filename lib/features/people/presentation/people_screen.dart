import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/navigation.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/states.dart';
import '../../../shared/providers/data_providers.dart';
import '../domain/saved_person.dart';
import 'balance_text.dart';
import 'person_editor_sheet.dart';

class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final people = ref.watch(peopleProvider);
    final balances = ref.watch(balancesProvider).value ?? const {};

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.lg,
                  Space.sm,
                  Space.md,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text('People', style: t.headlineLarge)),
                    IconButton.outlined(
                      tooltip: 'Add person',
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      onPressed: () => showPersonEditor(context),
                    ),
                    const SizedBox(width: Space.sm),
                  ],
                ),
              ),
              Expanded(
                child: people.when(
                  loading: () => const LoadingState(),
                  error: (e, _) => ErrorState(
                    message: "Your people couldn't be loaded.",
                    onRetry: () => ref.invalidate(peopleProvider),
                  ),
                  data: (list) => _List(people: list, balances: balances),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.people, required this.balances});

  final List<SavedPerson> people;
  final Map<String, PersonBalance> balances;

  @override
  Widget build(BuildContext context) {
    final others = people.where((p) => !p.isSelf).toList();
    final me = people.where((p) => p.isSelf).firstOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Space.xxl,
      ),
      children: [
        if (me != null) ...[
          const SectionHeader('You'),
          AppCard(
            padding: EdgeInsets.zero,
            child: _PersonRow(person: me, balance: null),
          ),
          const SizedBox(height: Space.lg),
        ],
        SectionHeader(
          'Saved people',
          trailing: others.isEmpty
              ? null
              : Text(
                  '${others.length}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
        ),
        if (others.isEmpty)
          AppCard(
            child: EmptyState(
              icon: Icons.group_outlined,
              title: 'No one saved yet',
              message:
                  'Add the people you split bills with, so you can pick '
                  'them in one tap.',
              actionLabel: 'Add a person',
              onAction: () => showPersonEditor(context),
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < others.length; i++) ...[
                  if (i > 0) const Hairline(indent: Space.lg + 40 + Space.md),
                  _PersonRow(
                    person: others[i],
                    balance: balances[others[i].id],
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.balance});

  final SavedPerson person;
  final PersonBalance? balance;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final lines = describeBalance(balance);

    return InkWell(
      onTap: () => context.open(AppRoutes.person(person.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md,
        ),
        child: Row(
          children: [
            PersonAvatar(name: person.name, tone: person.colorIndex, size: 40),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(person.name, style: t.titleSmall),
                  if (person.isSelf)
                    Text(
                      'Your account',
                      style: t.bodySmall?.copyWith(color: c.textSecondary),
                    )
                  else if (lines.isNotEmpty)
                    for (final line in lines)
                      Text(
                        line,
                        style: t.bodySmall?.copyWith(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                  else
                    Text(
                      'Settled up',
                      style: t.bodySmall?.copyWith(color: c.textSecondary),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}
