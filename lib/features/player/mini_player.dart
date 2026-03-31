import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/audio_player_controller.dart';
import '../../providers/library_controller.dart';
import '../widgets/track_artwork.dart';
import 'full_player_sheet.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  // Направление анимации: 1.0 — свайп влево (вперед), -1.0 — свайп вправо (назад)
  double _slideDirection = 1.0;

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerController>(
      builder: (context, audio, _) {
        final track = audio.currentTrack;
        if (track == null) return const SizedBox.shrink();

        // Скрываем, если не играет И прошло больше часа с момента последнего прослушивания
        final lastPlayed = audio.lastPlayedAt;
        final isRecent = lastPlayed != null && 
            DateTime.now().difference(lastPlayed).inMinutes < 60;
        
        if (!audio.isPlaying && !isRecent) {
          return const SizedBox.shrink();
        }

        return Material(
          color: AppTheme.surfaceHighlight,
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! < 0) {
                setState(() => _slideDirection = 1.0);
                audio.next();
              } else if (details.primaryVelocity! > 0) {
                setState(() => _slideDirection = -1.0);
                audio.previous();
              }
            },
            child: InkWell(
              onTap: () => showFullPlayerSheet(context),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      // Смещение зависит от того, заменяется ли виджет или появляется новый
                      final offset = child.key == ValueKey(track.id)
                          ? Offset(_slideDirection, 0.0)
                          : Offset(-_slideDirection, 0.0);

                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: offset,
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        )),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      key: ValueKey(track.id), // Важно для работы AnimatedSwitcher
                      child: Row(
                        children: [
                          TrackArtwork(
                            url: track.artworkUrl,
                            size: 48,
                            radius: 4,
                            heroTag: track.id,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Consumer<LibraryController>(
                            builder: (context, lib, _) {
                              final isLiked = lib.tracks.any((t) => t.id == track.id && t.isLiked);
                              return IconButton(
                                onPressed: () => lib.toggleLike(track.id),
                                icon: Icon(
                                  isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: isLiked ? Colors.redAccent : AppTheme.textSecondary.withValues(alpha: 0.8),
                                  size: 24,
                                ),
                              );
                            },
                          ),
                          IconButton(
                            onPressed: () => audio.togglePlayPause(),
                            icon: Icon(
                              audio.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: AppTheme.textPrimary,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
