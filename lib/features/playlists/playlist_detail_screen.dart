import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/config/api_config.dart';
import '../../data/models/playlist.dart';
import '../../data/models/track.dart';
import '../../providers/audio_player_controller.dart';
import '../../providers/playlist_controller.dart';
import '../widgets/track_artwork.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;
  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  Playlist? _playlist;
  List<Track> _tracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await context.read<PlaylistController>().getPlaylistDetails(widget.playlistId);
      if (mounted) {
        setState(() {
          _playlist = data['playlist'];
          _tracks = data['tracks'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    if (_playlist == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(child: Text('Плейлист не найден')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppTheme.background,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(_playlist!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.surfaceHighlight,
                      AppTheme.background,
                    ],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 10))],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _playlist!.artworkUrl != null 
                        ? Image.network(ApiConfig.resolveUrl(_playlist!.artworkUrl)!, fit: BoxFit.cover)
                        : const Icon(Icons.music_note, size: 80, color: AppTheme.textSecondary),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _showEditDialog(),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _confirmDelete(),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                   ElevatedButton.icon(
                    onPressed: _tracks.isNotEmpty 
                      ? () => context.read<AudioPlayerController>().playTrack(_tracks.first, playlist: _tracks)
                      : null,
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: const Text('Слушать', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                       minimumSize: const Size(140, 48),
                       backgroundColor: AppTheme.accent,
                       foregroundColor: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('${_tracks.length} треков', style: const TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ),
          if (_tracks.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('В этом плейлисте пока нет треков', style: TextStyle(color: AppTheme.textSecondary))),
            )
          else
            SliverList.builder(
              itemCount: _tracks.length,
              itemBuilder: (context, i) {
                final t = _tracks[i];
                return ListTile(
                  leading: TrackArtwork(url: t.artworkUrl, size: 48, radius: 4),
                  title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(t.artist, style: const TextStyle(color: AppTheme.textSecondary)),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: AppTheme.textSecondary, size: 20),
                    onPressed: () => _removeTrack(t),
                  ),
                  onTap: () => context.read<AudioPlayerController>().playTrack(t, playlist: _tracks),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Удалить плейлист?'),
        content: Text('Плейлист "${_playlist!.name}" будет удален навсегда.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ОТМЕНА', style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(
            onPressed: () async {
              await context.read<PlaylistController>().deletePlaylist(_playlist!.id);
              if (mounted) {
                Navigator.pop(context); // Закрываем диалог
                context.pop();         // Возвращаемся в библиотеку (GoRouter)
              }
            }, 
            child: const Text('УДАЛИТЬ', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog() {
    final nameController = TextEditingController(text: _playlist!.name);
    final descController = TextEditingController(text: _playlist!.description ?? '');
    PlatformFile? selectedFile;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Редактировать плейлист'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Предпросмотр обложки
                GestureDetector(
                  onTap: () async {
                    final result = await FilePicker.platform.pickFiles(type: FileType.image);
                    if (result != null) {
                      setDialogState(() => selectedFile = result.files.first);
                    }
                  },
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceHighlight,
                      borderRadius: BorderRadius.circular(8),
                      image: selectedFile != null 
                        ? DecorationImage(
                            image: MemoryImage(selectedFile!.bytes!), 
                            fit: BoxFit.cover,
                          )
                        : (_playlist!.artworkUrl != null 
                            ? DecorationImage(
                                image: NetworkImage(ApiConfig.resolveUrl(_playlist!.artworkUrl)!), 
                                fit: BoxFit.cover,
                              )
                            : null),
                    ),
                    child: (selectedFile == null && _playlist!.artworkUrl == null)
                        ? const Icon(Icons.add_a_photo_outlined, size: 40)
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(type: FileType.image);
                    if (result != null) {
                      setDialogState(() => selectedFile = result.files.first);
                    }
                  },
                  child: const Text('Выбрать обложку', style: TextStyle(color: AppTheme.accent)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Название',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accent)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Описание',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accent)),
                  ),
                  maxLines: 2,
                ),
                if (isUploading) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(color: AppTheme.accent),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context),
              child: const Text('ОТМЕНА', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: isUploading ? null : () async {
                final newName = nameController.text.trim();
                if (newName.isEmpty) return;

                setDialogState(() => isUploading = true);

                String? artworkUrl;
                if (selectedFile != null) {
                  artworkUrl = await context.read<PlaylistController>().uploadArtwork(
                    selectedFile!.bytes!, 
                    selectedFile!.name,
                  );
                }

                final updated = await context.read<PlaylistController>().updatePlaylist(
                  _playlist!.id,
                  name: newName,
                  description: descController.text.trim(),
                  artworkUrl: artworkUrl,
                );

                if (mounted && updated != null) {
                  setState(() => _playlist = updated);
                  Navigator.pop(context);
                } else {
                   setDialogState(() => isUploading = false);
                }
              },
              child: const Text('СОХРАНИТЬ', style: TextStyle(color: AppTheme.accent)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeTrack(Track track) async {
    await context.read<PlaylistController>().removeTrackFromPlaylist(_playlist!.id, track.id);
    setState(() {
      _tracks.removeWhere((t) => t.id == track.id);
    });
  }
}
