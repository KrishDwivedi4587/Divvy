import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../shared/providers/data_providers.dart';
import '../domain/person_rules.dart';
import '../domain/saved_person.dart';

/// The message shown when a name is not accepted.
String nameErrorMessage(NameCheckFailure reason) => switch (reason) {
  NameCheckFailure.empty => 'Enter a name',
  NameCheckFailure.duplicate => 'That name is already on your list',
  NameCheckFailure.tooLong => 'Names can be up to $maxNameLength characters',
  NameCheckFailure.limit => 'You can split between up to $maxPeople people',
};

/// Opens the add-or-rename sheet. Returns the saved person, or null if the
/// user dismissed it.
Future<SavedPerson?> showPersonEditor(
  BuildContext context, {
  SavedPerson? existing,
}) {
  return showAppSheet<SavedPerson>(
    context,
    builder: (_) => _PersonEditor(existing: existing),
  );
}

class _PersonEditor extends ConsumerStatefulWidget {
  const _PersonEditor({this.existing});

  final SavedPerson? existing;

  @override
  ConsumerState<_PersonEditor> createState() => _PersonEditorState();
}

class _PersonEditorState extends ConsumerState<_PersonEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);
    final actions = ref.read(peopleActionsProvider);
    final existing = widget.existing;
    final result = existing == null
        ? await actions.add(_name.text)
        : await actions.rename(existing.id, _name.text);
    if (!mounted) return;
    switch (result) {
      case PersonSaved(:final person):
        Navigator.of(context).pop(person);
      case PersonRejected(:final reason):
        setState(() {
          _error = nameErrorMessage(reason);
          _saving = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          editing ? 'Edit person' : 'Add a person',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: Space.lg),
        AppTextField(
          label: 'Name',
          hint: 'e.g. Aarav',
          controller: _name,
          autofocus: true,
          error: _error,
          maxLength: maxNameLength + 4,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: Space.xl),
        AppButton(
          label: editing ? 'Save' : 'Add person',
          onPressed: _submit,
          loading: _saving,
        ),
      ],
    );
  }
}
