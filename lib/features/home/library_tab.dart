import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/track.dart';
import '../../providers/audio_player_controller.dart';
import '../../providers/auth_controller.dart';
import '../../providers/library_controller.dart';
import '../widgets/track_artwork.dart';

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  String _searchQuery = '';
  int _selectedFilter = 0;

  final List<String> _filters = [
    'Всё',
    'Бодрое',
    'Рэп и хип-хоп',
    'Весёлое',
    'Поп',
    'Танцевальная',
    'Грустное',
    'Электроника'
  ];

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
            slivers: [
              // Шапка плейлиста
              SliverToBoxAdapter(
                child: _buildHeader(context, tracks.isNotEmpty),
              ),

              // Строка поиска и фильтры
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickySearchBarDelegate(
                  child: _buildSearchAndFilters(),
                ),
              ),

              // Список треков
              if (tracks.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'Нет треков, удовлетворяющих запросу.\nИли вы еще ничего не добавили в "Мне нравится".',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: tracks.length,
                  itemBuilder: (context, i) {
                    final t = tracks[i];
                    return _TrackTile(
                      track: t,
                      onPlay: () => context.read<AudioPlayerController>().playTrack(t, playlist: tracks),
                    );
                  },
                ),
                
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool hasTracks) {
    final auth = context.read<AuthController>();
    final username = auth.user?.displayName ?? 'Пользователь';

    // Получаем текущий список треков из Consumer выше или через Provider
    final lib = context.read<LibraryController>();
    final tracks = lib.tracks.where((t) => t.isLiked).toList();

    // Для десктопа/планшета делаем горизонтальный лейаут, для мобильного - вертикальный.
    final isDesktop = MediaQuery.of(context).size.width > 600;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
      child: isDesktop 
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildCoverImage(size: 200),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('Плейлист', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text('Мне нравится', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, height: 1.1)),
                    const SizedBox(height: 12),
                    Text(username, style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                    const SizedBox(height: 24),
                    _HeaderActions(tracks: tracks),
                  ],
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Center(child: _buildCoverImage(size: MediaQuery.of(context).size.width * 0.6)),
               const SizedBox(height: 24),
               const Text('Плейлист', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
               const SizedBox(height: 4),
               const Text('Мне нравится', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
               const SizedBox(height: 8),
               Text(username, style: const TextStyle(fontSize: 16)),
               const SizedBox(height: 16),
               _HeaderActions(tracks: tracks),
            ],
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

  Widget _buildSearchAndFilters() {
    return Container(
      color: AppTheme.background, // Небольшой фон, чтобы при скролле перекрывал треки
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Поиск трека',
              prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
              filled: true,
              fillColor: AppTheme.surfaceHighlight, // цвет строки поиска под дизайн
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppTheme.surfaceHighlight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppTheme.surfaceHighlight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppTheme.accent),
              )
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_filters.length, (i) {
                final isSelected = _selectedFilter == i;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_filters[i]),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedFilter = i),
                    backgroundColor: AppTheme.surfaceHighlight,
                    selectedColor: AppTheme.accent,
                    checkmarkColor: AppTheme.onAccent,
                    labelStyle: TextStyle(
                       color: isSelected ? AppTheme.onAccent : AppTheme.textPrimary,
                       fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide.none,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
        ],
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
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.more_horiz),
          color: AppTheme.textSecondary,
        ),
      ],
    );
  }
}

class _StickySearchBarDelegate extends SliverPersistentHeaderDelegate {
  const _StickySearchBarDelegate({required this.child});
  final Widget child;

  @override
  double get minExtent => 140; // Примерная высота TextField + Chips
  @override
  double get maxExtent => 140;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({required this.track, required this.onPlay});

  final Track track;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final isPlayingThis = context.select<AudioPlayerController, bool>(
      (audio) => audio.currentTrack?.id == track.id,
    );

    return InkWell(
      onTap: onPlay,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                children: [
                  TrackArtwork(url: track.artworkUrl, size: 48, radius: 4),
                  if (isPlayingThis)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: Icon(Icons.volume_up_rounded, color: AppTheme.textPrimary, size: 24),
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
                       fontWeight: isPlayingThis ? FontWeight.bold : FontWeight.normal,
                       color: isPlayingThis ? AppTheme.accent : AppTheme.textPrimary,
                     ),
                     maxLines: 1, 
                     overflow: TextOverflow.ellipsis,
                   ),
                   const SizedBox(height: 4),
                   Text(
                     track.artist,
                     style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
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
                   icon: Icon(track.isLiked ? Icons.favorite : Icons.favorite_border),
                   color: track.isLiked ? Colors.redAccent : AppTheme.textSecondary,
                   onPressed: () => context.read<LibraryController>().toggleLike(track.id),
                 ),
                 const SizedBox(width: 8),
                 Text(
                   _formatSec(track.durationSeconds),
                   style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                 ),
                 const SizedBox(width: 8),
                 IconButton(
                   icon: const Icon(Icons.more_horiz, color: AppTheme.textSecondary),
                   onPressed: () {},
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
