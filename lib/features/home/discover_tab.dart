import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/track.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/track_repository.dart';
import '../../core/config/api_config.dart';
import '../../providers/audio_player_controller.dart';
import '../../providers/library_controller.dart';
import '../widgets/track_artwork.dart';

String _formatDuration(int? seconds) {
  if (seconds == null || seconds <= 0) return '--:--';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

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
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 120,
                backgroundColor: AppTheme.background.withValues(alpha: 0.9),
                surfaceTintColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 20),
                  title: Text(
                    'Обзор',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontSize: 32,
                      letterSpacing: -1.0,
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.textSecondary),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Поиск
              const SliverToBoxAdapter(child: _GlobalSearchSection()),

              // 1. Featured Carousel
              SliverToBoxAdapter(
                child: _FeaturedCarousel(tracks: tracks),
              ),

              if (tracks.isNotEmpty) ...[
                _buildSectionHeader(context, 'Новые релизы', () {}),
                SliverToBoxAdapter(
                  child: _NewReleasesGrid(tracks: tracks),
                ),

                _buildSectionHeader(context, 'В тренде', () {}),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: tracks.length > 8 ? 8 : tracks.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (context, i) {
                        return _TrendingTrackCard(
                          track: tracks[i],
                          onTap: () => context.read<AudioPlayerController>().playTrack(tracks[i], playlist: tracks),
                        );
                      },
                    ),
                  ),
                ),

                _buildSectionHeader(context, 'Рекомендации', () {}),
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 120),
                  sliver: SliverList.builder(
                    itemCount: tracks.length > 10 ? 10 : tracks.length,
                    itemBuilder: (context, i) {
                      final t = tracks[tracks.length - 1 - i];
                      return _VerticalTrackTile(
                        track: t,
                        onPlay: () => context.read<AudioPlayerController>().playTrack(t, playlist: tracks),
                        onMore: () => _showTrackOptions(context, t),
                      );
                    },
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, VoidCallback onSeeAll) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            TextButton(
              onPressed: onSeeAll,
              child: const Text('Все', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showTrackOptions(BuildContext context, Track track) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 140),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    TrackArtwork(url: track.artworkUrl, size: 56, radius: 4, heroTag: 'opt_${track.id}'),
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
                onTap: () { Navigator.pop(context); },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sub Widgets ───────────────────────────────────────────────────────────

class _FeaturedCarousel extends StatelessWidget {
  const _FeaturedCarousel({required this.tracks});
  final List<Track> tracks;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) return const SizedBox.shrink();
    
    final width = MediaQuery.of(context).size.width;
    final carouselHeight = width > 1200 ? 320.0 : (width > 600 ? 280.0 : 220.0);
    
    return Container(
      height: carouselHeight,
      margin: const EdgeInsets.only(top: 16),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: PageView.builder(
          itemCount: tracks.length > 5 ? 5 : tracks.length,
          controller: PageController(viewportFraction: width > 900 ? 0.8 : 0.9),
          itemBuilder: (context, i) {
            final track = tracks[i];
            return GestureDetector(
              onTap: () => context.read<AudioPlayerController>().playTrack(track, playlist: tracks),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    TrackArtwork(url: track.artworkUrl, size: 400, radius: 0, heroTag: 'feat_${track.id}'),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 24,
                      bottom: 24,
                      right: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ХИТ НЕДЕЛИ',
                              style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            track.title,
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            track.artist,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NewReleasesGrid extends StatelessWidget {
  const _NewReleasesGrid({required this.tracks});
  final List<Track> tracks;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    // Адаптивное кол-во колонок
    int crossAxisCount = 2;
    double ratio = 0.68; // Было 0.75
    
    if (width > 1200) {
      crossAxisCount = 6;
      ratio = 0.75; // Было 0.82
    } else if (width > 900) {
      crossAxisCount = 4;
      ratio = 0.72; // Было 0.78
    } else if (width > 600) {
      crossAxisCount = 3;
      ratio = 0.70; // Было 0.76
    }

    final items = tracks.length > (crossAxisCount * 2) 
      ? tracks.sublist(0, crossAxisCount * 2) 
      : tracks;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          childAspectRatio: ratio,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final t = items[i];
          return GestureDetector(
            onTap: () => context.read<AudioPlayerController>().playTrack(t, playlist: tracks),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: TrackArtwork(
                    url: t.artworkUrl, 
                    size: 200, 
                    radius: 20, 
                    heroTag: 'new_${t.id}',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  t.title,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  t.artist,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TrendingTrackCard extends StatelessWidget {
  const _TrendingTrackCard({required this.track, required this.onTap});
  final Track track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 140,
              width: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: TrackArtwork(url: track.artworkUrl, size: 140, radius: 24, heroTag: 'trend_${track.id}'),
            ),
            const SizedBox(height: 10),
            Text(
              track.title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              track.artist,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      onTap: onPlay,
      leading: TrackArtwork(url: track.artworkUrl, size: 48, radius: 8, heroTag: 'vert_${track.id}'),
      title: Text(
        track.title,
        style: TextStyle(
          color: isPlayingThis ? AppTheme.accent : AppTheme.textPrimary,
          fontWeight: isPlayingThis ? FontWeight.bold : FontWeight.w600,
        ),
      ),
      subtitle: Text(track.artist, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatDuration(track.durationSeconds),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
            onPressed: onMore,
          ),
        ],
      ),
    );
  }
}

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
  bool _active = false;

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
        setState(() { _searching = false; });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: 'Поиск музыки и людей',
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 22),
              suffixIcon: _active ? IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  _controller.clear();
                  setState(() { _active = false; });
                },
              ) : null,
              filled: true,
              fillColor: AppTheme.surfaceHighlight,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          if (_active)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0,10))],
              ),
              clipBehavior: Clip.antiAlias,
              child: _searching 
                ? const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: AppTheme.accent)))
                : ListView(
                    shrinkWrap: true,
                    children: [
                      if (_trackResults.isNotEmpty) ...[
                        const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 8), child: Text('ТРЕКИ', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 11))),
                        ..._trackResults.map((t) => ListTile(
                          leading: TrackArtwork(url: t.artworkUrl, size: 40, radius: 4),
                          title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Text(
                            _formatDuration(t.durationSeconds),
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          onTap: () {
                            context.read<AudioPlayerController>().playTrack(t, playlist: _trackResults);
                          },
                        )),
                      ],
                      if (_userResults.isNotEmpty) ...[
                        const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 8), child: Text('ЛЮДИ', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 11))),
                        ..._userResults.map((u) => ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundImage: u.avatarUrl != null ? NetworkImage(ApiConfig.resolveUrl(u.avatarUrl)!) : null,
                            child: u.avatarUrl == null ? const Icon(Icons.person, size: 16) : null,
                          ),
                          title: Text(u.displayName),
                          onTap: () => context.push('/profile/${u.id}'),
                        )),
                      ],
                      if (_trackResults.isEmpty && _userResults.isEmpty)
                        const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Ничего не найдено', style: TextStyle(color: AppTheme.textSecondary)))),
                    ],
                  ),
            ),
        ],
      ),
    );
  }
}
