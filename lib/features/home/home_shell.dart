import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/navigation_controller.dart';
import '../player/mini_player.dart';
import 'discover_tab.dart';
import 'library_tab.dart';
import 'profile_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _titles = ['Главная', 'Медиатека', 'Профиль'];

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationController>();
    final index = nav.index;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: index,
              children: const [
                DiscoverTab(),
                LibraryTab(),
                ProfileTab(),
              ],
            ),
          ),
          const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 64,
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.surfaceHighlight,
        selectedIndex: index,
        onDestinationSelected: (i) => nav.setIndex(i),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: _iconColor(index, 0)),
            selectedIcon: const Icon(Icons.home_rounded, color: AppTheme.textPrimary),
            label: _titles[0],
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined, color: _iconColor(index, 1)),
            selectedIcon: const Icon(Icons.library_music_rounded, color: AppTheme.textPrimary),
            label: _titles[1],
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded, color: _iconColor(index, 2)),
            selectedIcon: const Icon(Icons.person_rounded, color: AppTheme.textPrimary),
            label: _titles[2],
          ),
        ],
      ),
    );
  }

  Color _iconColor(int index, int i) =>
      index == i ? AppTheme.textPrimary : AppTheme.textSecondary;
}
