import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_button.dart';
import '../../core/widgets/screen_scaffold.dart';
import '../../core/widgets/states.dart';
import '../../features/account/presentation/about_screen.dart';
import '../../features/account/presentation/account_screen.dart';
import '../../features/account/presentation/privacy_screen.dart';
import '../../features/bills/presentation/create/create_people_screen.dart';
import '../../features/bills/presentation/create/preview_screen.dart';
import '../../features/bills/presentation/create/review_screen.dart';
import '../../features/bills/presentation/create/source_screen.dart';
import '../../features/bills/presentation/create/split_screen.dart';
import '../../features/bills/presentation/create/summary_screen.dart';
import '../../features/bills/presentation/detail/bill_detail_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/people/presentation/people_screen.dart';
import '../../features/people/presentation/person_detail_screen.dart';
import '../shell/app_shell.dart';
import 'routes.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Builds the app's router.
///
/// The four tabs live inside a [StatefulShellRoute], so each keeps its own
/// history. Everything that should cover the whole screen (the Create Bill
/// flow, a bill, a person) sits on the root navigator above the tab bar.
GoRouter buildRouter({String initialLocation = AppRoutes.home}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    errorBuilder: (context, state) => const _NotFound(),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.people,
                builder: (context, state) => const PeopleScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.account,
                builder: (context, state) => const AccountScreen(),
                routes: [
                  GoRoute(
                    path: 'privacy',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const PrivacyScreen(),
                  ),
                  GoRoute(
                    path: 'about',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const AboutScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.create,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SourceScreen(),
        routes: [
          GoRoute(
            path: 'preview',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const PreviewScreen(),
          ),
          GoRoute(
            path: 'review',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const ReviewScreen(),
          ),
          GoRoute(
            path: 'people',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const CreatePeopleScreen(),
          ),
          GoRoute(
            path: 'split',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const SplitScreen(),
          ),
          GoRoute(
            path: 'summary',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const SummaryScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.billPattern,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            BillDetailScreen(billId: state.pathParameters['billId']!),
      ),
      GoRoute(
        path: AppRoutes.personPattern,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            PersonDetailScreen(personId: state.pathParameters['personId']!),
      ),
    ],
  );
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Not found',
      showBack: false,
      body: Column(
        children: [
          const Expanded(
            child: EmptyState(
              icon: Icons.explore_off_outlined,
              title: 'Page not found',
              message: "That page doesn't exist.",
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: AppButton(
              label: 'Go home',
              onPressed: () => GoRouter.of(context).go(AppRoutes.home),
            ),
          ),
        ],
      ),
    );
  }
}
