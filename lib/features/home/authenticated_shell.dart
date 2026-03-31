import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/audio_player_controller.dart';
import '../../providers/navigation_controller.dart';
import '../player/mini_player.dart';

class AuthenticatedShell extends StatefulWidget {
  final Widget child;
  const AuthenticatedShell({super.key, required this.child});

  @override
  State<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<AuthenticatedShell> {
  late final FocusNode _shellFocusNode;

  @override
  void initState() {
    super.initState();
    _shellFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _shellFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _shellFocusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event, AudioPlayerController audio) {
    if (event is! KeyDownEvent) return;
    
    final primaryFocus = FocusManager.instance.primaryFocus;
    bool isTyping = false;
    if (primaryFocus != null) {
      final context = primaryFocus.context;
      if (context != null) {
        if (context.widget is EditableText || 
            context.findAncestorWidgetOfExactType<EditableText>() != null) {
          isTyping = true;
        }
      }
      final label = primaryFocus.debugLabel?.toLowerCase() ?? '';
      if (label.contains('editabletext') || label.contains('textfield')) {
        isTyping = true;
      }
    }
         
    if (isTyping) return;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      audio.togglePlayPause();
    } else if (key == LogicalKeyboardKey.arrowRight) {
      audio.seek(audio.position + const Duration(seconds: 5));
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      audio.seek(audio.position - const Duration(seconds: 5));
    } else if (key == LogicalKeyboardKey.arrowUp) {
      audio.setVolume((audio.volume + 0.1).clamp(0.0, 1.0));
    } else if (key == LogicalKeyboardKey.arrowDown) {
      audio.setVolume((audio.volume - 0.1).clamp(0.0, 1.0));
    } else if (key == LogicalKeyboardKey.keyL) {
      audio.next();
    } else if (key == LogicalKeyboardKey.keyJ) {
      audio.previous();
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.read<AudioPlayerController>();
    final nav = context.watch<NavigationController>();
    final router = GoRouter.of(context);
    final isHomeTab = router.routerDelegate.currentConfiguration.last.matchedLocation == '/home';

    return KeyboardListener(
      focusNode: _shellFocusNode,
      onKeyEvent: (event) => _handleKeyEvent(event, audio),
      child: GestureDetector(
        onTap: () => _shellFocusNode.requestFocus(),
        child: Column(
          children: [
            Expanded(child: widget.child),
            const MiniPlayer(),
            if (isHomeTab) 
              NavigationBar(
                height: 64,
                backgroundColor: AppTheme.surface,
                indicatorColor: AppTheme.surfaceHighlight,
                selectedIndex: nav.index,
                onDestinationSelected: (i) => nav.setIndex(i),
                destinations: [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined, color: _iconColor(nav.index, 0)),
                    selectedIcon: const Icon(Icons.home_rounded, color: AppTheme.textPrimary),
                    label: 'Главная',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.library_music_outlined, color: _iconColor(nav.index, 1)),
                    selectedIcon: const Icon(Icons.library_music_rounded, color: AppTheme.textPrimary),
                    label: 'Медиатека',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded, color: _iconColor(nav.index, 2)),
                    selectedIcon: const Icon(Icons.person_rounded, color: AppTheme.textPrimary),
                    label: 'Профиль',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _iconColor(int index, int i) =>
      index == i ? AppTheme.textPrimary : AppTheme.textSecondary;
}
