import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/audio_player_controller.dart';
import '../../providers/library_controller.dart';
import '../widgets/track_artwork.dart';
import 'widgets/audio_visualizer.dart';

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

class _FullPlayerBody extends StatefulWidget {
  const _FullPlayerBody();

  @override
  State<_FullPlayerBody> createState() => _FullPlayerBodyState();
}

class _FullPlayerBodyState extends State<_FullPlayerBody> {
  bool _showQueue = false;

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioPlayerController>();
    final playingTrackId = audio.currentTrack?.id;
    
    if (playingTrackId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
      });
      return const SizedBox.shrink();
    }

    final library = context.watch<LibraryController>();
    final track = library.tracks.cast<dynamic>().firstWhere(
      (t) => t.id == playingTrackId,
      orElse: () => context.read<AudioPlayerController>().currentTrack,
    );

    if (track == null) return const SizedBox.shrink();

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 48), // Spacer for balance
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _showQueue = !_showQueue),
                icon: Icon(
                  _showQueue ? Icons.music_note_rounded : Icons.queue_music_rounded,
                  color: _showQueue ? AppTheme.accent : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_showQueue) ...[
            TrackArtwork(url: track.artworkUrl, size: 280, radius: 12),
            const SizedBox(height: 12),
            AudioVisualizer(isPlaying: audio.isPlaying),
            const SizedBox(height: 12),
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
          ] else ...[
            SizedBox(
              height: 380,
              child: ReorderableListView.builder(
                itemCount: audio.currentPlaylist.length,
                onReorder: audio.reorder,
                itemBuilder: (context, index) {
                  final t = audio.currentPlaylist[index];
                  final isCurrent = t.id == (audio.currentTrack?.id ?? '');
                  return ListTile(
                    key: ValueKey(t.id),
                    onTap: () => audio.jumpTo(index),
                    leading: TrackArtwork(url: t.artworkUrl, size: 40, radius: 4),
                    title: Text(
                      t.title,
                      style: TextStyle(
                        color: isCurrent ? AppTheme.accent : AppTheme.textPrimary,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(t.artist, style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.drag_handle_rounded, size: 20),
                  );
                },
              ),
            ),
          ],
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
          const _PlayerControls(),
        ],
      ),
    );
  }
}

class _PlayerControls extends StatelessWidget {
  const _PlayerControls();

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioPlayerController>();
    final duration = audio.duration ?? Duration.zero;
    final position = audio.position;

    return Column(
      children: [
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
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: () => audio.toggleShuffle(),
              icon: Icon(
                Icons.shuffle,
                color: audio.shuffleEnabled ? AppTheme.accent : AppTheme.textSecondary,
                size: 24,
              ),
            ),
            IconButton(
              onPressed: audio.hasPrevious || audio.position.inSeconds > 3
                  ? () => audio.previous()
                  : null,
              icon: const Icon(
                Icons.skip_previous_rounded,
                size: 36,
              ),
              color: audio.hasPrevious || audio.position.inSeconds > 3
                  ? AppTheme.textPrimary
                  : AppTheme.textSecondary.withValues(alpha: 0.3),
            ),
            IconButton(
              iconSize: 64,
              onPressed: () => audio.togglePlayPause(),
              padding: EdgeInsets.zero,
              icon: Icon(
                audio.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                color: AppTheme.accent,
                size: 72,
              ),
            ),
            IconButton(
              onPressed: audio.hasNext ? () => audio.next() : null,
              icon: const Icon(
                Icons.skip_next_rounded,
                size: 36,
              ),
              color: audio.hasNext
                  ? AppTheme.textPrimary
                  : AppTheme.textSecondary.withValues(alpha: 0.3),
            ),
            IconButton(
              onPressed: () => audio.toggleLoopMode(),
              icon: Icon(
                audio.loopMode == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                color: audio.loopMode != LoopMode.off ? AppTheme.accent : AppTheme.textSecondary,
                size: 24,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _VolumeControl(audio: audio),
      ],
    );
  }
}

class _VolumeControl extends StatelessWidget {
  final AudioPlayerController audio;
  const _VolumeControl({required this.audio});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          audio.volume == 0 ? Icons.volume_off_rounded : Icons.volume_down_rounded,
          color: AppTheme.textSecondary,
          size: 20,
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: AppTheme.textPrimary.withValues(alpha: 0.8),
              inactiveTrackColor: AppTheme.surfaceHighlight,
              thumbColor: AppTheme.textPrimary,
            ),
            child: Slider(
              value: audio.volume,
              onChanged: (v) => audio.setVolume(v),
            ),
          ),
        ),
        const Icon(
          Icons.volume_up_rounded,
          color: AppTheme.textSecondary,
          size: 20,
        ),
      ],
    );
  }
}

String formatPlayerDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds.remainder(60);
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
