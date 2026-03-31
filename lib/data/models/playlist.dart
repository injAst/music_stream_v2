class Playlist {
  final String id;
  final String name;
  final String? description;
  final String? artworkUrl;
  final bool isPublic;
  final int trackCount;
  final DateTime? createdAt;

  Playlist({
    required this.id,
    required this.name,
    this.description,
    this.artworkUrl,
    this.isPublic = false,
    this.trackCount = 0,
    this.createdAt,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      artworkUrl: json['artwork_url'] as String?,
      isPublic: json['is_public'] == true,
      trackCount: json['track_count'] as int? ?? 0,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'artwork_url': artworkUrl,
      'is_public': isPublic,
      'track_count': trackCount,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
