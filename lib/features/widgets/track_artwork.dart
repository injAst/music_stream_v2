import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/config/api_config.dart';
import '../../core/theme/app_theme.dart';

class TrackArtwork extends StatelessWidget {
  const TrackArtwork({
    super.key,
    required this.url,
    this.size = 56,
    this.radius = 6,
    this.heroTag,
  });

  final String? url;
  final double size;
  final double radius;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final u = ApiConfig.resolveUrl(url);
    Widget content = ClipRRect(
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

    if (heroTag != null) {
      return Hero(
        tag: heroTag!,
        child: content,
      );
    }
    return content;
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
