import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/track.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/user_repository.dart';
import '../../providers/audio_player_controller.dart';
import '../widgets/track_artwork.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.userId});
  final String userId;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isLoading = true;
  String? _error;
  UserProfile? _profile;
  List<Track> _likedTracks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final repo = UserRepository(prefs);
      // Загружаем профиль и лайкнутые треки параллельно
      final results = await Future.wait([
        repo.getUserProfileAndTracks(widget.userId),
        repo.getUserLikedTracks(widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = (results[0] as Map<String, dynamic>)['user'] as UserProfile;
        _likedTracks = results[1] as List<Track>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 24),
              OutlinedButton(onPressed: _load, child: const Text('Повторить')),
            ],
          ),
        ),
      );
    }
    if (_profile == null) return const SizedBox.shrink();

    return CustomScrollView(
      slivers: [
        // AppBar с кнопкой назад
        SliverAppBar(
          pinned: true,
          backgroundColor: AppTheme.background.withValues(alpha: 0.95),
          elevation: 0,
          leading: const BackButton(),
          title: Text(_profile!.displayName,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),

        // Шапка профиля
        SliverToBoxAdapter(child: _buildHeader()),

        // Заголовок секции
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              children: [
                const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Избранное · ${_likedTracks.length}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Список лайкнутых
        if (_likedTracks.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'Пользователь пока ничего не добавил в избранное',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: _likedTracks.length,
            itemBuilder: (context, i) {
              final track = _likedTracks[i];
              return _LikedTrackTile(
                track: track,
                onPlay: () => context.read<AudioPlayerController>().playTrack(track),
              );
            },
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          // Аватар
          CircleAvatar(
            radius: 48,
            backgroundColor: AppTheme.surfaceHighlight,
            backgroundImage:
                _profile!.avatarUrl != null && _profile!.avatarUrl!.isNotEmpty
                    ? NetworkImage(_profile!.avatarUrl!)
                    : null,
            child: _profile!.avatarUrl == null || _profile!.avatarUrl!.isEmpty
                ? Text(
                    _profile!.displayName.isNotEmpty
                        ? _profile!.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontSize: 36, fontWeight: FontWeight.w700),
                  )
                : null,
          ),
          const SizedBox(width: 20),
          // Имя и статистика
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _profile!.displayName,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_likedTracks.length} в избранном',
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LikedTrackTile extends StatelessWidget {
  const _LikedTrackTile({required this.track, required this.onPlay});

  final Track track;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final isPlaying = context.select<AudioPlayerController, bool>(
      (a) => a.currentTrack?.id == track.id,
    );

    return InkWell(
      onTap: onPlay,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            // Обложка
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                children: [
                  TrackArtwork(url: track.artworkUrl, size: 48, radius: 6),
                  if (isPlaying)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Icon(Icons.equalizer,
                            color: AppTheme.accent, size: 22),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Название и исполнитель
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                      color: isPlaying ? AppTheme.accent : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            // Иконка сердечка (статична — чужой профиль)
            const Icon(Icons.favorite_rounded,
                color: Colors.redAccent, size: 18),
          ],
        ),
      ),
    );
  }
}
