import 'package:csias_desktop/core/widgets/app_shell.dart';
import 'package:csias_desktop/features/chatgpt_queries/presentation/pages/chatgpt_queries_page.dart';
import 'package:csias_desktop/features/google_indexing/presentation/pages/google_indexing_page.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/pages/tistory_posting_page.dart';
import 'package:go_router/go_router.dart';

final router = GoRouter(
  initialLocation: '/tistory',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/tistory',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: TistoryPostingPage()),
        ),
        GoRoute(
          path: '/indexing',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: GoogleIndexingPage()),
        ),
        GoRoute(
          path: '/queries',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ChatGPTQueriesPage()),
        ),
      ],
    ),
  ],
);
