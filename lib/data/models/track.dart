class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.streamUrl,
    this.artworkUrl,
    this.durationSeconds,
  });

  final String id;
  final String title;
  final String artist;
  final String streamUrl;
  final String? artworkUrl;
  final int? durationSeconds;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'streamUrl': streamUrl,
        'artworkUrl': artworkUrl,
        'durationSeconds': durationSeconds,
      };

  static Track fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      streamUrl: json['streamUrl'] as String,
      artworkUrl: json['artworkUrl'] as String?,
      durationSeconds: json['durationSeconds'] as int?,
    );
  }
}
