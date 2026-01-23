import 'package:go_router/go_router.dart';

import '../pages/login_page.dart';
import '../pages/splash_page.dart';
import '../pages/dashboard_shell.dart';

import '../pages/sections/dashboard_page.dart';
import '../pages/sections/account_page.dart';
import '../pages/sections/change_password_page.dart';
import '../pages/sections/register_item_page.dart';
import '../pages/sections/data_page.dart';
import '../pages/sections/history_page.dart';
import '../pages/sections/add_data_page.dart';
import '../pages/sections/update_data_page.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),

      // Shell dengan sidebar yang selalu ada
      StatefulShellRoute.indexedStack(
        builder: (context, state, navShell) => DashboardShell(navShell: navShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/dashboard', builder: (_, _) => const DashboardPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/registeritem', builder: (_, _) => const RegisterItemPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/data', builder: (_, _) => const DataPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/adddata', builder: (_, _) => const AddDataPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/history', builder: (_, _) => const HistoryPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/account', builder: (_, _) => const AccountPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/changepassword', builder: (_, _) => const ChangePasswordPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/update', builder: (context, state) {
            final item = state.extra as Map<String, dynamic>;
            return UpdateDataPage(item: item);
            }),
          ]),
        ],
      ),
    ],
  );
}
