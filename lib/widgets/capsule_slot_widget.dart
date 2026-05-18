import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/capsule.dart';
import '../utils/app_colors.dart';

/// Single capsule slot card shown on the main menu.
/// Tapping opens the CapsuleScreen; when a capsule is brewing it shows a
/// countdown timer.
class CapsuleSlotWidget extends StatefulWidget {
  const CapsuleSlotWidget({
    super.key,
    required this.slot,
    required this.onTap,
  });

  final CapsuleSlot slot;
  final VoidCallback onTap;

  @override
  State<CapsuleSlotWidget> createState() => _CapsuleSlotWidgetState();
}

class _CapsuleSlotWidgetState extends State<CapsuleSlotWidget>
    with SingleTickerProviderStateMixin {
  Timer? _ticker;
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    if (!widget.slot.isEmpty && !widget.slot.isBrewComplete) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(CapsuleSlotWidget old) {
    super.didUpdateWidget(old);
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _shimmerCtrl,
        builder: (_, __) => _buildCard(slot),
      ),
    );
  }

  Widget _buildCard(CapsuleSlot slot) {
    if (slot.isEmpty) return _emptySlot();
    if (slot.isBrewComplete) return _readySlot(slot.tier!);
    return _brewingSlot(slot);
  }

  // ── Empty ──────────────────────────────────────────────────────────────────
  Widget _emptySlot() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.cardBorderColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: const Icon(Icons.add, color: Colors.white38, size: 28),
    );
  }

  // ── Ready to open ──────────────────────────────────────────────────────────
  Widget _readySlot(CapsuleTier tier) {
    final colors = tier.gradientArgb.map((v) => Color(v)).toList();
    final shimmer = _shimmerCtrl.value;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.55),
            blurRadius: 12 + 6 * sin(shimmer * 2 * pi),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.science, color: Colors.white, size: 30),
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.greenAccent.shade700,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '!',
                style: GoogleFonts.baloo2(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Brewing (timer countdown) ──────────────────────────────────────────────
  Widget _brewingSlot(CapsuleSlot slot) {
    final colors = slot.tier!.gradientArgb.map((v) => Color(v)).toList();
    final rem = slot.remainingBrewTime;
    final total = slot.tier!.brewTime;
    final progress = 1.0 - (rem.inSeconds / total.inSeconds).clamp(0.0, 1.0);
    final label = _formatDuration(rem);

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.first.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: colors.first.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation<Color>(colors.first),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.baloo2(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours >= 1) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      return '${h}h${m > 0 ? '${m}m' : ''}';
    }
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m}:${s.toString().padLeft(2, '0')}';
  }
}
