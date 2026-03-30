class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final Map<String, dynamic>? lastTrack;
  final String? lastPlayedAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.lastTrack,
    this.lastPlayedAt,
  });

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
    Map<String, dynamic>? lastTrack,
    String? lastPlayedAt,
    bool clearAvatar = false,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
      lastTrack: lastTrack ?? this.lastTrack,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'last_track': lastTrack,
        'last_played_at': lastPlayedAt,
      };

  static UserProfile fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      displayName: (json['display_name'] ?? json['displayName'] ?? '') as String,
      avatarUrl: (json['avatar_url'] ?? json['avatarUrl']) as String?,
      lastTrack: json['last_track'] as Map<String, dynamic>?,
      lastPlayedAt: json['last_played_at'] as String?,
    );
  }
}
