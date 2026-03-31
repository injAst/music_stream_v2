import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/library_controller.dart';

class PendingTrack {
  final PlatformFile file;
  String title;
  String artist;
  String artworkUrl;
  int? duration;
  String? status; // 'pending', 'extracting', 'uploading', 'done', 'error'
  String? error;

  PendingTrack({
    required this.file,
    required this.title,
    this.artist = '',
    this.artworkUrl = '',
    this.status = 'pending',
  });
}

class AddTrackScreen extends StatefulWidget {
  const AddTrackScreen({super.key});

  @override
  State<AddTrackScreen> createState() => _AddTrackScreenState();
}

class _AddTrackScreenState extends State<AddTrackScreen> {
  final List<PendingTrack> _pendingTracks = [];
  final _globalArtist = TextEditingController();
  final _globalArtworkUrl = TextEditingController();
  final _streamUrl = TextEditingController(); // For single URL fallback
  final _formKey = GlobalKey<FormState>();
  
  bool _isProcessing = false;
  int _currentProcessingIndex = -1;

  @override
  void dispose() {
    _globalArtist.dispose();
    _globalArtworkUrl.dispose();
    _streamUrl.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        for (final file in result.files) {
          String name = file.name;
          int dot = name.lastIndexOf('.');
          String title = dot != -1 ? name.substring(0, dot) : name;
          
          _pendingTracks.add(PendingTrack(
            file: file,
            title: title,
            artist: _globalArtist.text,
            artworkUrl: _globalArtworkUrl.text,
          ));
        }
      });
      _extractAllDurations();
    }
  }

  Future<void> _extractAllDurations() async {
    for (int i = 0; i < _pendingTracks.length; i++) {
      if (_pendingTracks[i].duration != null) continue;
      
      setState(() => _pendingTracks[i].status = 'extracting');
      
      final player = AudioPlayer();
      try {
        final file = _pendingTracks[i].file;
        Duration? duration;
        
        if (kIsWeb) {
          if (file.bytes != null) {
            final uri = Uri.dataFromBytes(file.bytes!, mimeType: 'audio/mpeg');
            duration = await player.setAudioSource(AudioSource.uri(uri));
          }
        } else if (file.path != null) {
          duration = await player.setFilePath(file.path!);
        }

        if (duration == null) {
          duration = await player.durationStream
              .firstWhere((d) => d != null && d.inSeconds > 0)
              .timeout(const Duration(seconds: 3), onTimeout: () => null);
        }

        if (mounted) {
          setState(() {
            _pendingTracks[i].duration = duration?.inSeconds ?? 0;
            _pendingTracks[i].status = 'pending';
          });
        }
      } catch (e) {
        debugPrint('Error extracting duration: $e');
      } finally {
        await player.dispose();
      }
    }
  }

  Future<void> _startUpload() async {
    if (_pendingTracks.isEmpty && _streamUrl.text.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
       // Batch upload pending tracks
       for (int i = 0; i < _pendingTracks.length; i++) {
         if (_pendingTracks[i].status == 'done') continue;

         setState(() {
           _currentProcessingIndex = i;
           _pendingTracks[i].status = 'uploading';
         });

         final track = _pendingTracks[i];
         File? fileObj;
         if (!kIsWeb && track.file.path != null) {
           fileObj = File(track.file.path!);
         }

         try {
           await context.read<LibraryController>().addTrack(
             title: track.title.trim(),
             artist: (track.artist.isEmpty ? _globalArtist.text : track.artist).trim(),
             artworkUrl: (track.artworkUrl.isEmpty ? _globalArtworkUrl.text : track.artworkUrl).trim(),
             audioFile: fileObj,
             audioBytes: track.file.bytes,
             audioFileName: track.file.name,
             durationSeconds: track.duration,
           );
           if (mounted) {
             setState(() => _pendingTracks[i].status = 'done');
           }
         } catch (e) {
           if (mounted) {
             setState(() {
               _pendingTracks[i].status = 'error';
               _pendingTracks[i].error = e.toString();
             });
           }
           // Stop on first error to let user fix? Or continue?
           // Let's continue but mark error.
         }
       }

       // Single URL fallback if provided and no tracks selected
       if (_pendingTracks.isEmpty && _streamUrl.text.isNotEmpty) {
         await context.read<LibraryController>().addTrack(
           title: 'Stream',
           artist: _globalArtist.text.trim(),
           artworkUrl: _globalArtworkUrl.text.trim(),
           streamUrl: _streamUrl.text.trim(),
         );
       }

       if (mounted && _pendingTracks.every((t) => t.status == 'done')) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Все треки успешно загружены!')),
         );
         context.pop();
       }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _currentProcessingIndex = -1;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pendingTracks.isEmpty ? 'Загрузить треки' : 'Загрузка (${_pendingTracks.length})'),
        actions: [
          if (_pendingTracks.isNotEmpty && !_isProcessing)
            TextButton(
              onPressed: () => setState(() => _pendingTracks.clear()),
              child: const Text('ОЧИСТИТЬ', style: TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildGlobalInputs(),
                      const SizedBox(height: 24),
                      if (_pendingTracks.isEmpty) _buildFileUploadTrigger() else _buildTrackList(),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Загрузка паком',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        SizedBox(height: 8),
        Text(
          'Выберите несколько файлов сразу, и мы загрузим их один за другим.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildGlobalInputs() {
    return Column(
      children: [
        TextFormField(
          controller: _globalArtist,
          decoration: const InputDecoration(
            labelText: 'Исполнитель (для всех)',
            prefixIcon: Icon(Icons.person_rounded),
            hintText: 'Будет применено к трекам без автора',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _globalArtworkUrl,
          decoration: const InputDecoration(
            labelText: 'URL обложки (для всех)',
            prefixIcon: Icon(Icons.image_outlined),
            hintText: 'Будет применено ко всем трекам сразу',
          ),
        ),
        if (_pendingTracks.isEmpty) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _streamUrl,
            decoration: const InputDecoration(
              labelText: 'Или вставьте прямой URL потока',
              prefixIcon: Icon(Icons.link_rounded),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFileUploadTrigger() {
    return InkWell(
      onTap: _pickFiles,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.surfaceHighlight, width: 2, style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload_outlined, color: AppTheme.accent, size: 48),
            SizedBox(height: 12),
            Text(
              'Нажмите, чтобы выбрать файлы',
              style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Выбранные файлы', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton.icon(
              onPressed: _isProcessing ? null : _pickFiles,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Добавить еще'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _pendingTracks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final track = _pendingTracks[index];
            return _buildTrackItem(track, index);
          },
        ),
      ],
    );
  }

  Widget _buildTrackItem(PendingTrack track, int index) {
    bool isProcessingThis = _currentProcessingIndex == index;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isProcessingThis ? AppTheme.accent : AppTheme.surfaceHighlight,
          width: isProcessingThis ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatusIcon(track),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Название трека
                    TextFormField(
                      initialValue: track.title,
                      enabled: !_isProcessing,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Название',
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                        border: InputBorder.none,
                      ),
                      onChanged: (v) => track.title = v,
                    ),
                    // Исполнитель трека
                    TextFormField(
                      initialValue: track.artist,
                      enabled: !_isProcessing,
                      style: const TextStyle(fontSize: 12, color: AppTheme.accent),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Исполнитель (если отличается)',
                        contentPadding: EdgeInsets.symmetric(vertical: 2),
                        border: InputBorder.none,
                      ),
                      onChanged: (v) => track.artist = v,
                    ),
                    // Обложка трека
                    TextFormField(
                      initialValue: track.artworkUrl,
                      enabled: !_isProcessing,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'URL обложки (если отличается)',
                        contentPadding: EdgeInsets.symmetric(vertical: 2),
                        border: InputBorder.none,
                      ),
                      onChanged: (v) => track.artworkUrl = v,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(track.file.size / 1024 / 1024).toStringAsFixed(2)} MB • ${_formatSec(track.duration ?? 0)}',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              if (!_isProcessing)
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                  onPressed: () => setState(() => _pendingTracks.removeAt(index)),
                ),
            ],
          ),
          if (track.status == 'error' && track.error != null)
             Padding(
               padding: const EdgeInsets.only(top: 8),
               child: Text(track.error!, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
             ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(PendingTrack track) {
    switch (track.status) {
      case 'extracting':
      case 'uploading':
        return const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppTheme.accent)),
        );
      case 'done':
        return const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 22);
      case 'error':
        return const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 22);
      default:
        return const Icon(Icons.audio_file_rounded, color: AppTheme.textSecondary, size: 22);
    }
  }

  Widget _buildBottomAction() {
    if (_pendingTracks.isEmpty && _streamUrl.text.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _startUpload,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          minimumSize: const Size(double.infinity, 54),
        ),
        child: _isProcessing 
          ? Text('ЗАГРУЗКА... (${_currentProcessingIndex + 1}/${_pendingTracks.length})')
          : Text(_pendingTracks.isEmpty ? 'ДОБАВИТЬ СТРИМ' : 'ЗАГРУЗИТЬ ВСЁ (${_pendingTracks.length})'),
      ),
    );
  }

  String _formatSec(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
