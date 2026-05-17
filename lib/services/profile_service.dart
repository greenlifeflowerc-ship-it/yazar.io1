import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/boost.dart';
import '../models/match_history_entry.dart';
import '../models/player_stats.dart';
import '../models/profile.dart';

class MatchSubmitResult {
  MatchSubmitResult({
    required this.level,
    required this.xp,
    required this.coins,
    required this.dna,
    required this.coinsEarned,
    required this.dnaEarned,
    required this.xpEarned,
    required this.xpMultiplier,
    required this.levelUpCoinsEarned,
    required this.levelUpDnaEarned,
    required this.levelsGained,
    required this.leveledUp,
  });

  final int level;
  final int xp;
  final int coins;
  final int dna;
  final int coinsEarned;
  final int dnaEarned;
  final int xpEarned;
  final double xpMultiplier;
  final int levelUpCoinsEarned;
  final int levelUpDnaEarned;
  final int levelsGained;
  final bool leveledUp;

  factory MatchSubmitResult.fromJson(Map<String, dynamic> json) {
    return MatchSubmitResult(
      level: (json['level'] as num?)?.toInt() ?? 1,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      dna: (json['dna'] as num?)?.toInt() ?? 0,
      coinsEarned: (json['coins_earned'] as num?)?.toInt() ?? 0,
      dnaEarned: (json['dna_earned'] as num?)?.toInt() ?? 0,
      xpEarned: (json['xp_earned'] as num?)?.toInt() ?? 0,
      xpMultiplier: (json['xp_multiplier'] as num?)?.toDouble() ?? 1.0,
      levelUpCoinsEarned:
          (json['level_up_coins_earned'] as num?)?.toInt() ?? 0,
      levelUpDnaEarned:
          (json['level_up_dna_earned'] as num?)?.toInt() ?? 0,
      levelsGained: (json['levels_gained'] as num?)?.toInt() ?? 0,
      leveledUp: json['leveled_up'] as bool? ?? false,
    );
  }
}

class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  final SupabaseClient _c = Supabase.instance.client;

  /// Fetch the user's profile row. If the signup trigger hasn't run for some
  /// reason (legacy account, missed event), upsert a default row so the rest
  /// of the app has data to render.
  Future<Profile> fetchOrCreateProfile(User user) async {
    try {
      final row = await _c
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (row != null) {
        return Profile.fromJson(row);
      }
    } catch (e) {
      debugPrint('profile fetch failed, attempting upsert: $e');
    }

    // Server-side default — created fresh, no leftover state from anywhere.
    // CRITICAL: never overwrite an existing row. We try INSERT first, and
    // if the unique-id check fires we fall through to a plain SELECT. This
    // guarantees the new-user starter (200 coins, 50 DNA) is applied only
    // on first creation; existing players keep their current balances.
    try {
      final inserted = await _c
          .from('profiles')
          .insert({
            'id': user.id,
            'email': user.email,
            'username': _usernameFromEmail(user.email),
            'level': 1,
            'xp': 0,
            'coins': 200,
            'dna': 50,
          })
          .select()
          .single();
      try {
        await _c.from('player_stats').upsert({'user_id': user.id});
      } catch (_) {}
      return Profile.fromJson(inserted);
    } catch (_) {
      // Likely a race: the row exists now (the auth trigger beat us). Just
      // read it as-is and preserve every existing value.
      final row = await _c
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      return Profile.fromJson(row);
    }
  }

  String? _usernameFromEmail(String? email) {
    if (email == null || !email.contains('@')) return null;
    return email.split('@').first;
  }

  Future<PlayerStats?> fetchStats() async {
    final user = _c.auth.currentUser;
    if (user == null) return null;
    final row = await _c
        .from('player_stats')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return PlayerStats.fromJson(row);
  }

  Future<List<MatchHistoryEntry>> fetchMatchHistory({int limit = 20}) async {
    final user = _c.auth.currentUser;
    if (user == null) return [];
    final rows = await _c
        .from('match_history')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(MatchHistoryEntry.fromJson)
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchInventory() async {
    final user = _c.auth.currentUser;
    if (user == null) return [];
    final rows = await _c
        .from('player_inventory')
        .select('id, equipped, unlocked_at, inventory_items(*)')
        .eq('user_id', user.id);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchAchievements() async {
    final user = _c.auth.currentUser;
    if (user == null) return [];
    final rows = await _c
        .from('player_achievements')
        .select('id, unlocked_at, achievements(*)')
        .eq('user_id', user.id)
        .order('unlocked_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  // ----------------------------------------------------------- boosts
  Future<List<BoostDefinition>> listBoostDefinitions() async {
    final rows =
        await _c.from('boost_definitions').select().order('price_coins');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(BoostDefinition.fromJson)
        .toList();
  }

  /// Owned (and historical) boosts for the current user. Status can be
  /// 'owned', 'active', 'expired', 'used'.
  Future<List<PlayerBoost>> listOwnedBoosts() async {
    final user = _c.auth.currentUser;
    if (user == null) return [];
    final rows = await _c
        .from('player_boosts')
        .select('*, boost_definitions(*)')
        .eq('user_id', user.id)
        .order('purchased_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(PlayerBoost.fromJson)
        .toList();
  }

  /// Server-validated active boosts. The RPC auto-expires stale rows on
  /// every call so the returned list is always trustworthy.
  Future<List<PlayerBoost>> getActiveBoosts() async {
    try {
      final raw = await _c.rpc('get_active_boosts');
      if (raw is List) {
        return raw
            .cast<Map<String, dynamic>>()
            .map(PlayerBoost.fromJson)
            .toList();
      }
    } catch (e) {
      debugPrint('get_active_boosts failed: $e');
    }
    return [];
  }

  /// Returns the new player_boost id + updated coin/dna totals.
  /// Throws on insufficient currency or unknown key — caller should surface
  /// the error message to the user.
  Future<Map<String, dynamic>> buyBoost(String key) async {
    final raw = await _c.rpc('buy_boost', params: {'p_key': key});
    if (raw is Map) return raw.cast<String, dynamic>();
    throw Exception('Unexpected response from buy_boost');
  }

  Future<Map<String, dynamic>> activateBoost(String playerBoostId) async {
    final raw = await _c.rpc(
      'activate_boost',
      params: {'p_player_boost_id': playerBoostId},
    );
    if (raw is Map) return raw.cast<String, dynamic>();
    throw Exception('Unexpected response from activate_boost');
  }

  /// Call the server-side RPC that calculates rewards atomically. The
  /// frontend cannot directly modify coins/DNA/XP — this is the only path.
  Future<MatchSubmitResult?> submitMatchResult({
    required int score,
    required int massCollected,
    required int kills,
    required int survivalSeconds,
    required int rank,
  }) async {
    final user = _c.auth.currentUser;
    if (user == null) return null;
    try {
      final raw = await _c.rpc('submit_match_result', params: {
        'p_score': score,
        'p_mass_collected': massCollected,
        'p_kills': kills,
        'p_survival_seconds': survivalSeconds,
        'p_rank': rank,
      });
      if (raw is Map<String, dynamic>) {
        return MatchSubmitResult.fromJson(raw);
      }
      if (raw is List && raw.isNotEmpty && raw.first is Map) {
        return MatchSubmitResult.fromJson(
            (raw.first as Map).cast<String, dynamic>());
      }
    } catch (e) {
      debugPrint('submit_match_result failed: $e');
    }
    return null;
  }
}
