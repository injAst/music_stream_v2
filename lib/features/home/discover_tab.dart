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
                backgroundColor: AppTheme.background.withValues(alpha: 0.9),
                title: const Text(
                  'Главное',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppTheme.textSecondary),
                    onPressed: () => context.push('/add-track'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: AppTheme.textSecondary),
                    onPressed: () {},
                  ),
                ],
              ),

              // Поиск пользователей и треков
              const SliverToBoxAdapter(child: _GlobalSearchSection()),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: _buildHeroCard(context, tracks.isNotEmpty ? tracks.first : null, tracks),
                ),
              ),
              if (tracks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Text(
                      'Специально для вас',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildMixesRow(),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
                    child: Text(
                      'Популярное',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: tracks.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (context, i) {
                        return _HorizontalTrackCard(
                          track: tracks[i],
                          onTap: () => context.read<AudioPlayerController>().playTrack(tracks[i], playlist: tracks),
                        );
                      },
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
                    child: Text(
                      'Вся коллекция',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                SliverList.builder(
                  itemCount: tracks.length,
                  itemBuilder: (context, i) {
                    final t = tracks[i];
                    return _VerticalTrackTile(
                      track: t,
                      onPlay: () => context.read<AudioPlayerController>().playTrack(t, playlist: tracks),
                    );
                  },
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
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: const DecorationImage(
          image: AssetImage('assets/images/moya_volna.png'),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
             color: AppTheme.accent.withValues(alpha: 0.1),
             blurRadius: 30,
             offset: const Offset(0, 5),
          )
        ]
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 90,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Моя волна',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              track != null ? '${track.title} · ${track.artist}' : 'Бесконечный поток музыки',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: AppTheme.accent,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: track != null ? () => context.read<AudioPlayerController>().playTrack(track, playlist: tracks) : null,
                          child: const Padding(
                            padding: EdgeInsets.all(16),
                            child: Icon(Icons.play_arrow_rounded, size: 32, color: AppTheme.onAccent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMixesRow() {
    return SizedBox(
      height: 140,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: const [
          _MixCard(title: 'Энергичный', imagePath: 'assets/images/energy_mix.png'),
          SizedBox(width: 16),
          _MixCard(title: 'Хип-хоп', imagePath: 'assets/images/hip_hop_mix.png'),
          SizedBox(width: 16),
          _MixCard(title: 'Танцевальный', imagePath: 'assets/images/moya_volna.png'),
        ],
      ),
    );
  }
}

class _MixCard extends StatelessWidget {
  const _MixCard({required this.title, required this.imagePath});
  final String title;
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(image: AssetImage(imagePath), fit: BoxFit.cover),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
             begin: Alignment.topCenter,
             end: Alignment.bottomCenter,
             colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
          ),
        ),
        padding: const EdgeInsets.all(12),
        alignment: Alignment.bottomLeft,
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }
}

class _HorizontalTrackCard extends StatelessWidget {
  const _HorizontalTrackCard({required this.track, required this.onTap});

  final Track track;
  final VoidCallback onTap;

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
            const SizedBox(height: 12),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalTrackTile extends StatelessWidget {
  const _VerticalTrackTile({required this.track, required this.onPlay});

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                children: [
                  TrackArtwork(url: track.artworkUrl, size: 48, radius: 6),
                  if (isPlayingThis)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Icon(Icons.volume_up_rounded, color: AppTheme.textPrimary, size: 24),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
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
                   icon: Icon(track.isLiked ? Icons.favorite : Icons.favorite_border, size: 22),
                   color: track.isLiked ? Colors.redAccent : AppTheme.textSecondary,
                   onPressed: () => context.read<LibraryController>().toggleLike(track.id),
                 ),
                 IconButton(
                   icon: const Icon(Icons.more_horiz, size: 22, color: AppTheme.textSecondary),
                   onPressed: () {},
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
              hintText: 'Найти музыку или друзей...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
              suffixIcon: _active
                  ? IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textSecondary),
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
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
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
