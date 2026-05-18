import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/capsule.dart';
import '../models/mystery_skin.dart';
import 'auth_service.dart';

/// Server sync layer for capsules and mystery-skin progress.
///
/// Strategy: local state is the working copy (fast UI). After every change
/// we fire-and-forget a push to Supabase. On login / screen open we pull
/// the authoritative state and apply it locally. New accounts naturally
/// start with zero progress because the DB has no rows for them.
class CapsuleService {
  CapsuleService._();
  static final CapsuleService instance = CapsuleService._();

  SupabaseClient get _sb => Supabase.instance.client;
  String? get _uid => _sb.auth.currentUser?.id;
  bool get _ready => AuthService.instance.isLoggedIn && _uid != null;

  // ── Capsule inventory ──────────────────────────────────────────────────────

  /// Pull active capsules from server and apply to the local inventory.
  /// Clears local slots first so deletions on other devices propagate.
  Future<void> pullInventory(CapsuleInventory inv) async {
    if (!_ready) return;
    try {
      final rows = await _sb
          .from('capsule_inventory')
          .select()
          .eq('user_id', _uid!)
          .eq('is_opened', false);

      // Reset local slots.
      for (final s in inv.slots) {
        s.clear();
      }
      for (final raw in (rows as List)) {
        final row = raw as Map<String, dynamic>;
        final slotIdx = row['slot_index'] as int;
        if (slotIdx < 0 || slotIdx >= CapsuleInventory.maxSlots) continue;
        final tier = CapsuleTier.values.firstWhere(
          (t) => t.name == row['tier'],
          orElse: () => CapsuleTier.common,
        );
        inv.slots[slotIdx]
          ..tier = tier
          ..brewStartedAt = DateTime.parse(row['brew_started'] as String).toLocal()
          ..isEmpty = false
          ..isReady = false;
      }
    } catch (e) {
      debugPrint('CapsuleService.pullInventory failed: $e');
    }
  }

  /// Push a freshly-awarded capsule to the server (upsert by slot).
  Future<void> awardCapsuleOnServer({
    required CapsuleTier tier,
    required int slotIndex,
    required DateTime brewStartedAt,
  }) async {
    if (!_ready) return;
    try {
      // Replace any existing row at this slot for this user.
      await _sb.from('capsule_inventory')
          .delete()
          .eq('user_id', _uid!)
          .eq('slot_index', slotIndex);
      await _sb.from('capsule_inventory').insert({
        'user_id': _uid,
        'slot_index': slotIndex,
        'tier': tier.name,
        'brew_started': brewStartedAt.toUtc().toIso8601String(),
        'is_opened': false,
      });
    } catch (e) {
      debugPrint('CapsuleService.awardCapsuleOnServer failed: $e');
    }
  }

  /// Mark a slot's capsule as opened on the server.
  Future<void> openCapsuleOnServer(int slotIndex) async {
    if (!_ready) return;
    try {
      await _sb.from('capsule_inventory')
          .delete()
          .eq('user_id', _uid!)
          .eq('slot_index', slotIndex);
    } catch (e) {
      debugPrint('CapsuleService.openCapsuleOnServer failed: $e');
    }
  }

  // ── Mystery skin progress ──────────────────────────────────────────────────

  /// Pull all mystery-skin progress and apply to the local registry.
  Future<void> pullMysteryProgress(MysterySkinRegistry reg) async {
    if (!_ready) return;
    try {
      final rows = await _sb
          .from('mystery_skin_pieces')
          .select()
          .eq('user_id', _uid!);

      // Reset all skins to defaults first so deletions / fresh accounts work.
      for (final ms in reg.skins) {
        ms.piecesOwned = 0;
        ms.evolutionLevel = SkinEvolutionLevel.l0;
      }
      for (final raw in (rows as List)) {
        final row = raw as Map<String, dynamic>;
        final ms = reg.find(row['skin_key'] as String);
        if (ms == null) continue;
        ms.piecesOwned = (row['pieces_owned'] as num?)?.toInt() ?? 0;
        final lvl = (row['evolution_level'] as num?)?.toInt() ?? 0;
        ms.evolutionLevel = SkinEvolutionLevel
            .values[lvl.clamp(0, SkinEvolutionLevel.values.length - 1)];
      }
    } catch (e) {
      debugPrint('CapsuleService.pullMysteryProgress failed: $e');
    }
  }

  /// Upsert one skin's progress to the server.
  Future<void> upsertMysteryProgress(MysterySkin ms) async {
    if (!_ready) return;
    try {
      await _sb.from('mystery_skin_pieces').upsert({
        'user_id': _uid,
        'skin_key': ms.key,
        'pieces_owned': ms.piecesOwned,
        'evolution_level': ms.evolutionLevel.index,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,skin_key');
    } catch (e) {
      debugPrint('CapsuleService.upsertMysteryProgress failed: $e');
    }
  }

  /// Push every skin that has progress (> 0 pieces or evolved past L0).
  Future<void> syncAllMysteryProgress(MysterySkinRegistry reg) async {
    if (!_ready) return;
    for (final ms in reg.skins) {
      if (ms.piecesOwned > 0 || ms.evolutionLevel != SkinEvolutionLevel.l0) {
        await upsertMysteryProgress(ms);
      }
    }
  }
}
