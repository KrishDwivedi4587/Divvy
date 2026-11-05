import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/widgets/avatar.dart';
import '../../../people/domain/saved_person.dart';
import '../../application/bill_draft_notifier.dart';
import '../../domain/bill_draft.dart';

/// A saved person offered as a one-tap addition.
class SavedPersonChip extends StatelessWidget {
  const SavedPersonChip({required this.person, required this.onTap, super.key});

  final SavedPerson person;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Add ${person.name}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Corners.pill),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, Space.md, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Corners.pill),
            border: Border.all(color: c.borderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PersonAvatar(
                name: person.name,
                tone: person.colorIndex,
                size: 28,
              ),
              const SizedBox(width: Space.sm),
              Flexible(
                child: Text(
                  person.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              const SizedBox(width: Space.xs),
              Icon(Icons.add_rounded, size: 16, color: c.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Someone on the bill, with a button to take them off.
class ParticipantRow extends ConsumerWidget {
  const ParticipantRow({required this.participant, super.key});

  final DraftParticipant participant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.sm,
      ),
      child: Row(
        children: [
          PersonAvatar(
            name: participant.name,
            tone: participant.colorIndex,
            size: 40,
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Text(
              participant.name,
              style: t.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Remove ${participant.name}',
            icon: Icon(Icons.close_rounded, size: 20, color: c.textSecondary),
            onPressed: () => ref
                .read(billDraftProvider.notifier)
                .removeParticipant(participant.id),
          ),
        ],
      ),
    );
  }
}
