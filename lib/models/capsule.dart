import 'dart:convert';
import 'dart:math';

/// Rarity tier for a capsule. Determines brew time and possible rewards.
enum CapsuleTier {
  common,
  rare,
  epic,
  legendary,
  mystery,
}

extension CapsuleTierX on CapsuleTier {
  String get displayName {
    switch (this) {
      case CapsuleTier.common:    return 'Common';
      case CapsuleTier.rare:      return 'Rare';
      case CapsuleTier.epic:      return 'Epic';
      case CapsuleTier.legendary: return 'Legendary';
      case CapsuleTier.mystery:   return 'Mystery';
    }
  }

  /// Brew duration before the capsule can be opened for free.
  Duration get brewTime {
    switch (this) {
      case CapsuleTier.common:    return const Duration(minutes: 30);
      case CapsuleTier.rare:      return const Duration(hours: 2);
      case CapsuleTier.epic:      return const Duration(hours: 8);
      case CapsuleTier.legendary: return const Duration(hours: 24);
      case CapsuleTier.mystery:   return const Duration(hours: 12);
    }
  }

  /// DNA cost to skip the remaining brew time.
  int get skipCostDna {
    switch (this) {
      case CapsuleTier.common:    return 10;
      case CapsuleTier.rare:      return 30;
      case CapsuleTier.epic:      return 80;
      case CapsuleTier.legendary: return 200;
      case CapsuleTier.mystery:   return 120;
    }
  }

  /// Gradient colours for the capsule card.
  /// Tuned for high contrast on dark backgrounds.
  List<int> get gradientArgb {
    switch (this) {
      case CapsuleTier.common:
        return [0xFFD0D6E2, 0xFF8892A8]; // silver
      case CapsuleTier.rare:
        return [0xFF3FA0FF, 0xFF1668DD]; // electric blue
      case CapsuleTier.epic:
        return [0xFFB667FF, 0xFF7A24E0]; // vibrant purple
      case CapsuleTier.legendary:
        return [0xFFFFD700, 0xFFE08C00]; // rich gold
      case CapsuleTier.mystery:
        return [0xFF22E5FF, 0xFF0098C2]; // bright cyan
    }
  }
}

// ── Reward ───────────────────────────────────────────────────────────────────

enum CapsuleRewardType { coins, dna, skinPiece, fullSkin }

class CapsuleReward {
  const CapsuleReward({
    required this.type,
    this.amount = 0,
    this.skinKey,
    this.skinName,
    this.skinImagePath,
    this.pieceIndex,
  });

  final CapsuleRewardType type;

  /// For coins / dna rewards.
  final int amount;

  /// For skinPiece / fullSkin rewards.
  final String? skinKey;
  final String? skinName;
  final String? skinImagePath;

  /// Which of the 5 pieces (0-4) this is (skinPiece only).
  final int? pieceIndex;
}

// ── Slot ─────────────────────────────────────────────────────────────────────

/// One of the 3 capsule slots the player has.
class CapsuleSlot {
  CapsuleSlot({required this.slotIndex});

  final int slotIndex; // 0, 1, or 2

  CapsuleTier? tier;
  DateTime? brewStartedAt;
  bool isReady = false;
  bool isEmpty = true;

  bool get isBrewComplete {
    if (isEmpty || tier == null || brewStartedAt == null) return false;
    return DateTime.now().isAfter(brewStartedAt!.add(tier!.brewTime));
  }

  Duration get remainingBrewTime {
    if (isEmpty || tier == null || brewStartedAt == null) return Duration.zero;
    final done = brewStartedAt!.add(tier!.brewTime);
    final left = done.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  void start(CapsuleTier t) {
    tier = t;
    brewStartedAt = DateTime.now();
    isEmpty = false;
    isReady = false;
  }

  void clear() {
    tier = null;
    brewStartedAt = null;
    isEmpty = true;
    isReady = false;
  }

  Map<String, dynamic> toJson() => {
        'slotIndex': slotIndex,
        'tier': tier?.index,
        'brewStartedAt': brewStartedAt?.toIso8601String(),
        'isEmpty': isEmpty,
        'isReady': isReady,
      };

  factory CapsuleSlot.fromJson(Map<String, dynamic> j) {
    final slot = CapsuleSlot(slotIndex: j['slotIndex'] as int);
    final tierIdx = j['tier'] as int?;
    slot.tier = tierIdx != null ? CapsuleTier.values[tierIdx] : null;
    final bs = j['brewStartedAt'] as String?;
    slot.brewStartedAt = bs != null ? DateTime.parse(bs) : null;
    slot.isEmpty = j['isEmpty'] as bool? ?? true;
    slot.isReady = j['isReady'] as bool? ?? false;
    return slot;
  }
}

// ── Inventory (in-memory singleton backed by SharedPreferences key) ──────────

class CapsuleInventory {
  CapsuleInventory._();
  static final CapsuleInventory instance = CapsuleInventory._();

  static const int maxSlots = 3;

  final List<CapsuleSlot> slots = List.generate(
    maxSlots,
    (i) => CapsuleSlot(slotIndex: i),
  );

  void loadFromJson(String raw) {
    try {
      final list = jsonDecode(raw) as List;
      for (int i = 0; i < list.length && i < maxSlots; i++) {
        final data = list[i] as Map<String, dynamic>;
        slots[i] = CapsuleSlot.fromJson(data);
      }
    } catch (_) {}
  }

  String saveToJson() => jsonEncode(slots.map((s) => s.toJson()).toList());

  int get firstEmptySlotIndex =>
      slots.indexWhere((s) => s.isEmpty);

  bool get hasFreeSlot => firstEmptySlotIndex >= 0;

  /// Award a capsule based on match performance.
  /// Returns the awarded tier, or null if all slots are full.
  CapsuleTier? awardForMatch({
    required int rank,
    required int survivalSeconds,
  }) {
    if (!hasFreeSlot) return null;

    final rng = Random();
    CapsuleTier tier;
    if (rank == 1) {
      tier = rng.nextDouble() < 0.30
          ? CapsuleTier.mystery
          : CapsuleTier.legendary;
    } else if (rank <= 3) {
      tier = CapsuleTier.epic;
    } else if (rank <= 10) {
      tier = CapsuleTier.rare;
    } else {
      tier = CapsuleTier.common;
    }

    // Survival bonus: > 10 min upgrades the tier (capped at legendary).
    if (survivalSeconds > 600) {
      const upgradePath = {
        CapsuleTier.common: CapsuleTier.rare,
        CapsuleTier.rare: CapsuleTier.epic,
        CapsuleTier.epic: CapsuleTier.legendary,
      };
      final upgraded = upgradePath[tier];
      if (upgraded != null) tier = upgraded;
    }

    final idx = firstEmptySlotIndex;
    if (idx < 0) return null;
    slots[idx].start(tier);
    return tier;
  }
}
