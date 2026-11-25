import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/responsive/text_scaling.dart';

/// Adaptive navigation: bottom bar on phones, rail on tablets / landscape.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _go(int index) => navigationShell.goBranch(
    index,
    // Tapping the active tab returns to its root (platform convention).
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = WindowSize.of(context);
    final destinations = [
      (Icons.list_alt_outlined, Icons.list_alt, l10n.navItems),
      (Icons.settings_outlined, Icons.settings, l10n.navSettings),
    ];

    if (size.isCompact) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _go,
          destinations: [
            for (final (icon, selected, label) in destinations)
              NavigationDestination(
                icon: Icon(icon),
                selectedIcon: Icon(selected),
                label: label,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        right: false,
        child: Row(
          children: [
            // Like NavigationBar (which Material already caps at 1.3x), the
            // rail keeps its labels readable instead of overflowing.
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: TextScaling.maxChromeScaleFactor,
              child: NavigationRail(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _go,
                extended: size == WindowSize.expanded,
                labelType: size == WindowSize.expanded
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                destinations: [
                  for (final (icon, selected, label) in destinations)
                    NavigationRailDestination(
                      icon: Tooltip(message: label, child: Icon(icon)),
                      selectedIcon: Icon(selected),
                      label: Text(label),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      ),
    );
  }
}
