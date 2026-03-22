class UserProfile {
  const UserProfile({
    required this.email,
    required this.displayName,
    this.avatarUrl,
  });

  final String email;
  final String displayName;
  final String? avatarUrl;

  UserProfile copyWith({
    String? email,
    String? displayName,
    String? avatarUrl,
    bool clearAvatar = false,
  }) {
    return UserProfile(
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
    );
  }

  Map<String, dynamic> toJson() => {
        'email': email,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
      };

  static UserProfile fromJson(Map<String, dynamic> json) {
    return UserProfile(
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}
