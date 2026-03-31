import 'dart:async';
import 'dart:math' as math;
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

          // Логика "Новых релизов": 7 дней или 6 последних (fallback)
          final weekAgo = DateTime.now().subtract(const Duration(days: 7));
          var newReleases = tracks.where((t) => t.createdAt != null && t.createdAt!.isAfter(weekAgo)).toList();

          // Если за неделю ничего не вышло — показываем 6 последних добавленных
          if (newReleases.isEmpty) {
            newReleases = tracks.take(6).toList();
          }

          // Логика "В тренде": Хайп-рейтинг (лайки + свежесть) + лимит 100 во вкладке "Все"
          final trendingTracks = List<Track>.from(tracks)..sort((a, b) {
            double getScore(Track t) {
              final age = t.createdAt != null 
                ? DateTime.now().difference(t.createdAt!).inDays 
                : 30; // 30 дней по умолчанию, если даты нет
              // Формула: Лайки делим на возраст (сглаженный), чтобы новые треки быстрее выходили в топ
              return (t.likesCount + 1) / (age + 2);
            }
            return getScore(b).compareTo(getScore(a));
          });
          
          final trendingAll = trendingTracks.take(100).toList();
          final trendingHome = trendingTracks.take(8).toList();

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

              // 1. Поток (вместо карусели)
              SliverToBoxAdapter(
                child: _FlowHero(tracks: tracks),
              ),

              if (tracks.isNotEmpty) ...[
                _buildSectionHeader(context, 'Новые релизы', () {
                   _showAllTracks(context, 'Новые релизы', newReleases);
                }),
                SliverToBoxAdapter(
                  child: _NewReleasesGrid(tracks: newReleases),
                ),

                _buildSectionHeader(context, 'В тренде', () {
                   _showAllTracks(context, 'В тренде', trendingAll);
                }),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: trendingHome.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (context, i) {
                        return _TrendingTrackCard(
                          track: trendingHome[i],
                          onTap: () => context.read<AudioPlayerController>().playTrack(trendingHome[i], playlist: trendingHome),
                        );
                      },
                    ),
                  ),
                ),

                _buildSectionHeader(context, 'Рекомендации', () {
                   _showAllTracks(context, 'Рекомендации', tracks.reversed.toList());
                }),
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

  void _showAllTracks(BuildContext context, String title, List<Track> tracks) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 140),
                itemCount: tracks.length,
                itemBuilder: (context, i) {
                  final t = tracks[i];
                  return _VerticalTrackTile(
                    track: t,
                    onPlay: () {
                      Navigator.pop(context);
                      context.read<AudioPlayerController>().playTrack(t, playlist: tracks);
                    },
                    onMore: () => _showTrackOptions(context, t),
                  );
                },
              ),
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

enum _FlowPatternType { nebula, aurora, waves, vortex, stardust }

class _FlowHero extends StatefulWidget {
  const _FlowHero({required this.tracks});
  final List<Track> tracks;

  @override
  State<_FlowHero> createState() => _FlowHeroState();
}

class _FlowHeroState extends State<_FlowHero> with TickerProviderStateMixin {
  late AnimationController _mainAnimController;
  late AnimationController _themeTransitionController;
  late AnimationController _patternTransitionController;
  
  int _currentThemeIndex = 0;
  _FlowPatternType _currentPattern = _FlowPatternType.nebula;
  _FlowPatternType _prevPattern = _FlowPatternType.nebula;
  
  Timer? _cycleTimer;

  static const List<List<Color>> _palettes = [
    [Color(0xFF1E3A8A), Color(0xFF4C1D95), Color(0xFFFACC15), Color(0xFF0D9488)], // Cosmos
    [Color(0xFFFF4E50), Color(0xFFE94E77), Color(0xFFF9D423), Color(0xFFFF8C00)], // Sunset
    [Color(0xFF0891B2), Color(0xFF1E40AF), Color(0xFF0284C7), Color(0xFF06B6D4)], // Ocean
    [Color(0xFF4338CA), Color(0xFF7C3AED), Color(0xFFDB2777), Color(0xFF2563EB)], // Neon Night
  ];

  @override
  void initState() {
    super.initState();
    _mainAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25), // Медленное, медитативное движение
    )..repeat();

    _themeTransitionController = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 8), // Очень плавный переход цвета (8 сек)
    )..value = 1.0;

    _patternTransitionController = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 6), // Длительный кросс-фейд паттернов
    )..value = 1.0;

    _startCycling();
  }

  void _startCycling() {
    _cycleTimer = Timer.periodic(const Duration(seconds: 45), (timer) {
      if (mounted) {
        setState(() {
            _currentThemeIndex = (_currentThemeIndex + 1) % _palettes.length;
            
            // Смена паттерна каждый цикл темы (10 сек) для теста
            _prevPattern = _currentPattern;
            _currentPattern = _FlowPatternType.values[(_currentPattern.index + 1) % _FlowPatternType.values.length];
            _patternTransitionController.forward(from: 0.0);
        });
        _themeTransitionController.forward(from: 0.0);
      }
    });
  }

  @override
  void dispose() {
    _mainAnimController.dispose();
    _themeTransitionController.dispose();
    _patternTransitionController.dispose();
    _cycleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tracks.isEmpty) return const SizedBox.shrink();
    
    final isPlaying = context.select<AudioPlayerController, bool>((audio) => audio.isPlaying);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: const Color(0xFF020202),
          boxShadow: [
             BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Фоновые слои туманности/волн с кросс-фейдом паттернов
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_mainAnimController, _themeTransitionController, _patternTransitionController]),
                builder: (context, child) {
                  final lerpTheme = _themeTransitionController.value;
                  final prevThemeIndex = (_currentThemeIndex - 1 + _palettes.length) % _palettes.length;
                  final currentColors = List.generate(4, (i) => 
                     Color.lerp(_palettes[prevThemeIndex][i], _palettes[_currentThemeIndex][i], lerpTheme)!
                  );

                  return Stack(
                    children: [
                      // Старый паттерн (уходящий)
                      if (_patternTransitionController.value < 1.0)
                        Opacity(
                          opacity: 1.0 - _patternTransitionController.value,
                          child: _buildPatternPainter(_prevPattern, currentColors, isPlaying),
                        ),
                      // Новый паттерн (приходящий)
                      Opacity(
                        opacity: _patternTransitionController.value,
                        child: _buildPatternPainter(_currentPattern, currentColors, isPlaying),
                      ),
                    ],
                  );
                },
              ),
            ),
            
            // Слой стекла
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.1),
                          Colors.white.withValues(alpha: 0.02),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: CustomPaint(painter: _GrainPainter(opacity: 0.03)),
                  ),
                ),
              ),
            ),
            
            // Убрали граненый блик (белую обводку) по просьбе пользователя

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                             const Icon(Icons.auto_awesome, color: AppTheme.accent, size: 14),
                             const SizedBox(width: 8),
                             Expanded(child: Text('ETERNAL FLOW ENGINE 3.1', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white.withValues(alpha: 0.7), letterSpacing: 2.5,), maxLines: 1, overflow: TextOverflow.ellipsis,),),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Поток',
                          style: GoogleFonts.outfit(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1.5,
                            height: 0.9,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Микс бесконечных миров',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _NebulaPlayButton(
                    isPlaying: isPlaying,
                    onTap: () => context.read<AudioPlayerController>().playWave(widget.tracks),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternPainter(_FlowPatternType pattern, List<Color> colors, bool isPlaying) {
    switch (pattern) {
      case _FlowPatternType.nebula:
        return CustomPaint(
          painter: _NebulaBackgroundPainter(
            animationValue: _mainAnimController.value,
            isPlaying: isPlaying,
            colors: colors,
          ),
          size: Size.infinite,
        );
      case _FlowPatternType.aurora:
        return CustomPaint(
          painter: _AuroraBackgroundPainter(
            animationValue: _mainAnimController.value,
            isPlaying: isPlaying,
            colors: colors,
          ),
          size: Size.infinite,
        );
      case _FlowPatternType.waves:
        return CustomPaint(
          painter: _WavesBackgroundPainter(
            animationValue: _mainAnimController.value,
            isPlaying: isPlaying,
            colors: colors,
          ),
          size: Size.infinite,
        );
      case _FlowPatternType.vortex:
        return CustomPaint(
          painter: _VortexBackgroundPainter(
            animationValue: _mainAnimController.value,
            isPlaying: isPlaying,
            colors: colors,
          ),
          size: Size.infinite,
        );
      case _FlowPatternType.stardust:
        return CustomPaint(
          painter: _StardustBackgroundPainter(
            animationValue: _mainAnimController.value,
            isPlaying: isPlaying,
            colors: colors,
          ),
          size: Size.infinite,
        );
    }
  }
}

class _NebulaPlayButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  const _NebulaPlayButton({required this.isPlaying, required this.onTap});

  @override
  State<_NebulaPlayButton> createState() => _NebulaPlayButtonState();
}

class _NebulaPlayButtonState extends State<_NebulaPlayButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       vsync: this,
       duration: const Duration(milliseconds: 1500),
    );
    if (widget.isPlaying) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_NebulaPlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
      _controller.animateTo(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: widget.isPlaying ? [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.4 * _controller.value),
                  blurRadius: 30 * _controller.value,
                  spreadRadius: 10 * _controller.value,
                ),
              ] : [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20),
              ],
            ),
            child: Icon(
              widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_outlined,
              color: Colors.black,
              size: 48,
            ),
          );
        },
      ),
    );
  }
}

class _NebulaBackgroundPainter extends CustomPainter {
  final double animationValue;
  final bool isPlaying;
  final List<Color> colors;
  _NebulaBackgroundPainter({
    required this.animationValue, 
    required this.isPlaying, 
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final speed = isPlaying ? 1.0 : 0.2;
    final val = animationValue * 2 * math.pi;

    void drawCloud(Color color, double xMult, double yMult, double radiusMult, double phase, BlendMode mode) {
      final paint = Paint()
        ..color = color
        ..blendMode = mode
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70);

      final centerX = size.width / 2 + size.width * 0.35 * math.cos(val * speed + phase) * xMult;
      final centerY = size.height / 2 + size.height * 0.35 * math.sin(val * speed + phase) * yMult;
      
      canvas.drawCircle(Offset(centerX, centerY), size.width * 0.4 * radiusMult, paint);
    }

    drawCloud(colors[0].withValues(alpha: 0.7), 1.0, 0.5, 1.2, 0, BlendMode.screen);
    drawCloud(colors[1].withValues(alpha: 0.6), -1.2, 0.8, 1.0, 1.5, BlendMode.plus);
    drawCloud(colors[2].withValues(alpha: 0.3), 0.8, -1.1, 0.8, 3.0, BlendMode.plus);
    drawCloud(colors[3].withValues(alpha: 0.4), -0.5, -0.7, 1.3, 4.5, BlendMode.screen);

    _drawStars(canvas, size, val);
  }

  @override
  bool shouldRepaint(_NebulaBackgroundPainter oldDelegate) => true;
}

// ─── Aurora Painter ────────────────────────────────────────────────────────
class _AuroraBackgroundPainter extends CustomPainter {
  final double animationValue;
  final bool isPlaying;
  final List<Color> colors;

  _AuroraBackgroundPainter({required this.animationValue, required this.isPlaying, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final speed = isPlaying ? 1.0 : 0.2;
    final val = animationValue * 2 * math.pi;

    for (int i = 0; i < 4; i++) {
        final paint = Paint()
            ..color = colors[i].withValues(alpha: 0.7) // Увеличили непрозрачность
            ..strokeWidth = 140 // Сделали ленты шире
            ..style = PaintingStyle.stroke
            ..blendMode = BlendMode.screen // Добавили свечение
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60); // Уменьшили размытие для четкости

        final path = Path();
        final xStart = (size.width / 4) * (i + 0.5); // Центрируем ленты
        path.moveTo(xStart, -100);
        
        for (double y = 0; y < size.height + 200; y += 30) {
            final xOffset = 80 * math.sin(y / size.height * math.pi + val * speed + i * 2);
            path.lineTo(xStart + xOffset, y);
        }
        canvas.drawPath(path, paint);
    }
    _drawStars(canvas, size, val);
  }

  @override
  bool shouldRepaint(_AuroraBackgroundPainter oldDelegate) => true;
}

// ─── Waves Painter ──────────────────────────────────────────────────────────
class _WavesBackgroundPainter extends CustomPainter {
    final double animationValue;
    final bool isPlaying;
    final List<Color> colors;

    _WavesBackgroundPainter({required this.animationValue, required this.isPlaying, required this.colors});

    @override
    void paint(Canvas canvas, Size size) {
        final speed = isPlaying ? 1.5 : 0.3;
        final val = animationValue * 2 * math.pi;

        for (int i = 0; i < 4; i++) {
            final paint = Paint()
                ..color = colors[i].withValues(alpha: 0.6) // Ярче
                ..blendMode = BlendMode.plus // Слой на слой для яркости
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);

            final path = Path();
            final yBase = (size.height / 5) * (i + 1);
            path.moveTo(-50, size.height + 50);
            path.lineTo(-50, yBase);

            for (double x = 0; x < size.width + 50; x += 20) {
                final y = yBase + 40 * math.sin(x / size.width * 2 * math.pi + val * speed + i * 3);
                path.lineTo(x, y);
            }

            path.lineTo(size.width + 50, size.height + 50);
            path.close();
            canvas.drawPath(path, paint);
        }
        _drawStars(canvas, size, val);
    }

    @override
    bool shouldRepaint(_WavesBackgroundPainter oldDelegate) => true;
}

// ─── Vortex Painter ─────────────────────────────────────────────────────────
class _VortexBackgroundPainter extends CustomPainter {
    final double animationValue;
    final bool isPlaying;
    final List<Color> colors;

    _VortexBackgroundPainter({required this.animationValue, required this.isPlaying, required this.colors});

    @override
    void paint(Canvas canvas, Size size) {
        final speed = isPlaying ? 2.0 : 0.4;
        final val = animationValue * 2 * math.pi;
        final center = Offset(size.width / 2, size.height / 2);

        for (int i = 0; i < 15; i++) {
            final paint = Paint()
                ..color = colors[i % 4].withValues(alpha: 0.7)
                ..blendMode = BlendMode.plus
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);

            final angle = val * speed + (i * math.pi / 7);
            final radius = (size.height * 0.2) + (i * 12.0);
            final x = center.dx + radius * math.cos(angle);
            final y = center.dy + radius * math.sin(angle);
            
            canvas.drawCircle(Offset(x, y), 25 + i * 2.5, paint);
        }
        _drawStars(canvas, size, val);
    }

    @override
    bool shouldRepaint(_VortexBackgroundPainter oldDelegate) => true;
}

// ─── Stardust Painter ───────────────────────────────────────────────────────
class _StardustBackgroundPainter extends CustomPainter {
    final double animationValue;
    final bool isPlaying;
    final List<Color> colors;

    _StardustBackgroundPainter({required this.animationValue, required this.isPlaying, required this.colors});

    @override
    void paint(Canvas canvas, Size size) {
        final speed = isPlaying ? 2.5 : 0.4;
        final val = animationValue * 2 * math.pi;
        final rand = math.Random(77);

        // Рисуем "облака" пыли (крупные мягкие пятна)
        for (int i = 0; i < 3; i++) {
            final paint = Paint()
                ..color = colors[i % 4].withValues(alpha: 0.2)
                ..blendMode = BlendMode.screen
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);
            
            final x = (size.width * 0.3) + (size.width * 0.4 * math.sin(val * 0.5 + i));
            final y = size.height * 0.5;
            canvas.drawCircle(Offset(x, y), size.height * 0.6, paint);
        }

        // Рисуем тысячи мелких частиц
        for (int i = 0; i < 80; i++) {
            final basePosX = rand.nextDouble() * size.width;
            final basePosY = rand.nextDouble() * size.height;
            
            // Движение по горизонтали + волновое смещение
            final xShift = (animationValue * speed * 100 + i * 20) % (size.width + 100) - 50;
            final yShift = 30 * math.sin(xShift / 50 + val + i);
            
            final opacity = (0.2 + 0.6 * math.sin(val * 2 + i)).clamp(0.0, 1.0);
            final paint = Paint()
                ..color = colors[i % 4].withValues(alpha: opacity)
                ..blendMode = BlendMode.plus;

            canvas.drawCircle(Offset((basePosX + xShift) % size.width, (basePosY + yShift) % size.height), 0.8 + rand.nextDouble() * 1.5, paint);
        }
        _drawStars(canvas, size, val);
    }

    @override
    bool shouldRepaint(_StardustBackgroundPainter oldDelegate) => true;
}


void _drawStars(Canvas canvas, Size size, double val) {
    final starPaint = Paint()..color = Colors.white;
    final rand = math.Random(13);
    for (int i = 0; i < 30; i++) {
        final x = rand.nextDouble() * size.width;
        final y = rand.nextDouble() * size.height;
        final orbit = 4.0 * math.sin(val * 2 + i);
        final opacity = 0.3 + 0.4 * math.sin(val * 4 + i);
        
        starPaint.color = Colors.white.withValues(alpha: opacity.clamp(0.0, 0.8));
        canvas.drawCircle(Offset(x + orbit, y + orbit), 0.7 + rand.nextDouble() * 0.5, starPaint);
    }
}

class _GrainPainter extends CustomPainter {
  final double opacity;
  _GrainPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: opacity);
    final rand = math.Random(10);
    for (int i = 0; i < 2000; i++) {
      canvas.drawRect(
        Rect.fromLTWH(rand.nextDouble() * size.width, rand.nextDouble() * size.height, 0.5, 0.5),
        paint
      );
    }
  }
  @override
  bool shouldRepaint(_GrainPainter oldDelegate) => false;
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

    final items = tracks.length > crossAxisCount 
      ? tracks.sublist(0, crossAxisCount) 
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

