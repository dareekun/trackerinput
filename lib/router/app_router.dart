import 'package:go_router/go_router.dart';

import '../pages/login_page.dart';
import '../pages/splash_page.dart';
import '../pages/dashboard_shell.dart';

import '../pages/sections/dashboard_page.dart';
import '../pages/sections/account_page.dart';
import '../pages/sections/change_password_page.dart';
import '../pages/sections/insert_data_page.dart';
import '../pages/sections/data_page.dart';
import '../pages/sections/history_page.dart';
import '../pages/sections/app_tools_page.dart';

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
            GoRoute(path: '/insertdata', builder: (_, _) => const InsertDataPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/data', builder: (_, _) => const DataPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/history', builder: (_, _) => const HistoryPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/app', builder: (_, _) => const AppToolsPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/account', builder: (_, _) => const AccountPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/changepassword', builder: (_, _) => const ChangePasswordPage()),
          ]),
        ],
      ),
    ],
  );
}
