import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AudioVisualizer extends StatefulWidget {
  final bool isPlaying;
  const AudioVisualizer({super.key, required this.isPlaying});

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 100),
          painter: _VisualizerPainter(
            animationValue: _controller.value,
            color: AppTheme.accent.withValues(alpha: 0.6),
          ),
        );
      },
    );
  }
}

class _VisualizerPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _VisualizerPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final width = size.width;
    final height = size.height;
    final centerY = height / 2;

    path.moveTo(0, centerY);

    for (double i = 0; i <= width; i++) {
      // Комбинация синусоид для более живой волны
      final x = i;
      final relativeX = i / width;
      
      // Затухание по краям (envelope)
      final envelope = math.sin(relativeX * math.pi);
      
      final y = centerY +
          envelope * 25 * math.sin(relativeX * 3 * math.pi + animationValue * 2 * math.pi) +
          envelope * 10 * math.sin(relativeX * 7 * math.pi - animationValue * 4 * math.pi);
          
      path.lineTo(x, y);
    }

    // Добавляем вторую волну с другим фазовым сдвигом для глубины
    final path2 = Path();
    path2.moveTo(0, centerY);
    for (double i = 0; i <= width; i++) {
      final x = i;
      final relativeX = i / width;
      final envelope = math.sin(relativeX * math.pi);
      
      final y = centerY +
          envelope * 20 * math.sin(relativeX * 4 * math.pi - animationValue * 2 * math.pi) +
          envelope * 12 * math.sin(relativeX * 5 * math.pi + animationValue * 3 * math.pi);
      path2.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
    canvas.drawPath(
      path2,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_VisualizerPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
