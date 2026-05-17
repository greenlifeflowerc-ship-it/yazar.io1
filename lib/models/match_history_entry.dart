class MatchHistoryEntry {
  MatchHistoryEntry({
    required this.id,
    required this.score,
    required this.massCollected,
    required this.kills,
    required this.survivalSeconds,
    required this.rank,
    required this.coinsEarned,
    required this.dnaEarned,
    required this.xpEarned,
    required this.createdAt,
  });

  final String id;
  final int score;
  final int massCollected;
  final int kills;
  final int survivalSeconds;
  final int rank;
  final int coinsEarned;
  final int dnaEarned;
  final int xpEarned;
  final DateTime createdAt;

  factory MatchHistoryEntry.fromJson(Map<String, dynamic> json) {
    return MatchHistoryEntry(
      id: json['id'] as String,
      score: (json['score'] as num?)?.toInt() ?? 0,
      massCollected: (json['mass_collected'] as num?)?.toInt() ?? 0,
      kills: (json['kills'] as num?)?.toInt() ?? 0,
      survivalSeconds: (json['survival_seconds'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      coinsEarned: (json['coins_earned'] as num?)?.toInt() ?? 0,
      dnaEarned: (json['dna_earned'] as num?)?.toInt() ?? 0,
      xpEarned: (json['xp_earned'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}
