import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/capsule.dart';

// Professional palette — kept in sync with capsule_screen.dart
class _P {
  static const bg       = Color(0xFF141A33);
  static const surface  = Color(0xFF1B2245);
  static const surface2 = Color(0xFF252D55);
  static const border   = Color(0xFF323A66);
  static const textPri  = Color(0xFFFFFFFF);
  static const textSec  = Color(0xFFC1C8E4);
  static const gold     = Color(0xFFFFD700);
  static const purple   = Color(0xFFA63CFF);
  static const cyan     = Color(0xFF22E5FF);
}

/// Animated popup that reveals one or more capsule rewards.
class CapsuleRewardPopup extends StatefulWidget {
  const CapsuleRewardPopup({
    super.key,
    required this.tier,
    required this.rewards,
  });

  final CapsuleTier tier;
  final List<CapsuleReward> rewards;

  static Future<void> show(
    BuildContext context, {
    required CapsuleTier tier,
    required List<CapsuleReward> rewards,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (_) => CapsuleRewardPopup(tier: tier, rewards: rewards),
    );
  }

  @override
  State<CapsuleRewardPopup> createState() => _CapsuleRewardPopupState();
}

class _CapsuleRewardPopupState extends State<CapsuleRewardPopup>
    with TickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late AnimationController _shineCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _scaleAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _opacityAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: const Interval(0, 0.4)),
    );

    _scaleCtrl.forward();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _shineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        widget.tier.gradientArgb.map((v) => Color(v)).toList();

    return AnimatedBuilder(
      animation: Listenable.merge([_scaleCtrl, _shineCtrl]),
      builder: (_, __) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: FadeTransition(
            opacity: _opacityAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: _buildCard(colors),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(List<Color> tierColors) {
    return Container(
      width: 340,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tierColors.first, width: 2),
        boxShadow: [
          BoxShadow(
            color: tierColors.first.withValues(alpha: 0.55),
            blurRadius: 28,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tierBadge(tierColors),
          const SizedBox(height: 16),
          _shineGraphic(tierColors),
          const SizedBox(height: 14),
          Text(
            'YOU EARNED',
            style: GoogleFonts.baloo2(
              color: _P.textSec,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 12),
          _rewardsGrid(),
          const SizedBox(height: 20),
          _awesomeButton(tierColors),
        ],
      ),
    );
  }

  Widget _tierBadge(List<Color> colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.5),
            blurRadius: 12,
          ),
        ],
      ),
      child: Text(
        widget.tier.displayName.toUpperCase(),
        style: GoogleFonts.baloo2(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shineGraphic(List<Color> colors) {
    final shine = _shineCtrl.value;
    return SizedBox(
      width: 86,
      height: 86,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: shine * 2 * pi,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    colors.first.withValues(alpha: 0),
                    colors.first.withValues(alpha: 0.55),
                    colors.last.withValues(alpha: 0.55),
                    colors.first.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.55),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Icon(Icons.workspace_premium,
                color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _rewardsGrid() {
    final rewards = widget.rewards;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: rewards
          .map((r) => _rewardCell(r))
          .toList(growable: false),
    );
  }

  Widget _rewardCell(CapsuleReward r) {
    final accent = _accentColor(r);
    return Container(
      width: 94,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: _P.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.25),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: _cellIcon(r, accent),
          ),
          const SizedBox(height: 10),
          Text(
            _cellTitle(r),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.baloo2(
                color: _P.textPri,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                height: 1),
          ),
          const SizedBox(height: 2),
          Text(
            _cellSub(r),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.baloo2(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                height: 1),
          ),
        ],
      ),
    );
  }

  Widget _cellIcon(CapsuleReward r, Color accent) {
    switch (r.type) {
      case CapsuleRewardType.coins:
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              _P.gold.withValues(alpha: 0.45),
              _P.gold.withValues(alpha: 0.05),
            ]),
          ),
          child: const Icon(Icons.monetization_on,
              color: _P.gold, size: 34),
        );
      case CapsuleRewardType.dna:
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              _P.purple.withValues(alpha: 0.45),
              _P.purple.withValues(alpha: 0.05),
            ]),
          ),
          child: const Icon(Icons.bubble_chart,
              color: _P.purple, size: 34),
        );
      case CapsuleRewardType.skinPiece:
      case CapsuleRewardType.fullSkin:
        final path = r.skinImagePath;
        if (path == null) {
          return Icon(
            r.type == CapsuleRewardType.fullSkin
                ? Icons.star
                : Icons.auto_awesome,
            color: accent,
            size: 34,
          );
        }
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: accent, width: 2),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.4),
                blurRadius: 6,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              path,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome,
                  color: accent, size: 30),
            ),
          ),
        );
    }
  }

  Widget _awesomeButton(List<Color> tierColors) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: tierColors,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: tierColors.first.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'AWESOME!',
            style: GoogleFonts.baloo2(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _accentColor(CapsuleReward r) {
    switch (r.type) {
      case CapsuleRewardType.coins:     return _P.gold;
      case CapsuleRewardType.dna:       return _P.purple;
      case CapsuleRewardType.skinPiece: return _P.cyan;
      case CapsuleRewardType.fullSkin:  return _P.gold;
    }
  }

  String _cellTitle(CapsuleReward r) {
    switch (r.type) {
      case CapsuleRewardType.coins:    return '+${r.amount}';
      case CapsuleRewardType.dna:      return '+${r.amount}';
      case CapsuleRewardType.skinPiece: return r.skinName ?? 'Piece';
      case CapsuleRewardType.fullSkin:  return r.skinName ?? 'Skin';
    }
  }

  String _cellSub(CapsuleReward r) {
    switch (r.type) {
      case CapsuleRewardType.coins:     return 'COINS';
      case CapsuleRewardType.dna:       return 'DNA';
      case CapsuleRewardType.skinPiece: return 'PIECE +1';
      case CapsuleRewardType.fullSkin:  return 'FULL SKIN';
    }
  }
}
