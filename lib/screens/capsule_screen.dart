import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../game/skin_settings.dart';
import '../models/capsule.dart';
import '../models/mystery_skin.dart';
import '../services/auth_service.dart';
import '../services/capsule_service.dart';
import '../services/storage_service.dart';
import '../widgets/capsule_reward_popup.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Professional palette — solid colours, no opacity hacks for primary surfaces.
// ─────────────────────────────────────────────────────────────────────────────
class _P {
  static const bg       = Color(0xFF0B0F22);   // screen background
  static const bg2      = Color(0xFF141A33);   // sub-surface
  static const surface  = Color(0xFF1B2245);   // cards
  static const surface2 = Color(0xFF252D55);   // elevated/active
  static const border   = Color(0xFF323A66);   // default card border
  static const borderHi = Color(0xFF4D578E);   // emphasized border

  static const textPri  = Color(0xFFFFFFFF);
  static const textSec  = Color(0xFFC1C8E4);
  static const textTer  = Color(0xFF8088AE);

  static const accent     = Color(0xFF22E5FF); // mystery accent
  static const accentDark = Color(0xFF0098C2);
  static const gold       = Color(0xFFFFD700);
  static const purple     = Color(0xFFA63CFF);
  static const green      = Color(0xFF22D656);
}

class CapsuleScreen extends StatefulWidget {
  const CapsuleScreen({super.key});

  @override
  State<CapsuleScreen> createState() => _CapsuleScreenState();
}

class _CapsuleScreenState extends State<CapsuleScreen>
    with TickerProviderStateMixin {
  final _inventory = CapsuleInventory.instance;
  final _registry = MysterySkinRegistry.instance;
  late final AnimationController _pulseCtrl;
  late final PageController _mysteryCtrl;
  int _mysteryIdx = 0;
  Timer? _ticker;

  static final _rng = Random();

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _mysteryCtrl = PageController(viewportFraction: 0.55);

    final raw = StorageService.instance.getString('capsuleInventory') ?? '';
    if (raw.isNotEmpty) _inventory.loadFromJson(raw);
    if (!_registry.isLoaded) {
      _registry.load(StorageService.instance.getString('mysterySkins'));
    }

    // Pull authoritative state from Supabase when logged in.
    // Server is the source of truth — new accounts will start clean.
    if (AuthService.instance.isLoggedIn) {
      CapsuleService.instance.pullInventory(_inventory).then((_) {
        if (mounted) setState(() {});
        StorageService.instance
            .setString('capsuleInventory', _inventory.saveToJson());
      });
      CapsuleService.instance.pullMysteryProgress(_registry).then((_) {
        if (mounted) setState(() {});
        StorageService.instance
            .setString('mysterySkins', _registry.saveToJson());
      });
    }

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _mysteryCtrl.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  void _save() {
    StorageService.instance
        .setString('capsuleInventory', _inventory.saveToJson());
    StorageService.instance
        .setString('mysterySkins', _registry.saveToJson());
    // Fire-and-forget push to server.
    if (AuthService.instance.isLoggedIn) {
      CapsuleService.instance.syncAllMysteryProgress(_registry);
    }
  }

  // ── Open / Skip ────────────────────────────────────────────────────────────

  Future<void> _openCapsule(CapsuleSlot slot) async {
    if (slot.isEmpty || slot.tier == null) return;
    if (!slot.isBrewComplete) {
      final dna = AuthService.instance.profile?.dna ?? 0;
      final cost = slot.tier!.skipCostDna;
      if (dna < cost) {
        _showSnack('Need $cost DNA to skip');
        return;
      }
      final ok = await _confirmSkip(slot.tier!, cost);
      if (!ok) return;
    }

    final tier = slot.tier!;
    final slotIdx = slot.slotIndex;
    final rewards = _generateRewards(tier);
    slot.clear();
    _save();
    // Notify server the capsule was opened.
    if (AuthService.instance.isLoggedIn) {
      CapsuleService.instance.openCapsuleOnServer(slotIdx);
    }
    setState(() {});

    if (mounted) {
      await CapsuleRewardPopup.show(context, tier: tier, rewards: rewards);
    }
    for (final r in rewards) {
      _applyReward(r);
    }
    setState(() {});
    _save();
  }

  void _applyReward(CapsuleReward reward) {
    switch (reward.type) {
      case CapsuleRewardType.skinPiece:
        if (reward.skinKey != null) {
          _registry.find(reward.skinKey!)?.piecesOwned++;
        }
        break;
      case CapsuleRewardType.fullSkin:
        if (reward.skinKey != null) {
          final ms = _registry.find(reward.skinKey!);
          if (ms != null && ms.piecesOwned < 5) ms.piecesOwned = 5;
        }
        break;
      case CapsuleRewardType.coins:
      case CapsuleRewardType.dna:
        break;
    }
  }

  Future<bool> _confirmSkip(CapsuleTier tier, int cost) async {
    final col = _tierColor(tier);
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _P.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Skip Brewing?',
            style: GoogleFonts.baloo2(
                color: _P.textPri, fontWeight: FontWeight.w900)),
        content: Text('Open ${tier.displayName} capsule now for $cost DNA?',
            style: GoogleFonts.baloo2(color: _P.textSec)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.baloo2(
                    color: _P.textSec, fontWeight: FontWeight.w800)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: col,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Use $cost DNA',
                style: GoogleFonts.baloo2(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Reward generation ──────────────────────────────────────────────────────

  List<CapsuleReward> _generateRewards(CapsuleTier tier) {
    final rewards = <CapsuleReward>[
      CapsuleReward(type: CapsuleRewardType.coins, amount: _coinAmount(tier)),
      CapsuleReward(type: CapsuleRewardType.dna, amount: _dnaAmount(tier)),
    ];
    final roll = _rng.nextDouble();
    bool addPiece = false;
    switch (tier) {
      case CapsuleTier.common:    addPiece = roll < 0.35; break;
      case CapsuleTier.rare:      addPiece = roll < 0.60; break;
      case CapsuleTier.epic:      addPiece = roll < 0.85; break;
      case CapsuleTier.legendary: addPiece = true; break;
      case CapsuleTier.mystery:   addPiece = true; break;
    }
    if (addPiece) rewards.add(_skinReward(tier));
    if ((tier == CapsuleTier.legendary || tier == CapsuleTier.mystery) &&
        _rng.nextDouble() < 0.50) {
      rewards.add(_skinReward(tier));
    }
    return rewards;
  }

  CapsuleReward _skinReward(CapsuleTier tier) {
    final skins = _registry.skins;
    if (skins.isEmpty) {
      return CapsuleReward(type: CapsuleRewardType.coins, amount: 50);
    }
    final incomplete =
        skins.where((s) => s.evolutionLevel != SkinEvolutionLevel.l3).toList();
    final target = incomplete.isNotEmpty
        ? incomplete[_rng.nextInt(incomplete.length)]
        : skins[_rng.nextInt(skins.length)];

    if (tier == CapsuleTier.legendary) {
      return CapsuleReward(
        type: CapsuleRewardType.fullSkin,
        skinKey: target.key,
        skinName: target.name,
        skinImagePath: target.baseImagePath,
      );
    }
    return CapsuleReward(
      type: CapsuleRewardType.skinPiece,
      skinKey: target.key,
      skinName: target.name,
      skinImagePath: target.baseImagePath,
      pieceIndex: _rng.nextInt(5),
    );
  }

  int _coinAmount(CapsuleTier t) {
    switch (t) {
      case CapsuleTier.common:    return 10 + _rng.nextInt(20);
      case CapsuleTier.rare:      return 30 + _rng.nextInt(40);
      case CapsuleTier.epic:      return 80 + _rng.nextInt(70);
      case CapsuleTier.legendary: return 200 + _rng.nextInt(150);
      case CapsuleTier.mystery:   return 50 + _rng.nextInt(100);
    }
  }

  int _dnaAmount(CapsuleTier t) {
    switch (t) {
      case CapsuleTier.common:    return 5 + _rng.nextInt(10);
      case CapsuleTier.rare:      return 15 + _rng.nextInt(20);
      case CapsuleTier.epic:      return 35 + _rng.nextInt(30);
      case CapsuleTier.legendary: return 80 + _rng.nextInt(60);
      case CapsuleTier.mystery:   return 25 + _rng.nextInt(40);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.baloo2(
              color: _P.textPri, fontWeight: FontWeight.w800)),
      backgroundColor: _P.surface,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Compute carousel height that adapts to available space.
            // Top + bottom fixed content is ~330 px; whatever remains goes
            // to the carousel, with a sane min/max so very tall or very
            // short devices both look right.
            final h = constraints.maxHeight;
            final carouselH = (h - 320).clamp(120.0, 240.0);
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: h),
                child: Column(
                  children: [
                    _header(),
                    const SizedBox(height: 8),
                    _slotsSection(),
                    const SizedBox(height: 6),
                    _earnTip(),
                    _sectionTitle('MYSTERY COLLECTION'),
                    SizedBox(
                      height: carouselH,
                      child: _mysteryCarousel(),
                    ),
                    _mysteryActions(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header() {
    final dna = AuthService.instance.profile?.dna ?? 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 14, 8),
      decoration: const BoxDecoration(
        color: _P.bg2,
        border: Border(
          bottom: BorderSide(color: _P.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: _P.textPri, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            'CAPSULES',
            style: GoogleFonts.baloo2(
              color: _P.textPri,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _P.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _P.border, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bubble_chart, color: _P.gold, size: 16),
                const SizedBox(width: 5),
                Text('$dna',
                    style: GoogleFonts.baloo2(
                        color: _P.textPri,
                        fontSize: 13,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 3 Slot Cards ───────────────────────────────────────────────────────────

  Widget _slotsSection() {
    return LayoutBuilder(
      builder: (_, constraints) {
        final totalW =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
        final cardW = (totalW - 40 - 24) / 3;
        const cardH = 112.0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _slotCard(_inventory.slots[0], cardW, cardH),
              const SizedBox(width: 12),
              _slotCard(_inventory.slots[1], cardW, cardH),
              const SizedBox(width: 12),
              _slotCard(_inventory.slots[2], cardW, cardH),
            ],
          ),
        );
      },
    );
  }

  Widget _slotCard(CapsuleSlot slot, double w, double h) {
    if (slot.isEmpty) return _emptySlot(w, h);
    if (slot.isBrewComplete) return _readySlot(slot, w, h);
    return _brewingSlot(slot, w, h);
  }

  Widget _emptySlot(double w, double h) {
    return SizedBox(
      width: w,
      height: h,
      child: Container(
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _P.border, width: 1.5),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, color: _P.textTer, size: 26),
              const SizedBox(height: 6),
              Text(
                'EMPTY',
                style: GoogleFonts.baloo2(
                  color: _P.textTer,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _brewingSlot(CapsuleSlot slot, double w, double h) {
    final tier = slot.tier!;
    final col = _tierColor(tier);
    final rem = slot.remainingBrewTime;
    final total = tier.brewTime;
    final progress =
        1.0 - (rem.inSeconds / total.inSeconds).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => _openCapsule(slot),
      child: SizedBox(
        width: w,
        height: h,
        child: Container(
          decoration: BoxDecoration(
            color: _P.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: col, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 58,
                height: 58,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3.5,
                      backgroundColor: _P.border,
                      valueColor: AlwaysStoppedAnimation<Color>(col),
                    ),
                    _CapsuleIcon(tier: tier, size: 26),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tier.displayName.toUpperCase(),
                style: GoogleFonts.baloo2(
                    color: col,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1),
              ),
              const SizedBox(height: 2),
              Text(
                _fmtDur(rem),
                style: GoogleFonts.baloo2(
                    color: _P.textPri,
                    fontSize: 12,
                    fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _readySlot(CapsuleSlot slot, double w, double h) {
    final tier = slot.tier!;
    final col = _tierColor(tier);

    return GestureDetector(
      onTap: () => _openCapsule(slot),
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (_, __) {
          final t = _pulseCtrl.value;
          return SizedBox(
            width: w,
            height: h,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    col.withValues(alpha: 0.20 + 0.08 * t),
                    _P.surface,
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: col, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: col.withValues(alpha: 0.35 + 0.20 * t),
                    blurRadius: 16 + 8 * t,
                    spreadRadius: 1 + t,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CapsuleIcon(tier: tier, size: 40),
                  const SizedBox(height: 6),
                  _valueStars(tier),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: col,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'OPEN',
                      style: GoogleFonts.baloo2(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _valueStars(CapsuleTier tier) {
    final v = _tierValue(tier);
    final col = _tierColor(tier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0.5),
          child: Icon(
            Icons.star,
            size: 10,
            color: i < v ? col : _P.border,
          ),
        ),
      ),
    );
  }

  // ── Earn tip ───────────────────────────────────────────────────────────────

  Widget _earnTip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _P.bg2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _P.border, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events, color: _P.gold, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Earn capsules by playing — higher rank & longer survival = better tier!',
                style: GoogleFonts.baloo2(
                    color: _P.textSec,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section title ──────────────────────────────────────────────────────────

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Row(
        children: [
          Text(
            text,
            style: GoogleFonts.baloo2(
                color: _P.textPri,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(height: 1, color: _P.border),
          ),
        ],
      ),
    );
  }

  // ── Mystery Carousel ───────────────────────────────────────────────────────

  Widget _mysteryCarousel() {
    final skins = _registry.skins;
    if (skins.isEmpty) return const SizedBox.shrink();
    return PageView.builder(
      controller: _mysteryCtrl,
      itemCount: skins.length,
      onPageChanged: (i) => setState(() => _mysteryIdx = i),
      itemBuilder: (_, i) {
        final ms = skins[i];
        final selected = i == _mysteryIdx;
        return Center(child: _mysteryCard(ms, selected));
      },
    );
  }

  Widget _mysteryCard(MysterySkin ms, bool selected) {
    final locked = !ms.isUnlocked;
    final lvlColor = _levelColor(ms.evolutionLevel);
    final ringColor = locked ? _P.border : lvlColor;

    return AnimatedScale(
      scale: selected ? 1.0 : 0.78,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: selected ? 1.0 : 0.55,
        duration: const Duration(milliseconds: 220),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _P.surface,
              border: Border.all(
                color: ringColor,
                width: selected ? 4 : 2,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: ringColor.withValues(alpha: 0.45),
                        blurRadius: 26,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColorFiltered(
                      colorFilter: locked
                          ? const ColorFilter.matrix([
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0,      0,      0,      1, 0,
                            ])
                          : const ColorFilter.mode(
                              Colors.transparent, BlendMode.multiply),
                      child: Image.asset(
                        ms.baseImagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: _P.bg2,
                          child: const Icon(Icons.auto_awesome,
                              color: _P.accent, size: 44),
                        ),
                      ),
                    ),
                    if (locked)
                      Container(
                        color: Colors.black.withValues(alpha: 0.55),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock,
                                  color: _P.textPri, size: 34),
                              const SizedBox(height: 4),
                              Text('${ms.piecesOwned}/5',
                                  style: GoogleFonts.baloo2(
                                      color: _P.textPri,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ),
                    if (!locked &&
                        ms.evolutionLevel != SkinEvolutionLevel.l0)
                      Positioned(
                        left: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: lvlColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ms.evolutionLevel.displayName.toUpperCase(),
                            style: GoogleFonts.baloo2(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Action row under the carousel ──────────────────────────────────────────

  Widget _mysteryActions() {
    final skins = _registry.skins;
    if (skins.isEmpty) return const SizedBox.shrink();
    final ms = skins[_mysteryIdx.clamp(0, skins.length - 1)];
    final locked = !ms.isUnlocked;
    final isEquipped =
        !locked && SkinSettings.instance.skinPath == ms.baseImagePath;
    final nextPieces = ms.piecesForNext;
    final lvlColor = _levelColor(ms.evolutionLevel);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              ms.name,
              style: GoogleFonts.baloo2(
                  color: _P.textPri,
                  fontSize: 16,
                  fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: locked ? _P.bg2 : lvlColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: locked ? _P.border : lvlColor, width: 1),
              ),
              child: Text(
                locked
                    ? 'LOCKED'
                    : ms.evolutionLevel.displayName.toUpperCase(),
                style: GoogleFonts.baloo2(
                    color: locked ? _P.textSec : lvlColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8),
              ),
            ),
          ],
        ),
        if (nextPieces != null) ...[
          const SizedBox(height: 2),
          Text(
            locked
                ? '${ms.piecesOwned}/5 pieces to unlock'
                : '${ms.piecesOwned}/$nextPieces pieces',
            style: GoogleFonts.baloo2(
                color: _P.textSec,
                fontSize: 11,
                fontWeight: FontWeight.w700),
          ),
        ],
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _arrowBtn(
              icon: Icons.chevron_left,
              enabled: _mysteryIdx > 0,
              onTap: () => _mysteryCtrl.previousPage(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
              ),
            ),
            const SizedBox(width: 14),
            _primaryBtn(ms, isEquipped, locked, lvlColor),
            const SizedBox(width: 14),
            _arrowBtn(
              icon: Icons.chevron_right,
              enabled: _mysteryIdx < skins.length - 1,
              onTap: () => _mysteryCtrl.nextPage(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _primaryBtn(
      MysterySkin ms, bool isEquipped, bool locked, Color lvlColor) {
    String label;
    Color color;
    VoidCallback? onTap;

    if (locked && !ms.canEvolve) {
      label = 'LOCKED';
      color = _P.border;
      onTap = null;
    } else if (locked && ms.canEvolve) {
      label = '🔓  UNLOCK';
      color = _P.accent;
      onTap = () {
        setState(() => ms.evolve());
        _save();
      };
    } else if (!locked && ms.canEvolve) {
      label = 'UPGRADE ✦';
      color = lvlColor;
      onTap = () {
        setState(() => ms.evolve());
        _save();
        if (SkinSettings.instance.skinPath == ms.baseImagePath) {
          SkinSettings.instance.setEvolutionLevel(
              ms.evolutionLevel.index,
              altPath: ms.altImagePath);
        }
      };
    } else if (isEquipped) {
      label = '✓  EQUIPPED';
      color = _P.green;
      onTap = null;
    } else {
      label = 'EQUIP';
      color = _P.accent;
      onTap = () async {
        await SkinSettings.instance.selectSkin(
          ms.baseImagePath,
          evolutionLevel: ms.evolutionLevel.index,
          altPath: ms.altImagePath,
        );
        setState(() {});
        _showSnack('${ms.name} equipped!');
      };
    }

    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: disabled ? _P.surface : color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: disabled ? _P.border : color, width: 1.5),
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.baloo2(
              color: disabled ? _P.textSec : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1),
        ),
      ),
    );
  }

  Widget _arrowBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _P.surface,
          shape: BoxShape.circle,
          border: Border.all(
              color: enabled ? _P.borderHi : _P.border, width: 1.5),
        ),
        child: Icon(icon,
            color: enabled ? _P.textPri : _P.textTer, size: 22),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Color _tierColor(CapsuleTier tier) => Color(tier.gradientArgb.first);

  int _tierValue(CapsuleTier t) {
    switch (t) {
      case CapsuleTier.common:    return 1;
      case CapsuleTier.rare:      return 2;
      case CapsuleTier.epic:      return 3;
      case CapsuleTier.mystery:   return 4;
      case CapsuleTier.legendary: return 5;
    }
  }

  Color _levelColor(SkinEvolutionLevel lvl) {
    switch (lvl) {
      case SkinEvolutionLevel.l0: return _P.accent;
      case SkinEvolutionLevel.l1: return _P.green;
      case SkinEvolutionLevel.l2: return const Color(0xFF00E5FF);
      case SkinEvolutionLevel.l3: return _P.gold;
    }
  }

  String _fmtDur(Duration d) {
    if (d.inHours >= 1) {
      final m = d.inMinutes.remainder(60);
      return '${d.inHours}h${m > 0 ? ' ${m}m' : ''}';
    }
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Capsule icon — each tier gets a distinct shape painted on top of its colour.
// ─────────────────────────────────────────────────────────────────────────────

class _CapsuleIcon extends StatelessWidget {
  const _CapsuleIcon({required this.tier, this.size = 32});
  final CapsuleTier tier;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = tier.gradientArgb.map((v) => Color(v)).toList();
    return CustomPaint(
      size: Size.square(size),
      painter: _CapsuleShapePainter(tier: tier, colors: colors),
    );
  }
}

class _CapsuleShapePainter extends CustomPainter {
  _CapsuleShapePainter({required this.tier, required this.colors});
  final CapsuleTier tier;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(Rect.fromCircle(center: c, radius: r));
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.13
      ..color = Colors.white.withValues(alpha: 0.90);

    Path path;
    switch (tier) {
      case CapsuleTier.common:
        path = Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.92));
        break;
      case CapsuleTier.rare:
        path = _polygon(c, r * 0.95, 6, rotation: pi / 6);
        break;
      case CapsuleTier.epic:
        path = _polygon(c, r * 0.95, 4, rotation: pi / 4);
        break;
      case CapsuleTier.legendary:
        path = _star(c, r * 0.95, r * 0.42, 5);
        break;
      case CapsuleTier.mystery:
        path = _star(c, r * 0.95, r * 0.55, 8);
        break;
    }

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);

    final tp = TextPainter(
      text: TextSpan(
        text: _glyph(tier),
        style: TextStyle(
          color: Colors.white,
          fontSize: r * 0.9,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  String _glyph(CapsuleTier t) {
    switch (t) {
      case CapsuleTier.common:    return 'C';
      case CapsuleTier.rare:      return 'R';
      case CapsuleTier.epic:      return 'E';
      case CapsuleTier.legendary: return 'L';
      case CapsuleTier.mystery:   return '?';
    }
  }

  Path _polygon(Offset c, double r, int sides, {double rotation = 0}) {
    final path = Path();
    for (int i = 0; i < sides; i++) {
      final a = rotation - pi / 2 + (i * 2 * pi / sides);
      final p = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  Path _star(Offset c, double outerR, double innerR, int points) {
    final path = Path();
    final step = pi / points;
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? outerR : innerR;
      final a = -pi / 2 + i * step;
      final p = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _CapsuleShapePainter old) =>
      old.tier != tier || old.colors != colors;
}
