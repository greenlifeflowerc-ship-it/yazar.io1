import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../services/storage_service.dart';

/// Holds the player's currently-selected skin: its asset path plus the
/// already-decoded `ui.Image` so the painter can blit it synchronously each
/// frame. Listeners are notified when the selection changes (so the main-menu
/// avatar preview and the painter both refresh).
///
/// Also tracks skin evolution level (0–3) and manages the split-triggered
/// visual effects:
///  • L2 — electric glow ring, active for ~3 s after each split.
///  • L3 — alternate face, active for ~5 s after each split.
/// Both have a light cooldown so they can't fire back-to-back indefinitely.
class SkinSettings extends ChangeNotifier {
  SkinSettings._();
  static final SkinSettings instance = SkinSettings._();

  // ── Base skin ──────────────────────────────────────────────────────────────
  String? _skinPath;
  String? get skinPath => _skinPath;

  ui.Image? _skinImage;
  ui.Image? get skinImage => _skinImage;

  bool _loading = false;
  bool get isLoading => _loading;

  // ── Evolution level ────────────────────────────────────────────────────────
  /// 0 = plain, 1 = L1 shimmer, 2 = L2 glow-on-split, 3 = L3 alt-face-on-split.
  int _evolutionLevel = 0;
  int get evolutionLevel => _evolutionLevel;

  /// Alternate face image for L3 (loaded alongside the base skin).
  String? _altSkinPath;
  ui.Image? _altSkinImage;
  ui.Image? get altSkinImage => _altSkinImage;

  // ── Split-effect state ─────────────────────────────────────────────────────
  // L2: glow ring shown for _glowDuration after a split, then off for _glowCooldown.
  static const Duration _glowDuration  = Duration(milliseconds: 3500);
  static const Duration _glowCooldown  = Duration(milliseconds: 2000);

  // L3: alt face shown for _altDuration after a split, then off for _altCooldown.
  static const Duration _altDuration   = Duration(milliseconds: 5000);
  static const Duration _altCooldown   = Duration(milliseconds: 3000);

  DateTime? _glowActiveUntil;
  DateTime? _glowCooldownUntil;
  DateTime? _altActiveUntil;
  DateTime? _altCooldownUntil;

  /// True while the L2 glow ring should be rendered.
  bool get isGlowActive {
    if (_evolutionLevel < 2) return false;
    final now = DateTime.now();
    return _glowActiveUntil != null && now.isBefore(_glowActiveUntil!);
  }

  /// True while the L3 alternate face should be shown.
  bool get isAltFaceActive {
    if (_evolutionLevel < 3) return false;
    final now = DateTime.now();
    return _altActiveUntil != null && now.isBefore(_altActiveUntil!);
  }

  /// Called by SplitHandler when the human player splits a cell.
  void onPlayerSplit() {
    final now = DateTime.now();

    // L2 glow
    if (_evolutionLevel >= 2) {
      final cooldownDone = _glowCooldownUntil == null || now.isAfter(_glowCooldownUntil!);
      if (cooldownDone && !isGlowActive) {
        _glowActiveUntil = now.add(_glowDuration);
        _glowCooldownUntil = now.add(_glowDuration + _glowCooldown);
      }
    }

    // L3 alt face
    if (_evolutionLevel >= 3) {
      final cooldownDone = _altCooldownUntil == null || now.isAfter(_altCooldownUntil!);
      if (cooldownDone && !isAltFaceActive) {
        _altActiveUntil = now.add(_altDuration);
        _altCooldownUntil = now.add(_altDuration + _altCooldown);
      }
    }
  }

  // ── Persistence ────────────────────────────────────────────────────────────
  Future<void> loadFromStorage() async {
    final path = StorageService.instance.getString('selectedSkin');
    final level = StorageService.instance.getInt('skinEvolutionLevel') ?? 0;
    final altPath = StorageService.instance.getString('altSkinPath');
    if (path != null) {
      await selectSkin(path, save: false, evolutionLevel: level, altPath: altPath);
    }
  }

  Future<void> selectSkin(
    String? path, {
    bool save = true,
    int evolutionLevel = 0,
    String? altPath,
  }) async {
    final pathChanged = path != _skinPath;
    final levelChanged = evolutionLevel != _evolutionLevel;
    final altChanged = altPath != _altSkinPath;
    if (!pathChanged && !levelChanged && !altChanged) return;

    _skinPath = path;
    _evolutionLevel = evolutionLevel;
    _altSkinPath = altPath;

    if (save) {
      StorageService.instance.setString('selectedSkin', path ?? '');
      StorageService.instance.setInt('skinEvolutionLevel', evolutionLevel);
      StorageService.instance.setString('altSkinPath', altPath ?? '');
    }

    if (path == null || path.isEmpty) {
      _skinPath = null;
      _skinImage = null;
      _altSkinImage = null;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();

    try {
      // Load base image
      if (pathChanged || _skinImage == null) {
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        if (path == _skinPath) _skinImage = frame.image;
      }

      // Load alt image (L3)
      if (altPath != null && altPath.isNotEmpty && (altChanged || _altSkinImage == null)) {
        try {
          final altData = await rootBundle.load(altPath);
          final altCodec = await ui.instantiateImageCodec(altData.buffer.asUint8List());
          final altFrame = await altCodec.getNextFrame();
          if (altPath == _altSkinPath) _altSkinImage = altFrame.image;
        } catch (_) {
          _altSkinImage = null;
        }
      } else if (altPath == null || altPath.isEmpty) {
        _altSkinImage = null;
      }
    } catch (_) {
      if (path == _skinPath) _skinImage = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Update only the evolution level (e.g. after capsule upgrade), keeping
  /// the same skin path.
  Future<void> setEvolutionLevel(int level, {String? altPath}) async {
    await selectSkin(
      _skinPath,
      save: true,
      evolutionLevel: level,
      altPath: altPath ?? _altSkinPath,
    );
  }

  void clear() {
    _skinPath = null;
    _skinImage = null;
    _altSkinPath = null;
    _altSkinImage = null;
    _evolutionLevel = 0;
    StorageService.instance.setString('selectedSkin', '');
    StorageService.instance.setInt('skinEvolutionLevel', 0);
    StorageService.instance.setString('altSkinPath', '');
    notifyListeners();
  }
}
