import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/navigation.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/states.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/providers/data_providers.dart';
import '../../bills/domain/engine/money.dart';
import '../../bills/domain/models/bill_record.dart';
import '../../bills/presentation/start_bill.dart';
import '../../history/presentation/bill_tile.dart';
import '../../people/domain/saved_person.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final me = ref.watch(selfPersonProvider).value;
    final now = ref.watch(clockProvider)();
    final name = me == null || me.name == 'You' ? null : me.name;

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.md,
              Space.gutter,
              Space.xxl,
            ),
            children: [
              Row(
                children: [
                  const BrandMark(),
                  const SizedBox(width: Space.sm),
                  Text('Divvy', style: t.titleLarge),
                  const Spacer(),
                  if (me != null)
                    GestureDetector(
                      onTap: () => context.switchTo(AppRoutes.account),
                      child: PersonAvatar(
                        name: me.name,
                        tone: me.colorIndex,
                        size: 36,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Space.xl),
              Text(
                greetingFor(now),
                style: t.bodyMedium?.copyWith(color: c.textSecondary),
              ),
              Text(name ?? 'Welcome', style: t.headlineLarge),
              const SizedBox(height: Space.xl),
              const _NewBillCard(),
              const SizedBox(height: Space.lg),
              const _BalancesCard(),
              const _QuickLinks(),
              const SizedBox(height: Space.xl),
              const _RecentBills(),
              const SizedBox(height: Space.xl),
              const _RecentActivity(),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewBillCard extends ConsumerWidget {
  const _NewBillCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(color: c.ink, borderRadius: Corners.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Split a bill',
            style: t.headlineMedium?.copyWith(color: c.onInk),
          ),
          const SizedBox(height: Space.sm),
          Text(
            'Photograph a receipt, choose who was there, and see exactly '
            'what each person owes.',
            style: t.bodyMedium?.copyWith(
              color: c.onInk.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: Space.xl),
          FilledButton.icon(
            onPressed: () => startNewBill(context, ref),
            style: FilledButton.styleFrom(
              backgroundColor: c.onInk,
              foregroundColor: c.ink,
              minimumSize: const Size(0, 48),
            ),
            icon: const Icon(Icons.add_rounded, size: 22),
            label: const Text('New bill'),
          ),
        ],
      ),
    );
  }
}

/// How much is owed to the account holder and how much they owe, per currency.
class _BalancesCard extends ConsumerWidget {
  const _BalancesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(balancesProvider).value;
    if (balances == null) return const SizedBox.shrink();

    final owed = <Currency, Paise>{};
    final owe = <Currency, Paise>{};
    for (final PersonBalance b in balances.values) {
      b.net.forEach((currency, amount) {
        if (amount > Paise.zero) {
          owed[currency] = (owed[currency] ?? Paise.zero) + amount;
        } else if (amount.isNegative) {
          owe[currency] = (owe[currency] ?? Paise.zero) - amount;
        }
      });
    }
    if (owed.isEmpty && owe.isEmpty) return const SizedBox.shrink();

    final t = Theme.of(context).textTheme;
    final c = context.colors;

    Widget lines(String label, Map<Currency, Paise> amounts) {
      if (amounts.isEmpty) return const SizedBox.shrink();
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: t.bodySmall?.copyWith(color: c.textSecondary)),
            const SizedBox(height: Space.xs),
            for (final e in amounts.entries)
              MoneyText(e.value, e.key, style: t.titleLarge),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: AppCard(
        onTap: () => context.switchTo(AppRoutes.people),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            lines('Owed to you', owed),
            lines('You owe', owe),
            Icon(Icons.chevron_right_rounded, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _QuickLinks extends ConsumerWidget {
  const _QuickLinks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(billCountProvider).value;
    final people = ref.watch(peopleProvider).value;
    // The account holder is always in the list; count only the others.
    final others = people?.where((p) => !p.isSelf).length;

    return Row(
      children: [
        Expanded(
          child: _QuickLink(
            icon: Icons.receipt_long_outlined,
            title: 'Past bills',
            detail: bills == null ? '' : '$bills saved',
            onTap: () => context.switchTo(AppRoutes.history),
          ),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: _QuickLink(
            icon: Icons.group_outlined,
            title: 'People',
            detail: others == null ? '' : '$others saved',
            onTap: () => context.switchTo(AppRoutes.people),
          ),
        ),
      ],
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: Space.lg),
          Text(title, style: t.titleSmall),
          Text(detail, style: t.bodySmall?.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}

class _RecentBills extends ConsumerWidget {
  const _RecentBills();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentBillsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Recent bills',
          trailing: recent.value?.isNotEmpty == true
              ? GestureDetector(
                  onTap: () => context.switchTo(AppRoutes.history),
                  child: Text(
                    'See all',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                )
              : null,
        ),
        recent.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Space.xl),
            child: LoadingState(),
          ),
          error: (e, _) => ErrorState(
            message: "Your bills couldn't be loaded.",
            onRetry: () => ref.invalidate(recentBillsProvider),
          ),
          data: (bills) {
            if (bills.isEmpty) {
              return AppCard(
                child: EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No bills yet',
                  message:
                      'Bills you split are saved here, with their receipts.',
                  actionLabel: 'Create your first bill',
                  onAction: () => startNewBill(context, ref),
                ),
              );
            }
            return AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < bills.length; i++) ...[
                    if (i > 0) const Hairline(),
                    BillTile(
                      bill: bills[i],
                      onTap: () => context.open(AppRoutes.bill(bills[i].id)),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(recentActivityProvider).value;
    if (events == null || events.isEmpty) return const SizedBox.shrink();
    final now = ref.watch(clockProvider)();
    final c = context.colors;
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Recent activity'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < events.length; i++) ...[
                if (i > 0) const Hairline(indent: Space.lg),
                InkWell(
                  onTap: () => context.open(AppRoutes.bill(events[i].billId)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.lg,
                      vertical: Space.md,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          events[i].kind == ActivityKind.paidBack
                              ? Icons.check_circle_outline_rounded
                              : Icons.receipt_long_outlined,
                          size: 20,
                          color: c.textSecondary,
                        ),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _describe(events[i]),
                                style: t.bodyMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                timeAgo(events[i].at, now),
                                style: t.bodySmall?.copyWith(
                                  color: c.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _describe(ActivityEvent e) {
    final amount = formatMoney(e.amount, e.currency);
    return switch (e.kind) {
      ActivityKind.paidBack =>
        '${e.personName} paid back $amount for ${e.billTitle}',
      ActivityKind.billCreated => 'You split ${e.billTitle} · $amount',
    };
  }
}
