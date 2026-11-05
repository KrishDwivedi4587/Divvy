import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/bills/presentation/start_bill.dart';
import 'bottom_bar.dart';

/// The frame around the four tabs. Each tab keeps its own navigation state, so
/// switching away and back returns to where you were.
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DivvyBottomBar(
        currentIndex: navigationShell.currentIndex,
        // Tapping the tab you are already on returns to its first screen.
        onSelect: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        onNew: () => startNewBill(context, ref),
      ),
    );
  }
}
