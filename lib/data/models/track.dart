class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.streamUrl,
    this.artworkUrl,
    this.durationSeconds,
    this.canDelete = false,
    this.isLiked = false,
    this.likesCount = 0,
    this.createdAt,
  });

  final String id;
  final String title;
  final String artist;
  final String streamUrl;
  final String? artworkUrl;
  final int? durationSeconds;
  final bool canDelete;
  final bool isLiked;
  final int likesCount;
  final DateTime? createdAt;

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? streamUrl,
    String? artworkUrl,
    int? durationSeconds,
    bool? canDelete,
    bool? isLiked,
    int? likesCount,
    DateTime? createdAt,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      streamUrl: streamUrl ?? this.streamUrl,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      canDelete: canDelete ?? this.canDelete,
      isLiked: isLiked ?? this.isLiked,
      likesCount: likesCount ?? this.likesCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'streamUrl': streamUrl,
        'artworkUrl': artworkUrl,
        'durationSeconds': durationSeconds,
        'canDelete': canDelete,
        'isLiked': isLiked,
        'likesCount': likesCount,
        'createdAt': createdAt?.toIso8601String(),
      };

  static Track fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      streamUrl: (json['streamUrl'] ?? json['stream_url']) as String,
      artworkUrl: (json['artworkUrl'] ?? json['artwork_url']) as String?,
      durationSeconds: (json['durationSeconds'] ?? json['duration_seconds']) as int?,
      canDelete: (json['canDelete'] ?? json['can_delete']) as bool? ?? false,
      isLiked: (json['isLiked'] ?? json['is_liked']) as bool? ?? false,
      likesCount: (json['likesCount'] ?? json['likes_count']) as int? ?? 0,
      createdAt: json['createdAt'] != null || json['created_at'] != null
          ? DateTime.parse((json['createdAt'] ?? json['created_at']) as String)
          : null,
    );
  }
}
