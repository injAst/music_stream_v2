import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/config/api_config.dart';
import '../../data/models/playlist.dart';
import '../../data/models/track.dart';
import '../../providers/audio_player_controller.dart';
import '../../providers/auth_controller.dart';
import '../../providers/library_controller.dart';
import '../../providers/playlist_controller.dart';
import '../widgets/track_artwork.dart';

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  String _searchQuery = '';
  int _activeTabIndex = 0; // 0: Favorites, 1: My Tracks, 2: Playlists

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaylistController>().fetchPlaylists();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Consumer2<LibraryController, PlaylistController>(
        builder: (context, lib, plc, _) {
          if (lib.isLoading && plc.isLoading && lib.tracks.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
          }

          final likedTracks = lib.tracks.where((t) => t.isLiked).toList();
          final myTracks = lib.tracks.where((t) => t.canDelete).toList();
          final playlists = plc.playlists;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Шапка с переключателем
              SliverToBoxAdapter(
                child: _buildHeader(context, likedTracks, myTracks, playlists),
              ),

              // Строка поиска (только для треков)
              if (_activeTabIndex != 2)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickySearchBarDelegate(
                    onSearch: (v) => setState(() => _searchQuery = v),
                    hintText: _activeTabIndex == 0 ? 'Поиск в любимых' : 'Поиск в моих треках',
                  ),
                ),

              // Основной контент
              if (_activeTabIndex == 2)
                _buildPlaylistGrid(context, playlists)
              else if (_activeTabIndex == 1)
                _buildTrackList(context, myTracks, isMyTracks: true)
              else
                _buildTrackList(context, likedTracks, isMyTracks: false),
                
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTrackList(BuildContext context, List<Track> allTracks, {required bool isMyTracks}) {
    var tracks = allTracks;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      tracks = tracks.where((t) => 
         t.title.toLowerCase().contains(q) || 
         t.artist.toLowerCase().contains(q)).toList();
    }

    if (tracks.isEmpty && _searchQuery.isEmpty) {
       return SliverFillRemaining(hasScrollBody: false, child: _buildEmptyTracksState());
    }

    return SliverPadding(
      padding: const EdgeInsets.only(top: 8),
      sliver: SliverList.builder(
        itemCount: tracks.length,
        itemBuilder: (context, i) {
          final t = tracks[i];
          return _TrackTile(
            track: t,
            onPlay: () => context.read<AudioPlayerController>().playTrack(t, playlist: tracks),
            onLongPress: () => _showTrackOptions(context, t, allowEdit: isMyTracks),
          );
        },
      ),
    );
  }

  Widget _buildPlaylistGrid(BuildContext context, List<Playlist> playlists) {
    if (playlists.isEmpty) {
      return SliverFillRemaining(hasScrollBody: false, child: _buildEmptyPlaylistsState());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 110,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.65,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final p = playlists[i];
            return GestureDetector(
              onTap: () => context.push('/playlist/${p.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Квадратная обложка
                  AspectRatio(
                    aspectRatio: 1,
                    child: Hero(
                      tag: p.id,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceHighlight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          image: p.artworkUrl != null 
                            ? DecorationImage(
                                image: NetworkImage(ApiConfig.resolveUrl(p.artworkUrl)!), 
                                fit: BoxFit.cover,
                              )
                            : null,
                        ),
                        child: p.artworkUrl == null 
                          ? const Center(child: Icon(Icons.music_note, size: 28, color: AppTheme.textSecondary))
                          : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.name, 
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600, 
                      fontSize: 13,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${p.trackCount} треков', 
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            );
          },
          childCount: playlists.length,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<Track> likedTracks, List<Track> myTracks, List<Playlist> playlists) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 70, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Библиотека',
                style: GoogleFonts.outfit(
                  fontSize: 32, 
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const Spacer(),
              // Временная кнопка удаления всего
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Удалить всё?'),
                      content: const Text('Все треки в вашей библиотеке будут безвозвратно удалены.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('ОТМЕНА'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            context.read<LibraryController>().deleteAllTracks();
                          },
                          child: const Text('УДАЛИТЬ ЛИБРИТ!', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                },
                child: Container(
                  width: 38,
                  height: 38,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.surfaceHighlight,
                  ),
                  child: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
                ),
              ),
              // Кнопка добавления (Apple Music Style)
              GestureDetector(
                onTap: () => _showAddMenu(context),
                child: Container(
                  width: 38,
                  height: 38,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.surfaceHighlight,
                  ),
                  child: const Icon(Icons.add, color: AppTheme.textPrimary, size: 22),
                ),
              ),
              // Аватарка профиля
              GestureDetector(
                onTap: () {
                  final user = context.read<AuthController>().user;
                  if (user != null) {
                    context.push('/profile/${user.id}');
                  }
                },
                child: Hero(
                  tag: 'profile_avatar',
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surfaceHighlight,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: context.read<AuthController>().user?.avatarUrl != null 
                      ? Image.network(
                          ApiConfig.resolveUrl(context.read<AuthController>().user?.avatarUrl)!,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.person_rounded, color: AppTheme.textSecondary, size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _PremiumTabSwitcher(
            activeTab: _activeTabIndex,
            onTabChanged: (i) => setState(() => _activeTabIndex = i),
            labels: const ['Любимые', 'Мои', 'Плейлисты'], 
          ),
        ],
      ),
    );
  }

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Библиотека',
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.music_note_rounded, color: Colors.blueAccent),
                ),
                title: const Text('Загрузить трек', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Добавить свою музыку в облако'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/add-track');
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.playlist_add_rounded, color: AppTheme.accent),
                ),
                title: const Text('Создать плейлист', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Собрать свою коллекцию'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreatePlaylistDialog(context);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTracksState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_border_rounded, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          const Text('Нет любимых треков', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Нажмите на сердечко у любого трека', style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildEmptyPlaylistsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.playlist_add_rounded, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          const Text('У вас пока нет плейлистов', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showCreatePlaylistDialog(context),
            child: const Text('Создать первый'),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Новый плейлист'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Название',
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accent)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ОТМЕНА', style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                context.read<PlaylistController>().createPlaylist(name);
                Navigator.pop(context);
              }
            }, 
            child: const Text('СОЗДАТЬ', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }

  void _showTrackOptions(BuildContext context, Track track, {required bool allowEdit}) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _TrackOptionsSheet(track: track, allowEdit: allowEdit),
    );
  }
}

class _PremiumTabSwitcher extends StatelessWidget {
  const _PremiumTabSwitcher({
    required this.activeTab,
    required this.onTabChanged,
    required this.labels,
  });

  final int activeTab;
  final ValueChanged<int> onTabChanged;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHighlight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Движущийся индикатор
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: activeTab == 0 
                ? Alignment.centerLeft 
                : activeTab == 1 
                    ? Alignment.center 
                    : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 1 / labels.length,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Сами кнопки
          Row(
            children: List.generate(labels.length, (i) {
              final isActive = activeTab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTabChanged(i),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        color: isActive ? Colors.black : AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      child: Text(labels[i]),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _TrackOptionsSheet extends StatelessWidget {
  const _TrackOptionsSheet({required this.track, required this.allowEdit});
  final Track track;
  final bool allowEdit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
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
            if (track.canDelete && allowEdit)
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppTheme.accent),
                title: const Text('Редактировать'),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) => _EditTrackDialog(track: track),
                  );
                },
              ),
            if (track.isLiked)
              ListTile(
                leading: const Icon(Icons.favorite, color: Colors.redAccent),
                title: const Text('Удалить из любимых'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<LibraryController>().toggleLike(track.id);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.favorite_border),
                title: const Text('В любимые треки'),
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
                _showAddToPlaylistPicker(context, track);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAddToPlaylistPicker(BuildContext context, Track track) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scroll) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Выберите плейлист', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Consumer<PlaylistController>(
                  builder: (context, plc, _) {
                    if (plc.playlists.isEmpty) {
                      return const Center(child: Text('У вас пока нет плейлистов'));
                    }
                    return ListView.builder(
                      controller: scroll,
                      itemCount: plc.playlists.length,
                      itemBuilder: (context, i) {
                        final p = plc.playlists[i];
                        return ListTile(
                          leading: Container(
                            width: 40, height: 40, 
                            decoration: BoxDecoration(color: AppTheme.surfaceHighlight, borderRadius: BorderRadius.circular(4)),
                            child: const Icon(Icons.music_note, size: 20),
                          ),
                          title: Text(p.name),
                          subtitle: Text('${p.trackCount} треков'),
                          onTap: () {
                            plc.addTrackToPlaylist(p.id, track.id);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Добавлено в "${p.name}"'), backgroundColor: AppTheme.accent),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ... _TrackTile, _StickySearchBarDelegate remain similar to before but updated for new context
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isPlayingThis ? AppTheme.accent.withValues(alpha: 0.05) : Colors.transparent,
        ),
        child: Row(
          children: [
            TrackArtwork(
              url: track.artworkUrl, 
              size: 52, 
              radius: 4, 
              heroTag: track.id,
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
            Consumer<LibraryController>(
              builder: (context, lib, _) {
                final isLiked = track.isLiked;
                return IconButton(
                  onPressed: () => lib.toggleLike(track.id),
                  icon: Icon(
                    isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                    color: isLiked ? Colors.redAccent : AppTheme.textSecondary,
                    size: 22,
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 20),
              onPressed: onLongPress,
            )
          ],
        ),
      ),
    );
  }
}

class _StickySearchBarDelegate extends SliverPersistentHeaderDelegate {
  const _StickySearchBarDelegate({required this.onSearch, required this.hintText});
  final ValueChanged<String> onSearch;
  final String hintText;

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
          hintText: hintText,
          prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
          filled: true,
          fillColor: AppTheme.surfaceHighlight,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickySearchBarDelegate oldDelegate) => false;
}

class _EditTrackDialog extends StatefulWidget {
  const _EditTrackDialog({required this.track});
  final Track track;

  @override
  State<_EditTrackDialog> createState() => _EditTrackDialogState();
}

class _EditTrackDialogState extends State<_EditTrackDialog> {
  late TextEditingController _title;
  late TextEditingController _artist;
  late TextEditingController _artwork;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.track.title);
    _artist = TextEditingController(text: widget.track.artist);
    _artwork = TextEditingController(text: widget.track.artworkUrl ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _artwork.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Редактировать трек'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Название',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accent)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _artist,
              decoration: const InputDecoration(
                labelText: 'Исполнитель',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accent)),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _artwork,
                    decoration: const InputDecoration(
                      labelText: 'URL обложки',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      contentPadding: EdgeInsets.zero,
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accent)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _loading ? null : _uploadArtwork,
                  tooltip: 'Загрузить обложку',
                  icon: const Icon(Icons.file_upload, color: AppTheme.accent),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : _delete,
          child: const Text('УДАЛИТЬ', style: TextStyle(color: Colors.redAccent)),
        ),
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('ОТМЕНА', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        TextButton(
          onPressed: _loading ? null : _save,
          child: _loading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
            : const Text('СОХРАНИТЬ', style: TextStyle(color: AppTheme.accent)),
        ),
      ],
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Удалить трек?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ОТМЕНА', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('УДАЛИТЬ', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      setState(() => _loading = true);
      try {
        await context.read<LibraryController>().removeTrack(widget.track.id);
        if (mounted) Navigator.pop(context); // Close edit dialog
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка при удалении: $e')),
          );
        }
      }
    }
  }

  Future<void> _uploadArtwork() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null) return;
      
      setState(() => _loading = true);
      
      final file = result.files.first;
      final url = await context.read<LibraryController>().uploadArtwork(
        file: kIsWeb ? null : File(file.path!),
        bytes: kIsWeb ? file.bytes : null,
        filename: file.name,
      );
      
      setState(() {
        _artwork.text = url;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await context.read<LibraryController>().updateTrackMetadata(
        id: widget.track.id,
        title: _title.text.trim(),
        artist: _artist.text.trim(),
        artworkUrl: _artwork.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        // Извлекаем более понятное сообщение об ошибке
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $msg')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
