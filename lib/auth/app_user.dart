class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.avatarEmoji,
    required this.createdAt,
  });

  final String id;
  final String displayName;
  final String avatarEmoji;
  final DateTime createdAt;

  AppUser copyWith({
    String? displayName,
    String? avatarEmoji,
  }) {
    return AppUser(
      id: id,
      displayName: displayName ?? this.displayName,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      createdAt: createdAt,
    );
  }
}

