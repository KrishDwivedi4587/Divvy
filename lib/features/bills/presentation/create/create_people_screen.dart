import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/navigation.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../../core/widgets/step_progress.dart';
import '../../../../shared/providers/data_providers.dart';
import '../../../people/domain/person_rules.dart';
import '../../../people/domain/saved_person.dart';
import '../../application/bill_draft_notifier.dart';
import 'people_step_parts.dart';

const int minToSplit = 2;

String _messageFor(NameCheckFailure reason) => switch (reason) {
  NameCheckFailure.empty => 'Enter a name',
  NameCheckFailure.duplicate => 'That person is already on this bill',
  NameCheckFailure.tooLong => 'Names can be up to $maxNameLength characters',
  NameCheckFailure.limit => 'You can split between up to $maxPeople people',
};

/// Step 3: who was there. Type a name and press Add (or Return) to add a new or
/// saved person, or tap someone from your saved people.
class CreatePeopleScreen extends ConsumerStatefulWidget {
  const CreatePeopleScreen({super.key});

  @override
  ConsumerState<CreatePeopleScreen> createState() => _CreatePeopleScreenState();
}

class _CreatePeopleScreenState extends ConsumerState<CreatePeopleScreen> {
  final _name = TextEditingController();
  final _focus = FocusNode();
  String? _problem;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_busy) return;
    final draft = ref.read(billDraftProvider);
    final check = checkPersonName(_name.text, [
      for (final p in draft.participants) p.name,
    ]);
    if (check is NameRejected) {
      setState(() => _problem = _messageFor(check.reason));
      return;
    }
    final name = (check as NameOk).name;

    setState(() => _busy = true);
    final notifier = ref.read(billDraftProvider.notifier);

    // Typing the name of someone already saved adds that person, rather than
    // creating a second one with the same name.
    final saved = await ref.read(peopleProvider.future);
    final match = saved
        .where((p) => p.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
    if (match != null) {
      notifier.addPerson(match);
    } else {
      final result = await ref.read(peopleActionsProvider).add(name);
      if (!mounted) return;
      switch (result) {
        case PersonSaved(:final person):
          notifier.addPerson(person);
        case PersonRejected(:final reason):
          setState(() {
            _problem = _messageFor(reason);
            _busy = false;
          });
          return;
      }
    }
    if (!mounted) return;
    _name.clear();
    setState(() {
      _problem = null;
      _busy = false;
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final people = ref.watch(billDraftProvider).participants;
    final saved = ref.watch(peopleProvider).value ?? const <SavedPerson>[];
    final onBill = {for (final p in people) p.personId};
    final suggestions = saved
        .where((p) => !p.isArchived && !onBill.contains(p.id))
        .toList();
    final enough = people.length >= minToSplit;
    final full = people.length >= maxPeople;

    return ScreenScaffold(
      title: "Who's splitting?",
      belowHeader: const StepProgress(step: 3, of: 5, label: 'People'),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!enough)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Text(
                'Add at least $minToSplit people to split the bill',
                style: t.bodySmall?.copyWith(color: c.textSecondary),
              ),
            ),
          AppButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: enough
                ? () => context.open(AppRoutes.createSplit)
                : null,
          ),
        ],
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: 'Add a person',
                hint: 'Name',
                controller: _name,
                focusNode: _focus,
                error: _problem,
                maxLength: maxNameLength + 4,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                onChanged: (_) {
                  if (_problem != null) setState(() => _problem = null);
                },
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: Space.md),
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: AppButton(
                label: 'Add',
                icon: Icons.add_rounded,
                expand: false,
                loading: _busy,
                onPressed: full ? null : _add,
              ),
            ),
          ],
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: Space.xl),
          const SectionHeader('From your people'),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final p in suggestions)
                SavedPersonChip(
                  person: p,
                  onTap: full
                      ? null
                      : () => ref.read(billDraftProvider.notifier).addPerson(p),
                ),
            ],
          ),
        ],
        const SizedBox(height: Space.xl),
        SectionHeader(
          'On this bill',
          trailing: Text(
            '${people.length} of $maxPeople',
            style: t.labelMedium?.copyWith(color: c.textSecondary),
          ),
        ),
        if (people.isEmpty)
          AppCard(
            muted: true,
            child: Text(
              'No one yet. Add the people who shared this bill.',
              style: t.bodyMedium?.copyWith(color: c.textSecondary),
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < people.length; i++) ...[
                  if (i > 0) const Hairline(indent: Space.lg + 40 + Space.md),
                  ParticipantRow(participant: people[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
