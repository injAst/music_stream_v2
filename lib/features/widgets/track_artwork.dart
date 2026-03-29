import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class TrackArtwork extends StatelessWidget {
  const TrackArtwork({
    super.key,
    required this.url,
    this.size = 56,
    this.radius = 6,
  });

  final String? url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final u = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: u != null && u.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: u,
                fit: BoxFit.cover,
                memCacheWidth: (size * 3).toInt(),
                placeholder: (_, __) => Container(color: AppTheme.surfaceHighlight),
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppTheme.surfaceHighlight,
      child: Icon(
        Icons.music_note_rounded,
        size: size * 0.45,
        color: AppTheme.textSecondary,
      ),
    );
  }
}
