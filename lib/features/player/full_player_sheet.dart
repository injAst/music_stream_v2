import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:google_fonts/google_fonts.dart';

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
  bool _showLyrics = false;

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final screenHeight = constraints.maxHeight;
        
        // Адаптивные размеры обложки
        double artworkSize;
        if (isLandscape) {
          artworkSize = 200;
        } else if (screenHeight < 650) {
          artworkSize = 160;
        } else if (screenHeight < 750) {
          artworkSize = 190;
        } else if (screenHeight < 850) {
          artworkSize = 220;
        } else {
          artworkSize = 280;
        }
        
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Индикатор закрытия и кнопка очереди
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 48),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => setState(() {
                            _showLyrics = !_showLyrics;
                            if (_showLyrics) _showQueue = false;
                          }),
                          icon: Icon(
                            _showLyrics ? Icons.lyrics_rounded : Icons.lyrics_outlined,
                            color: _showLyrics ? AppTheme.accent : AppTheme.textSecondary,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() {
                            _showQueue = !_showQueue;
                            if (_showQueue) _showLyrics = false;
                          }),
                          icon: Icon(
                            _showQueue ? Icons.queue_music_rounded : Icons.queue_music_outlined,
                            color: _showQueue ? AppTheme.accent : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                if (_showQueue)
                  _buildQueueView(audio)
                else if (_showLyrics)
                  _buildLyricsView(track)
                else if (isLandscape)
                  _buildLandscapeLayout(audio, track, artworkSize)
                else
                  _buildPortraitLayout(audio, track, artworkSize, screenHeight),

                const SizedBox(height: 12),
                const _PlayerControls(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPortraitLayout(AudioPlayerController audio, dynamic track, double artworkSize, double screenHeight) {
    final bool isSmall = screenHeight < 680;
    
    return Column(
      children: [
        TrackArtwork(
          url: track.artworkUrl, 
          size: artworkSize, 
          radius: 12,
          heroTag: track.id,
        ),
        if (screenHeight > 680) ...[
          const SizedBox(height: 12),
          AudioVisualizer(isPlaying: audio.isPlaying),
        ],
        SizedBox(height: isSmall ? 12 : 16),
        Text(
          '${track.artist} - ${track.title}',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: isSmall ? 18 : 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          track.artist,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: isSmall ? 13 : 15,
            letterSpacing: 0.2,
          ),
        ),
        SizedBox(height: isSmall ? 12 : 16),
        _buildLikeButton(track),
      ],
    );
  }

  Widget _buildLandscapeLayout(AudioPlayerController audio, dynamic track, double artworkSize) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TrackArtwork(
          url: track.artworkUrl, 
          size: artworkSize, 
          radius: 12,
          heroTag: track.id,
        ),
        const SizedBox(width: 32),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${track.artist} - ${track.title}',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                track.artist,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              _buildLikeButton(track),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQueueView(AudioPlayerController audio) {
    return SizedBox(
      height: 400,
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
    );
  }

  Widget _buildLyricsView(dynamic track) {
    return Container(
      height: 380,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ShaderMask(
        shaderCallback: (rect) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
            stops: [0.0, 0.1, 0.9, 1.0],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 40),
              _lyricLine("Я вижу этот свет", true),
              _lyricLine("Он манит за собой", false),
              _lyricLine("В пространстве нет границ", false),
              _lyricLine("Где мы найдем покой", false),
              _lyricLine("Звучат аккорды дня", false),
              _lyricLine("В сиянии огней", false),
              _lyricLine("И музыка ведет", false),
              _lyricLine("К мечте твоей и моей", false),
              _lyricLine("Сквозь шум ночных дорог", false),
              _lyricLine("Сквозь холод горьких слов", false),
              _lyricLine("Мы сохраним в сердцах", false),
              _lyricLine("Ту вечную любовь", false),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lyricLine(String text, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
          fontSize: active ? 26 : 22,
          fontWeight: active ? FontWeight.w900 : FontWeight.w600,
          color: active ? AppTheme.accent : Colors.white.withValues(alpha: 0.4),
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildLikeButton(dynamic track) {
    return GestureDetector(
      onTap: () => context.read<LibraryController>().toggleLike(track.id),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            track.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: track.isLiked ? Colors.redAccent : AppTheme.textSecondary,
            size: 28,
          ),
          if (track.likesCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${track.likesCount}',
              style: const TextStyle(
                color: AppTheme.textSecondary, 
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
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
        const SizedBox(height: 16),
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
