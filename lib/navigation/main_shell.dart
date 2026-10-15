import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../features/home/home_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/search/search_screen.dart';
import '../features/watchlist/watchlist_screen.dart';

/// Which bottom tab is active. Provided app-wide so any screen can jump tabs
/// (e.g. the home search icon, or "Browse titles" from an empty watchlist).
class ShellTabs extends ChangeNotifier {
  static const int home = 0;
  static const int search = 1;
  static const int watchlist = 2;
  static const int profile = 3;

  int _index = home;
  int get index => _index;

  void go(int index) {
    if (index == _index) return;
    _index = index;
    notifyListeners();
  }
}

/// Persistent bottom-navigation scaffold hosting the four main screens.
class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final tabs = context.watch<ShellTabs>();

    return PopScope(
      canPop: tabs.index == ShellTabs.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) tabs.go(ShellTabs.home);
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: tabs.index,
          children: const [
            HomeScreen(),
            SearchScreen(),
            WatchlistScreen(),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: _BottomNav(
          index: tabs.index,
          onChanged: tabs.go,
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _items = [
    (icon: Icons.home_outlined, active: Icons.home_rounded, label: 'Home'),
    (icon: Icons.search_rounded, active: Icons.search_rounded, label: 'Search'),
    (
      icon: Icons.bookmark_border_rounded,
      active: Icons.bookmark_rounded,
      label: 'My List'
    ),
    (icon: Icons.person_outline_rounded, active: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xF2050608),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: _items[i].icon,
                    activeIcon: _items[i].active,
                    label: _items[i].label,
                    selected: i == index,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.textPrimary : AppColors.textMuted;
    return InkResponse(
      onTap: onTap,
      highlightShape: BoxShape.rectangle,
      containedInkWell: true,
      splashColor: Colors.white10,
      highlightColor: Colors.transparent,
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: AppDurations.normal,
              curve: Curves.easeOut,
              width: 18,
              height: 2,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            AnimatedSwitcher(
              duration: AppDurations.fast,
              child: Icon(
                selected ? activeIcon : icon,
                key: ValueKey(selected),
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: AppDurations.fast,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
