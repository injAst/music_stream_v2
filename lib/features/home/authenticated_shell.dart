import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/audio_player_controller.dart';
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

    return KeyboardListener(
      focusNode: _shellFocusNode,
      onKeyEvent: (event) => _handleKeyEvent(event, audio),
      child: GestureDetector(
        onTap: () => _shellFocusNode.requestFocus(),
        child: Column(
          children: [
            Expanded(child: widget.child),
            const MiniPlayer(),
          ],
        ),
      ),
    );
  }
}
