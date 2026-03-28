class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.streamUrl,
    this.artworkUrl,
    this.durationSeconds,
    this.canDelete = false,
  });

  final String id;
  final String title;
  final String artist;
  final String streamUrl;
  final String? artworkUrl;
  final int? durationSeconds;
  final bool canDelete;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'streamUrl': streamUrl,
        'artworkUrl': artworkUrl,
        'durationSeconds': durationSeconds,
        'canDelete': canDelete,
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
    );
  }
}
