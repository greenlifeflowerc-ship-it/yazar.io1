class Profile {
  Profile({
    required this.id,
    this.email,
    this.username,
    this.avatarUrl,
    this.level = 1,
    this.xp = 0,
    this.coins = 0,
    this.dna = 0,
  });

  final String id;
  final String? email;
  final String? username;
  final String? avatarUrl;
  final int level;
  final int xp;
  final int coins;
  final int dna;

  /// XP required to reach the next level. Matches the spec formula
  /// `requiredXP = 100 * level * level`.
  int get xpForNextLevel => 100 * level * level;

  double get xpProgress {
    final need = xpForNextLevel;
    if (need <= 0) return 0;
    return (xp / need).clamp(0.0, 1.0);
  }

  String get displayName {
    final u = username;
    if (u != null && u.trim().isNotEmpty) return u;
    final e = email;
    if (e != null && e.contains('@')) return e.split('@').first;
    return 'Player';
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      email: json['email'] as String?,
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      level: (json['level'] as num?)?.toInt() ?? 1,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      dna: (json['dna'] as num?)?.toInt() ?? 0,
    );
  }

  Profile copyWith({
    String? email,
    String? username,
    String? avatarUrl,
    int? level,
    int? xp,
    int? coins,
    int? dna,
  }) {
    return Profile(
      id: id,
      email: email ?? this.email,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      coins: coins ?? this.coins,
      dna: dna ?? this.dna,
    );
  }
}
