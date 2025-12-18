import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_shell.dart';
import '../features/chatgpt_queries/presentation/pages/chatgpt_queries_page.dart';
import '../features/tistory_posting/presentation/pages/tistory_posting_page.dart';
import '../features/chatgpt_queries/presentation/pages/chatgpt_queries_page.dart';

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
          path: '/queries',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ChatGPTQueriesPage()),
        ),
      ],
    ),
  ],
);
