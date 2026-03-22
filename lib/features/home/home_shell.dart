import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
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
  int _index = 0;

  static const _titles = ['Главная', 'Медиатека', 'Профиль'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _index,
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
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: _iconColor(0)),
            selectedIcon: const Icon(Icons.home_rounded, color: AppTheme.textPrimary),
            label: _titles[0],
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined, color: _iconColor(1)),
            selectedIcon: const Icon(Icons.library_music_rounded, color: AppTheme.textPrimary),
            label: _titles[1],
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded, color: _iconColor(2)),
            selectedIcon: const Icon(Icons.person_rounded, color: AppTheme.textPrimary),
            label: _titles[2],
          ),
        ],
      ),
    );
  }

  Color _iconColor(int i) =>
      _index == i ? AppTheme.textPrimary : AppTheme.textSecondary;
}
