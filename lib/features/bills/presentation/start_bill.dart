import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/navigation.dart';
import '../../../app/router/routes.dart';
import '../../receipt_scanning/application/scan_notifier.dart';
import '../application/bill_draft_notifier.dart';

/// Begins a new bill and opens the Create Bill flow. Used by every "New bill"
/// button so they all start from the same clean state.
Future<void> startNewBill(BuildContext context, WidgetRef ref) async {
  ref.read(scanProvider.notifier).reset();
  await ref.read(billDraftProvider.notifier).startNewBill();
  if (context.mounted) context.open(AppRoutes.create);
}
