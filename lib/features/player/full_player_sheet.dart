import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/audio_player_controller.dart';
import '../../providers/library_controller.dart';
import '../widgets/track_artwork.dart';

Future<void> showFullPlayerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => const _FullPlayerBody(),
  );
}

class _FullPlayerBody extends StatelessWidget {
  const _FullPlayerBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerController>(
      builder: (context, audio, _) {
        final playingTrackId = audio.currentTrack?.id;
        final library = context.watch<LibraryController>();
        final track = library.tracks.cast<dynamic>().firstWhere(
          (t) => t.id == playingTrackId,
          orElse: () => audio.currentTrack,
        );

        if (track == null) {
          Navigator.of(context).pop();
          return const SizedBox.shrink();
        }

        final duration = audio.duration ?? Duration.zero;
        final position = audio.position;

        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              TrackArtwork(url: track.artworkUrl, size: 280, radius: 12),
              const SizedBox(height: 24),
              Text(
                track.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                track.artist,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(track.isLiked ? Icons.favorite : Icons.favorite_border),
                    color: track.isLiked ? Colors.redAccent : AppTheme.textSecondary,
                    onPressed: () => context.read<LibraryController>().toggleLike(track.id),
                  ),
                  if (track.likesCount > 0)
                    Text(
                      '${track.likesCount}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: AppTheme.accent,
                  inactiveTrackColor: AppTheme.surfaceHighlight,
                  thumbColor: AppTheme.textPrimary,
                ),
                child: Slider(
                  value: duration.inMilliseconds > 0
                      ? position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble()
                      : 0,
                  max: duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1,
                  onChanged: (v) {
                    audio.seek(Duration(milliseconds: v.round()));
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatPlayerDuration(position),
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  Text(
                    formatPlayerDuration(duration),
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 48,
                    onPressed: () => audio.togglePlayPause(),
                    icon: Icon(
                      audio.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      color: AppTheme.accent,
                      size: 64,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

String formatPlayerDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds.remainder(60);
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
