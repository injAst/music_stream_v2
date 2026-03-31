import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/navigation_controller.dart';
import 'discover_tab.dart';
import 'library_tab.dart';
import 'profile_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationController>();
    final index = nav.index;

    return IndexedStack(
      index: index,
      children: const [
        DiscoverTab(),
        LibraryTab(),
        ProfileTab(),
      ],
    );
  }
}
