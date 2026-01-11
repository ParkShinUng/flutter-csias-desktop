import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_spacing.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  int _indexFromLocation(String location) {
    if (location.startsWith('/indexing')) return 1;
    if (location.startsWith('/queries')) return 2;
    return 0; // default: /tistory
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = _indexFromLocation(location);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (i) {
              if (i == 0) context.go('/tistory');
              if (i == 1) context.go('/indexing');
              if (i == 2) context.go('/queries');
            },
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Column(
                children: const [
                  Icon(Icons.auto_awesome, size: 26),
                  SizedBox(height: 10),
                  Text(
                    'Customizer',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.article_outlined),
                selectedIcon: Icon(Icons.article),
                label: Text('Tistory'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.playlist_add_check_outlined),
                selectedIcon: Icon(Icons.playlist_add_check),
                label: Text('Google\nIndexing', textAlign: TextAlign.center),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.query_stats_outlined),
                selectedIcon: Icon(Icons.query_stats),
                label: Text('Queries'),
              ),
            ],
          ),

          // Divider
          const VerticalDivider(width: 1),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.r16),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
