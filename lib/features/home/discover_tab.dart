import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/track.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/track_repository.dart';
import '../../providers/audio_player_controller.dart';
import '../../providers/library_controller.dart';
import '../widgets/track_artwork.dart';

class DiscoverTab extends StatelessWidget {
  const DiscoverTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Consumer<LibraryController>(
        builder: (context, lib, _) {
          if (lib.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
          }
          final tracks = lib.tracks;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                floating: true,
                backgroundColor: AppTheme.background.withValues(alpha: 0.94),
                surfaceTintColor: Colors.transparent,
                title: Text(
                  'Главное',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: AppTheme.textPrimary, size: 28),
                      tooltip: 'Добавить трек',
                      onPressed: () => context.push('/add-track'),
                    ),
                  ),
                ],
              ),

              // Поиск пользователей и треков
              const SliverToBoxAdapter(child: _GlobalSearchSection()),

              SliverToBoxAdapter(
                child: Consumer<AudioPlayerController>(
                  builder: (context, audio, _) {
                    final currentTrack = audio.currentTrack;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: _buildHeroCard(context, currentTrack, tracks),
                    );
                  }
                ),
              ),
              if (tracks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Специально для вас',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildMixesRow(),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                    child: Text(
                      'Популярное сегодня',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 220,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: tracks.length > 10 ? 10 : tracks.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (context, i) {
                        return _HorizontalTrackCard(
                          track: tracks[i],
                          onTap: () => context.read<AudioPlayerController>().playTrack(tracks[i], playlist: tracks),
                          onMore: () => _showTrackOptions(context, tracks[i]),
                        );
                      },
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
                    child: Text(
                      'Вся коллекция',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 24),
                  sliver: SliverList.builder(
                    itemCount: tracks.length,
                    itemBuilder: (context, i) {
                      final t = tracks[i];
                      return _VerticalTrackTile(
                        track: t,
                        onPlay: () => context.read<AudioPlayerController>().playTrack(t, playlist: tracks),
                        onMore: () => _showTrackOptions(context, t),
                      );
                    },
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, Track? track, List<Track> tracks) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF0E932), // AppTheme.accent
            Color(0xFFE5DE25), // AppTheme.accentDim
            Color(0xFF635F0A), // Darker yellow/olive
          ],
        ),
        boxShadow: [
          BoxShadow(
             color: AppTheme.accent.withValues(alpha: 0.2),
             blurRadius: 40,
             offset: const Offset(0, 15),
          )
        ]
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Фоновое изображение с наложением
          Positioned.fill(
            child: Opacity(
              opacity: 0.7,
              child: Image.asset(
                'assets/images/moya_volna.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),
          ),
          // Градиентное наложение для читаемости текста снизу
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'Моя волна',
                  style: TextStyle(
                    fontSize: 32, 
                    fontWeight: FontWeight.w900, 
                    color: Colors.white,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  track != null ? 'Сейчас играет: ${track.title}' : 'Бесконечный поток музыки под ваше настроение',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15, 
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: tracks.isNotEmpty ? () => context.read<AudioPlayerController>().playWave(tracks) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(120, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded, size: 24),
                          SizedBox(width: 8),
                          Text('Слушать', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: track != null ? () => context.read<LibraryController>().toggleLike(track.id) : null,
                      icon: Icon(
                        track != null && track.isLiked ? Icons.favorite : Icons.favorite_border_rounded, 
                        color: Colors.white
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
              leading: Icon(track.isLiked ? Icons.favorite : Icons.favorite_border, 
                color: track.isLiked ? AppTheme.accent : AppTheme.textSecondary),
              title: Text(track.isLiked ? 'Удалить из любимых' : 'Добавить в любимые'),
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

  Widget _buildMixesRow() {
    return SizedBox(
      height: 160,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _MixCard(
            title: 'Энергия', 
            subtitle: 'Бодрые треки', 
            color: const Color(0xFFFF5722),
            icon: Icons.bolt_rounded,
          ),
          const SizedBox(width: 12),
          _MixCard(
            title: 'Хип-хоп', 
            subtitle: 'Ритм улиц', 
            color: const Color(0xFF2196F3),
            icon: Icons.mic_external_on_rounded,
          ),
          const SizedBox(width: 12),
          _MixCard(
            title: 'Танцы', 
            subtitle: 'Зажигай', 
            color: const Color(0xFFE91E63),
            icon: Icons.nightlife_rounded,
          ),
          const SizedBox(width: 12),
          _MixCard(
            title: 'Релакс', 
            subtitle: 'Спокойствие', 
            color: const Color(0xFF4CAF50),
            icon: Icons.spa_rounded,
          ),
        ],
      ),
    );
  }
}

class _MixCard extends StatelessWidget {
  const _MixCard({
    required this.title, 
    required this.subtitle, 
    required this.color,
    required this.icon,
  });
  
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // TODO: Navigation or Filter
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.8),
              color,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HorizontalTrackCard extends StatelessWidget {
  const _HorizontalTrackCard({
    required this.track, 
    required this.onTap,
    required this.onMore,
  });

  final Track track;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                TrackArtwork(url: track.artworkUrl, size: 140, radius: 12),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceHighlight.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: AppTheme.textPrimary, size: 20),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onMore,
                  child: const Icon(Icons.more_vert, size: 18, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalTrackTile extends StatelessWidget {
  const _VerticalTrackTile({
    required this.track, 
    required this.onPlay,
    required this.onMore,
  });

  final Track track;
  final VoidCallback onPlay;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final isPlayingThis = context.select<AudioPlayerController, bool>(
      (audio) => audio.currentTrack?.id == track.id,
    );

    return InkWell(
      onTap: onPlay,
      splashColor: AppTheme.accent.withValues(alpha: 0.1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                   TrackArtwork(url: track.artworkUrl, size: 52, radius: 8),
                   if (isPlayingThis)
                     Container(
                       decoration: BoxDecoration(
                         color: Colors.black.withValues(alpha: 0.6),
                         borderRadius: BorderRadius.circular(8),
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
                       fontWeight: isPlayingThis ? FontWeight.bold : FontWeight.w600,
                       color: isPlayingThis ? AppTheme.accent : AppTheme.textPrimary,
                       letterSpacing: -0.3,
                     ),
                     maxLines: 1, 
                     overflow: TextOverflow.ellipsis,
                   ),
                   const SizedBox(height: 2),
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
                 IconButton(
                   icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textSecondary),
                   onPressed: onMore,
                 )
              ],
            )
          ],
        ),
      ),
    );
  }
}

// ─── Поиск пользователей ────────────────────────────────────────────────────

// ─── Глобальный поиск (Пользователи + Треки) ────────────────────────────────

class _GlobalSearchSection extends StatefulWidget {
  const _GlobalSearchSection();

  @override
  State<_GlobalSearchSection> createState() => _GlobalSearchSectionState();
}

class _GlobalSearchSectionState extends State<_GlobalSearchSection> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<UserProfile> _userResults = [];
  List<Track> _trackResults = [];
  bool _searching = false;
  bool _active = false; // виден ли блок результатов

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _userResults = [];
        _trackResults = [];
        _active = false;
        _searching = false;
      });
      return;
    }
    setState(() {
      _active = true;
      _searching = true;
    });
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final userRepo = UserRepository(prefs);
        final trackRepo = TrackRepository(prefs);

        final query = value.trim();
        // Запускаем поиск людей и треков параллельно
        final results = await Future.wait([
          userRepo.searchUsers(query),
          trackRepo.searchTracks(query),
        ]);

        if (!mounted) return;
        setState(() {
          _userResults = results[0] as List<UserProfile>;
          _trackResults = results[1] as List<Track>;
          _searching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _searching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Строка поиска
          TextField(
            controller: _controller,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: 'Найти музыку или людей...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 22),
              suffixIcon: _active
                  ? IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                      onPressed: () {
                        _controller.clear();
                        setState(() {
                          _userResults = [];
                          _trackResults = [];
                          _active = false;
                          _searching = false;
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.surfaceHighlight,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.accent, width: 1.0),
              ),
            ),
          ),

          // Результаты поиска
          if (_active) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: _searching
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Секция Треков
                        if (_trackResults.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text('ТРЕКИ',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2)),
                          ),
                          ..._trackResults.map((track) {
                            return ListTile(
                              onTap: () {
                                FocusScope.of(context).unfocus();
                                context.read<AudioPlayerController>().playTrack(track, playlist: _trackResults);
                              },
                              leading: TrackArtwork(url: track.artworkUrl, size: 40, radius: 4),
                              title: Text(track.title,
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(track.artist,
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                              trailing: const Icon(Icons.play_circle_outline, color: AppTheme.accent),
                            );
                          }),
                        ],

                        // Секция Людей
                        if (_userResults.isNotEmpty) ...[
                          if (_trackResults.isNotEmpty) const Divider(height: 1),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text('ЛЮДИ',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2)),
                          ),
                          ..._userResults.map((user) {
                            return ListTile(
                              onTap: () {
                                FocusScope.of(context).unfocus();
                                context.push('/profile/${user.id}');
                              },
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundColor: AppTheme.surfaceHighlight,
                                backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                                    ? NetworkImage(user.avatarUrl!)
                                    : null,
                                child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                                    ? Text(
                                        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                      )
                                    : null,
                              ),
                              title: Text(user.displayName,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
                            );
                          }),
                        ],

                        if (_trackResults.isEmpty && _userResults.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                            child: Center(
                              child: Text('Ничего не найдено 😕',
                                  style: TextStyle(color: AppTheme.textSecondary)),
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
