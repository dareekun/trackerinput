import 'package:go_router/go_router.dart';

import '../pages/login_page.dart';
import '../pages/splash_page.dart';
import '../pages/dashboard_shell.dart';

import '../pages/sections/dashboard_page.dart';
import '../pages/sections/account_page.dart';
import '../pages/sections/change_password_page.dart';
import '../pages/sections/insert_data_page.dart';
import '../pages/sections/data_page.dart';
import '../pages/sections/chat_page.dart';
import '../pages/sections/app_tools_page.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),

      // Shell dengan sidebar yang selalu ada
      StatefulShellRoute.indexedStack(
        builder: (context, state, navShell) => DashboardShell(navShell: navShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/dashboard', builder: (_, __) => const DashboardPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/account', builder: (_, __) => const AccountPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/insertdata', builder: (_, __) => const InsertDataPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/data', builder: (_, __) => const DataPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/chat', builder: (_, __) => const ChatPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/app', builder: (_, __) => const AppToolsPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/changepassword', builder: (_, __) => const ChangePasswordPage()),
          ]),
        ],
      ),
    ],
  );
}
