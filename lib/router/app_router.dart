import 'package:go_router/go_router.dart';

import '../pages/login_page.dart';
import '../pages/splash_page.dart';
import '../pages/register_page.dart';
import '../pages/dashboard_shell.dart';

import '../pages/sections/dashboard_page.dart';
import '../pages/sections/account_page.dart';
import '../pages/sections/change_password_page.dart';
import '../pages/sections/register_doc_page.dart';
import '../pages/sections/data_page.dart';
import '../pages/sections/document_list_page.dart';
import '../pages/sections/history_page.dart';
import '../pages/sections/add_record_page.dart';
import '../pages/sections/update_data_page.dart';
import '../pages/sections/reminder_page.dart';
import '../pages/sections/detail_history_page.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),

      // Shell dengan sidebar yang selalu ada
      StatefulShellRoute.indexedStack(
        builder: (context, state, navShell) => DashboardShell(navShell: navShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/dashboard', builder: (_, _) => const DashboardPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/registerdoc', builder: (_, _) => const RegisterDocPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/data', builder: (_, _) => const DataPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/documentlist', builder: (_, _) => const DocumentListPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/addrecord', builder: (_, _) => const AddRecordPage()),
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
            GoRoute(path: '/reminder', builder: (_, _) => const ReminderPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/update', builder: (context, state) {
            final item = state.extra as Map<String, dynamic>;
            return UpdateDataPage(item: item);
            }),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/detailhistory', builder: (context, state) {
            final date = state.uri.queryParameters['date']; // Mengambil ?date=...
            return DetailHistoryPage(filterDate: date);
            }),
          ]),
        ],
      ),
    ],
  );
}
