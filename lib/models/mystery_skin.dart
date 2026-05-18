import 'dart:convert';

/// Evolution level of a Mystery Skin.
/// L0 = plain (no special behaviour).
/// L1 = persistent subtle shimmer.
/// L2 = electric glow ring, active ONLY when the player just split (+ short cooldown).
/// L3 = alternate face, shown ONLY when the player just split (+ short cooldown).
enum SkinEvolutionLevel { l0, l1, l2, l3 }

extension SkinEvolutionLevelX on SkinEvolutionLevel {
  String get displayName {
    switch (this) {
      case SkinEvolutionLevel.l0: return 'Base';
      case SkinEvolutionLevel.l1: return 'Level 1';
      case SkinEvolutionLevel.l2: return 'Level 2';
      case SkinEvolutionLevel.l3: return 'Level 3';
    }
  }

  /// Number of skin pieces required to reach this level from L0.
  int get piecesRequired {
    switch (this) {
      case SkinEvolutionLevel.l0: return 0;
      case SkinEvolutionLevel.l1: return 5;
      case SkinEvolutionLevel.l2: return 15;
      case SkinEvolutionLevel.l3: return 30;
    }
  }
}

/// One mystery skin definition — a skin that can be assembled from pieces.
class MysterySkin {
  MysterySkin({
    required this.key,
    required this.name,
    required this.baseImagePath,
    this.altImagePath,
    this.evolutionLevel = SkinEvolutionLevel.l0,
    this.piecesOwned = 0,
  });

  final String key;
  final String name;

  /// Base skin image (L0–L2 use this).
  final String baseImagePath;

  /// Alternate face image shown on split at L3.
  final String? altImagePath;

  SkinEvolutionLevel evolutionLevel;
  int piecesOwned;

  /// Total pieces needed for the NEXT level (null if already max).
  int? get piecesForNext {
    switch (evolutionLevel) {
      case SkinEvolutionLevel.l0: return SkinEvolutionLevel.l1.piecesRequired;
      case SkinEvolutionLevel.l1: return SkinEvolutionLevel.l2.piecesRequired;
      case SkinEvolutionLevel.l2: return SkinEvolutionLevel.l3.piecesRequired;
      case SkinEvolutionLevel.l3: return null;
    }
  }

  bool get canEvolve {
    final needed = piecesForNext;
    return needed != null && piecesOwned >= needed;
  }

  /// Skin is unlocked (equippable) once evolved past L0 or has enough pieces to unlock.
  bool get isUnlocked =>
      evolutionLevel != SkinEvolutionLevel.l0 ||
      piecesOwned >= SkinEvolutionLevel.l1.piecesRequired;

  void evolve() {
    if (!canEvolve) return;
    switch (evolutionLevel) {
      case SkinEvolutionLevel.l0:
        evolutionLevel = SkinEvolutionLevel.l1;
        break;
      case SkinEvolutionLevel.l1:
        evolutionLevel = SkinEvolutionLevel.l2;
        break;
      case SkinEvolutionLevel.l2:
        evolutionLevel = SkinEvolutionLevel.l3;
        break;
      case SkinEvolutionLevel.l3:
        break;
    }
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'piecesOwned': piecesOwned,
        'evolutionLevel': evolutionLevel.index,
      };

  static MysterySkin fromDefinition(
    Map<String, dynamic> def,
    Map<String, dynamic>? progress,
  ) {
    return MysterySkin(
      key: def['key'] as String,
      name: def['name'] as String,
      baseImagePath: def['baseImagePath'] as String,
      altImagePath: def['altImagePath'] as String?,
      piecesOwned: (progress?['piecesOwned'] as num?)?.toInt() ?? 0,
      evolutionLevel: SkinEvolutionLevel.values[
          (progress?['evolutionLevel'] as num?)?.toInt() ?? 0],
    );
  }
}

// ── Registry ──────────────────────────────────────────────────────────────────

/// Hard-coded catalogue of mystery skins.
/// In the future this can be fetched from Supabase.
class MysterySkinRegistry {
  MysterySkinRegistry._();
  static final MysterySkinRegistry instance = MysterySkinRegistry._();

  static const List<Map<String, String>> _definitions = [
    {
      'key': 'mystery_bat',
      'name': 'Bat',
      'baseImagePath': 'assets/skins/mystery/bat.png',
      'altImagePath': 'assets/skins/mystery/bat_alt.png',
    },
    {
      'key': 'mystery_bbb',
      'name': 'BBB',
      'baseImagePath': 'assets/skins/mystery/bbb.png',
      'altImagePath': 'assets/skins/mystery/bbb_alt.png',
    },
    {
      'key': 'mystery_eagle',
      'name': 'Eagle',
      'baseImagePath': 'assets/skins/mystery/eagle.png',
      'altImagePath': 'assets/skins/mystery/eagle_alt.png',
    },
    {
      'key': 'mystery_jago',
      'name': 'Jago',
      'baseImagePath': 'assets/skins/mystery/jago.png',
      'altImagePath': 'assets/skins/mystery/jago_alt.png',
    },
    {
      'key': 'mystery_rick',
      'name': 'Rick',
      'baseImagePath': 'assets/skins/mystery/rick.png',
      'altImagePath': 'assets/skins/mystery/rick_alt.png',
    },
  ];

  List<MysterySkin> _skins = [];
  bool _loaded = false;

  List<MysterySkin> get skins {
    if (!_loaded) load(null);
    return List.unmodifiable(_skins);
  }

  MysterySkin? find(String key) =>
      _skins.cast<MysterySkin?>().firstWhere((s) => s?.key == key, orElse: () => null);

  void load(String? savedJson) {
    Map<String, Map<String, dynamic>> progress = {};
    if (savedJson != null && savedJson.isNotEmpty) {
      try {
        final list = jsonDecode(savedJson) as List;
        for (final item in list) {
          final m = item as Map<String, dynamic>;
          progress[m['key'] as String] = m;
        }
      } catch (_) {}
    }

    _skins = _definitions.map((def) {
      return MysterySkin.fromDefinition(def, progress[def['key']]);
    }).toList();
    _loaded = true;
  }

  String saveToJson() {
    return jsonEncode(_skins.map((s) => s.toJson()).toList());
  }

  bool get isLoaded => _loaded;
}
