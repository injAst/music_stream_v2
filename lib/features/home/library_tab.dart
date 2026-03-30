import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/track.dart';
import '../../providers/audio_player_controller.dart';
import '../../providers/auth_controller.dart';
import '../../providers/library_controller.dart';
import '../../providers/navigation_controller.dart';
import '../widgets/track_artwork.dart';

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Consumer<LibraryController>(
        builder: (context, lib, _) {
          if (lib.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
          }

          // Показываем только лайкнутые треки
          var tracks = lib.tracks.where((t) => t.isLiked).toList();
          if (_searchQuery.trim().isNotEmpty) {
            final q = _searchQuery.trim().toLowerCase();
            tracks = tracks.where((t) => 
               t.title.toLowerCase().contains(q) || 
               t.artist.toLowerCase().contains(q)).toList();
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Шапка плейлиста с градиентом
              SliverToBoxAdapter(
                child: _buildHeader(context, tracks),
              ),

              // Строка поиска
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickySearchBarDelegate(
                  onSearch: (v) => setState(() => _searchQuery = v),
                ),
              ),

              // Список треков
              if (tracks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(top: 8),
                  sliver: SliverList.builder(
                    itemCount: tracks.length,
                    itemBuilder: (context, i) {
                      final t = tracks[i];
                      return _TrackTile(
                        track: t,
                        onPlay: () => context.read<AudioPlayerController>().playTrack(t, playlist: tracks),
                        onLongPress: () => _showTrackOptions(context, t),
                      );
                    },
                  ),
                ),
                
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<Track> tracks) {
    final auth = context.read<AuthController>();
    final username = auth.user?.displayName ?? 'Пользователь';

    final isDesktop = MediaQuery.of(context).size.width > 600;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.accent.withValues(alpha: 0.3),
            AppTheme.background,
          ],
          stops: const [0.0, 0.8],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
      child: isDesktop 
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildCoverImage(size: 232),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('ПЛЕЙЛИСТ', style: theme.textTheme.labelMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    )),
                    const SizedBox(height: 8),
                    const Text('Мне нравится', style: TextStyle(
                      fontSize: 72, 
                      fontWeight: FontWeight.w900, 
                      height: 1.0,
                      letterSpacing: -2,
                    )),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 12,
                          backgroundColor: AppTheme.surfaceHighlight,
                          child: Icon(Icons.person, size: 16, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        const Icon(Icons.circle, size: 4, color: AppTheme.textSecondary),
                        const SizedBox(width: 8),
                        Text('${tracks.length} треков', style: const TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _HeaderActions(tracks: tracks),
                  ],
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Center(child: _buildCoverImage(size: MediaQuery.of(context).size.width * 0.55)),
               const SizedBox(height: 32),
               Text('ПЛЕЙЛИСТ', style: theme.textTheme.labelSmall?.copyWith(
                 color: AppTheme.textSecondary,
                 letterSpacing: 1.2,
                 fontWeight: FontWeight.bold,
               )),
               const SizedBox(height: 4),
               const Text('Мне нравится', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
               const SizedBox(height: 12),
               Row(
                 children: [
                   Text(username, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                   const SizedBox(width: 8),
                   const Icon(Icons.circle, size: 4, color: AppTheme.textSecondary),
                   const SizedBox(width: 8),
                   Text('${tracks.length} треков', style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                 ],
               ),
               const SizedBox(height: 24),
               _HeaderActions(tracks: tracks),
            ],
          ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceHighlight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_border_rounded, size: 64, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          const Text(
            'Здесь будет ваша музыка',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Добавляйте треки в "Мне нравится",\nчтобы они всегда были под рукой.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.read<NavigationController>().setIndex(0),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.textPrimary,
              foregroundColor: AppTheme.background,
              minimumSize: const Size(180, 48),
            ),
            child: const Text('Найти что-нибудь'),
          ),
        ],
      ),
    );
  }

  void _showTrackOptions(BuildContext context, Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  TrackArtwork(url: track.artworkUrl, size: 56, radius: 4),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(track.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(track.artist, style: const TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.favorite, color: Colors.redAccent),
              title: const Text('Удалить из любимых'),
              onTap: () {
                Navigator.pop(context);
                context.read<LibraryController>().toggleLike(track.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Добавить в плейлист'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement playlists
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Поделиться'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
           BoxShadow(
             color: Colors.black.withValues(alpha: 0.5),
             blurRadius: 20,
             offset: const Offset(0, 10),
           ),
        ]
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/heart_cover.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: AppTheme.surfaceHighlight),
      ),
    );
  }

}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({required this.tracks});
  final List<Track> tracks;

  @override
  Widget build(BuildContext context) {
    final hasTracks = tracks.isNotEmpty;
    
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: hasTracks 
            ? () => context.read<AudioPlayerController>().playTrack(tracks.first, playlist: tracks)
            : null,
          icon: const Icon(Icons.play_arrow_rounded, size: 28),
          label: const Text('Слушать', style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
             minimumSize: const Size(140, 48),
             padding: const EdgeInsets.symmetric(horizontal: 24),
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: hasTracks 
            ? () async {
                final audio = context.read<AudioPlayerController>();
                // Включаем перемешивание и запускаем первый случайный трек
                if (!audio.shuffleEnabled) await audio.toggleShuffle();
                audio.playTrack(tracks[0], playlist: tracks);
              }
            : null,
          icon: const Icon(Icons.shuffle),
          color: AppTheme.textSecondary,
        ),
      ],
    );
  }
}

class _StickySearchBarDelegate extends SliverPersistentHeaderDelegate {
  const _StickySearchBarDelegate({required this.onSearch});
  final ValueChanged<String> onSearch;

  @override
  double get minExtent => 72;
  @override
  double get maxExtent => 72;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.background,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: TextField(
        onChanged: onSearch,
        decoration: InputDecoration(
          hintText: 'Поиск в любимых треках',
          prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
          filled: true,
          fillColor: AppTheme.surfaceHighlight,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.accent, width: 1),
          )
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickySearchBarDelegate oldDelegate) => false;
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.track, 
    required this.onPlay,
    this.onLongPress,
  });

  final Track track;
  final VoidCallback onPlay;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isPlayingThis = context.select<AudioPlayerController, bool>(
      (audio) => audio.currentTrack?.id == track.id,
    );

    return InkWell(
      onTap: onPlay,
      onLongPress: onLongPress,
      splashColor: AppTheme.accent.withValues(alpha: 0.1),
      highlightColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isPlayingThis ? AppTheme.accent.withValues(alpha: 0.05) : Colors.transparent,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                children: [
                   TrackArtwork(url: track.artworkUrl, size: 52, radius: 4),
                   if (isPlayingThis)
                     Container(
                       decoration: BoxDecoration(
                         color: Colors.black.withValues(alpha: 0.6),
                         borderRadius: BorderRadius.circular(4),
                       ),
                       child: const Center(
                         child: Icon(Icons.volume_up_rounded, color: AppTheme.accent, size: 24),
                       ),
                     ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                     track.title,
                     style: TextStyle(
                       fontSize: 16, 
                       fontWeight: isPlayingThis ? FontWeight.bold : FontWeight.w500,
                       color: isPlayingThis ? AppTheme.accent : AppTheme.textPrimary,
                     ),
                     maxLines: 1, 
                     overflow: TextOverflow.ellipsis,
                   ),
                   const SizedBox(height: 4),
                   Text(
                     track.artist,
                     style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                     maxLines: 1, 
                     overflow: TextOverflow.ellipsis,
                   ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                 IconButton(
                   icon: Icon(track.isLiked ? Icons.favorite : Icons.favorite_border, size: 20),
                   color: track.isLiked ? AppTheme.accent : AppTheme.textSecondary,
                   onPressed: () => context.read<LibraryController>().toggleLike(track.id),
                 ),
                 const SizedBox(width: 4),
                 Text(
                   _formatSec(track.durationSeconds),
                   style: const TextStyle(
                     color: AppTheme.textSecondary, 
                     fontSize: 13, 
                     fontFeatures: [FontFeature.tabularFigures()],
                   ),
                 ),
                 const SizedBox(width: 4),
                 IconButton(
                   icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 20),
                   onPressed: onLongPress,
                 )
              ],
            )
          ],
        ),
      ),
    );
  }
  
  String _formatSec(int? sec) {
    if (sec == null) return '--:--';
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2,'0')}';
  }
}
