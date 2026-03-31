import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/audio_player_controller.dart';
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
  late final FocusNode _shellFocusNode;

  @override
  void initState() {
    super.initState();
    _shellFocusNode = FocusNode();
    // Запрашиваем фокус один раз после постройки первого кадра
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

    // Максимально надежная проверка на режим "печати"
    bool isTyping = false;
    if (primaryFocus != null) {
      final context = primaryFocus.context;
      if (context != null) {
        // Проверяем само виджет и всех его предков на наличие текстового ввода
        if (context.widget is EditableText || 
            context.findAncestorWidgetOfExactType<EditableText>() != null) {
          isTyping = true;
        }
      }
      // Дополнительная проверка по системной метке фокуса
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

  int _lastIndex = 0;

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationController>();
    final index = nav.index;
    final audio = context.read<AudioPlayerController>();

    // Если вкладка изменилась - возвращаем фокус оболочке
    if (_lastIndex != index) {
      _lastIndex = index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _shellFocusNode.requestFocus();
      });
    }

    return KeyboardListener(
      focusNode: _shellFocusNode,
      onKeyEvent: (event) => _handleKeyEvent(event, audio),
      child: GestureDetector(
        onTap: () {
          // Убираем фокус с полей ввода при клике в пустое место
          final currentFocus = FocusScope.of(context);
          if (!currentFocus.hasPrimaryFocus) {
            currentFocus.unfocus();
          }
        },
        child: Scaffold(
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
        ),
      ),
    );
  }

  Color _iconColor(int index, int i) =>
      index == i ? AppTheme.textPrimary : AppTheme.textSecondary;
}
