class PlayerStats {
  PlayerStats({
    required this.userId,
    this.matchesPlayed = 0,
    this.bestScore = 0,
    this.totalScore = 0,
    this.totalMassCollected = 0,
    this.totalKills = 0,
    this.totalDeaths = 0,
    this.totalSurvivalSeconds = 0,
    this.wins = 0,
  });

  final String userId;
  final int matchesPlayed;
  final int bestScore;
  final int totalScore;
  final int totalMassCollected;
  final int totalKills;
  final int totalDeaths;
  final int totalSurvivalSeconds;
  final int wins;

  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    return PlayerStats(
      userId: json['user_id'] as String,
      matchesPlayed: (json['matches_played'] as num?)?.toInt() ?? 0,
      bestScore: (json['best_score'] as num?)?.toInt() ?? 0,
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      totalMassCollected:
          (json['total_mass_collected'] as num?)?.toInt() ?? 0,
      totalKills: (json['total_kills'] as num?)?.toInt() ?? 0,
      totalDeaths: (json['total_deaths'] as num?)?.toInt() ?? 0,
      totalSurvivalSeconds:
          (json['total_survival_seconds'] as num?)?.toInt() ?? 0,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
    );
  }
}
