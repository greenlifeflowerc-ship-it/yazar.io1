/// A boost SKU from `boost_definitions` — the store catalogue.
class BoostDefinition {
  BoostDefinition({
    required this.id,
    required this.key,
    required this.name,
    required this.type,
    required this.multiplier,
    required this.durationSeconds,
    required this.priceCoins,
    required this.priceDna,
    this.description,
    this.iconUrl,
  });

  final String id;
  final String key;
  final String name;
  final String type; // 'mass' | 'xp'
  final double multiplier;
  final int durationSeconds;
  final int priceCoins;
  final int priceDna;
  final String? description;
  final String? iconUrl;

  bool get isMass => type == 'mass';
  bool get isXp => type == 'xp';

  factory BoostDefinition.fromJson(Map<String, dynamic> json) {
    return BoostDefinition(
      id: json['id'] as String,
      key: json['key'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      multiplier: (json['multiplier'] as num).toDouble(),
      durationSeconds: (json['duration_seconds'] as num).toInt(),
      priceCoins: (json['price_coins'] as num?)?.toInt() ?? 0,
      priceDna: (json['price_dna'] as num?)?.toInt() ?? 0,
      description: json['description'] as String?,
      iconUrl: json['icon_url'] as String?,
    );
  }
}

/// A row from `player_boosts` joined with the definition row.
class PlayerBoost {
  PlayerBoost({
    required this.id,
    required this.boostId,
    required this.status,
    required this.activatedAt,
    required this.expiresAt,
    required this.key,
    required this.name,
    required this.type,
    required this.multiplier,
    required this.durationSeconds,
  });

  final String id;
  final String boostId;
  final String status; // 'owned' | 'active' | 'expired' | 'used'
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final String key;
  final String name;
  final String type; // 'mass' | 'xp'
  final double multiplier;
  final int durationSeconds;

  bool get isMass => type == 'mass';
  bool get isXp => type == 'xp';
  bool get isActive =>
      status == 'active' &&
      expiresAt != null &&
      DateTime.now().isBefore(expiresAt!);

  Duration get remaining {
    final exp = expiresAt;
    if (exp == null) return Duration.zero;
    final r = exp.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  /// Used for both `get_active_boosts()` rows (joined columns) and
  /// `player_boosts` joined with `boost_definitions(*)` rows.
  factory PlayerBoost.fromJson(Map<String, dynamic> json) {
    // get_active_boosts returns the joined columns flat. Direct table query
    // returns the boost_definitions row nested under `boost_definitions`.
    final nested = json['boost_definitions'];
    Map<String, dynamic>? def = nested is Map
        ? nested.cast<String, dynamic>()
        : null;

    return PlayerBoost(
      id: json['id'] as String,
      boostId: (json['boost_id'] ?? def?['id']) as String,
      status: json['status'] as String? ?? 'owned',
      activatedAt: _parseTs(json['activated_at']),
      expiresAt: _parseTs(json['expires_at']),
      key: (json['key'] ?? def?['key']) as String,
      name: (json['name'] ?? def?['name']) as String,
      type: (json['type'] ?? def?['type']) as String,
      multiplier:
          ((json['multiplier'] ?? def?['multiplier']) as num).toDouble(),
      durationSeconds:
          ((json['duration_seconds'] ?? def?['duration_seconds']) as num)
              .toInt(),
    );
  }

  static DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}
