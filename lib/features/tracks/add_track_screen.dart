import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/library_controller.dart';

class AddTrackScreen extends StatefulWidget {
  const AddTrackScreen({super.key});

  @override
  State<AddTrackScreen> createState() => _AddTrackScreenState();
}

class _AddTrackScreenState extends State<AddTrackScreen> {
  final _title = TextEditingController();
  final _artist = TextEditingController();
  final _url = TextEditingController();
  final _art = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  PlatformFile? _selectedFile;
  bool _loading = false;

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _url.dispose();
    _art.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      setState(() {
        _selectedFile = file;
        
        if (_title.text.isEmpty) {
           String name = file.name;
           int dot = name.lastIndexOf('.');
           _title.text = dot != -1 ? name.substring(0, dot) : name;
        }
        _url.clear(); // Clear URL
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedFile == null && _url.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите файл или укажите URL потока')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      File? fileObj;
      if (!kIsWeb && _selectedFile?.path != null) {
        // Not web
        fileObj = File(_selectedFile!.path!);
      }
      
      await context.read<LibraryController>().addTrack(
            title: _title.text.trim(),
            artist: _artist.text.trim(),
            streamUrl: _url.text.isEmpty ? null : _url.text.trim(),
            audioFile: fileObj,
            audioBytes: _selectedFile?.bytes,
            audioFileName: _selectedFile?.name,
            artworkUrl: _art.text.isEmpty ? null : _art.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Трек успешно загружен')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при загрузке: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // В зависимости от того, выбран ли файл, мы дизейблим ввод URL
    final hasFile = _selectedFile != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Загрузить трек'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Добавьте свой собственный MP3/WAV трек или укажите прямую ссылку на стрим.',
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 24),

                // File Upload Section
                InkWell(
                  onTap: _pickFile,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: hasFile ? AppTheme.accent.withValues(alpha: 0.1) : AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasFile ? AppTheme.accent : AppTheme.surfaceHighlight,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                         Icon(
                           hasFile ? Icons.audio_file_rounded : Icons.cloud_upload_outlined,
                           color: hasFile ? AppTheme.accent : AppTheme.textSecondary,
                           size: 48,
                         ),
                         const SizedBox(height: 12),
                         Text(
                           hasFile ? _selectedFile!.name : 'Выбрать аудиофайл с устройства',
                           textAlign: TextAlign.center,
                           style: TextStyle(
                              color: hasFile ? AppTheme.accent : AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                           ),
                         ),
                         if (hasFile) ...[
                           const SizedBox(height: 8),
                           TextButton.icon(
                             onPressed: () => setState(() => _selectedFile = null),
                             icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                             label: const Text('Убрать', style: TextStyle(color: Colors.redAccent)),
                             style: TextButton.styleFrom(
                               minimumSize: Size.zero, 
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                             ),
                           ),
                         ]
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Center(
                  child: Text('ИЛИ', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _url,
                  enabled: !hasFile,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Вставить прямой URL потока',
                    prefixIcon: const Icon(Icons.link_rounded),
                    filled: !hasFile,
                    fillColor: hasFile ? Colors.transparent : AppTheme.surface,
                  ),
                ),

                const SizedBox(height: 32),
                const Divider(height: 1, color: AppTheme.surfaceHighlight),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Название',
                    prefixIcon: Icon(Icons.music_note_rounded),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Обязательное поле' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _artist,
                  decoration: const InputDecoration(
                    labelText: 'Исполнитель',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Обязательное поле' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _art,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'URL обложки (необязательно)',
                    prefixIcon: Icon(Icons.image_outlined),
                  ),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: _loading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onAccent),
                        )
                      : const Text('ДОБАВИТЬ ТРЕК', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
