import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/mystery_skin.dart';
import '../utils/app_colors.dart';

/// Panel that shows a mystery skin's piece progress and evolution level,
/// with an "Evolve" button when enough pieces are collected.
class MysterySkinPanel extends StatelessWidget {
  const MysterySkinPanel({
    super.key,
    required this.skin,
    required this.onEvolve,
    this.isEquipped = false,
    this.onEquip,
  });

  final MysterySkin skin;
  final VoidCallback onEvolve;
  final bool isEquipped;
  final VoidCallback? onEquip;

  @override
  Widget build(BuildContext context) {
    final lvl = skin.evolutionLevel;
    final nextPieces = skin.piecesForNext;
    final piecesOwned = skin.piecesOwned;
    final progress = nextPieces != null
        ? (piecesOwned / nextPieces).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _levelBadge(lvl),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  skin.name,
                  style: GoogleFonts.baloo2(
                    color: AppColors.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onEquip != null)
                _equipButton(isEquipped),
            ],
          ),
          const SizedBox(height: 12),
          _evolutionIndicator(lvl),
          const SizedBox(height: 12),
          if (nextPieces != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pieces',
                  style: GoogleFonts.baloo2(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '$piecesOwned / $nextPieces',
                  style: GoogleFonts.baloo2(
                    color: AppColors.primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.cardBorderColor,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _levelColor(lvl),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (skin.canEvolve)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                  'Evolve → ${_nextLevelName(lvl)}',
                  style: GoogleFonts.baloo2(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _levelColor(lvl),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onEvolve,
              ),
            ),
          if (lvl == SkinEvolutionLevel.l3)
            _maxLevelBadge(),
        ],
      ),
    );
  }

  Widget _levelBadge(SkinEvolutionLevel lvl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _levelColor(lvl).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _levelColor(lvl).withValues(alpha: 0.5)),
      ),
      child: Text(
        lvl.displayName.toUpperCase(),
        style: GoogleFonts.baloo2(
          color: _levelColor(lvl),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _evolutionIndicator(SkinEvolutionLevel lvl) {
    return Row(
      children: SkinEvolutionLevel.values.map((l) {
        final active = l.index <= lvl.index;
        return Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: active
                  ? _levelColor(lvl)
                  : AppColors.cardBorderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _equipButton(bool equipped) {
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: equipped
            ? AppColors.freeGreen.withValues(alpha: 0.15)
            : Colors.transparent,
        foregroundColor: equipped ? AppColors.freeGreen : AppColors.secondaryText,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: equipped ? null : onEquip,
      child: Text(
        equipped ? 'Equipped' : 'Equip',
        style: GoogleFonts.baloo2(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  Widget _maxLevelBadge() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFD60A), Color(0xFFFF8F00)]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            'MAX LEVEL — Alt-face on split',
            style: GoogleFonts.baloo2(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Color _levelColor(SkinEvolutionLevel lvl) {
    switch (lvl) {
      case SkinEvolutionLevel.l0: return AppColors.secondaryText;
      case SkinEvolutionLevel.l1: return const Color(0xFF34C924);
      case SkinEvolutionLevel.l2: return const Color(0xFF00E5FF);
      case SkinEvolutionLevel.l3: return const Color(0xFFFFD60A);
    }
  }

  String _nextLevelName(SkinEvolutionLevel lvl) {
    switch (lvl) {
      case SkinEvolutionLevel.l0: return 'L1 Shimmer';
      case SkinEvolutionLevel.l1: return 'L2 Glow on Split';
      case SkinEvolutionLevel.l2: return 'L3 Alt-Face on Split';
      case SkinEvolutionLevel.l3: return '';
    }
  }
}
