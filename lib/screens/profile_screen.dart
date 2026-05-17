import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'dart:async';

import '../models/boost.dart';
import '../models/match_history_entry.dart';
import '../models/player_stats.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _tab = 0;

  // Tab data caches
  PlayerStats? _stats;
  List<MatchHistoryEntry>? _history;
  List<Map<String, dynamic>>? _inventory;
  List<Map<String, dynamic>>? _achievements;

  // Boost state
  List<BoostDefinition>? _boostStore;
  List<PlayerBoost>? _ownedBoosts;
  bool _loadingBoosts = false;
  String? _boostBusyId; // id of an in-flight buy/activate
  Timer? _countdownTimer; // ticks once a second to refresh the countdown UI

  bool _loadingStats = false;
  bool _loadingHistory = false;
  bool _loadingInventory = false;
  bool _loadingAchievements = false;

  static final _fmt = NumberFormat.decimalPattern('en_US');

  @override
  void initState() {
    super.initState();
    _loadAll();
    AuthService.instance.refreshActiveBoosts();
    // 1Hz tick to update the countdown text without rebuilding the whole
    // screen.
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _loadStats();
    _loadHistory();
    _loadInventory();
    _loadAchievements();
    _loadBoosts();
  }

  Future<void> _loadBoosts() async {
    setState(() => _loadingBoosts = true);
    try {
      final defs = await ProfileService.instance.listBoostDefinitions();
      final owned = await ProfileService.instance.listOwnedBoosts();
      if (!mounted) return;
      setState(() {
        _boostStore = defs;
        _ownedBoosts = owned;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _boostStore = null;
          _ownedBoosts = null;
        });
      }
    }
    if (mounted) setState(() => _loadingBoosts = false);
  }

  Future<void> _buyBoost(BoostDefinition def) async {
    if (_boostBusyId != null) return;
    setState(() => _boostBusyId = def.id);
    try {
      await ProfileService.instance.buyBoost(def.key);
      await AuthService.instance.refreshProfile();
      await _loadBoosts();
    } catch (e) {
      _toast(_humanError(e));
    }
    if (mounted) setState(() => _boostBusyId = null);
  }

  Future<void> _activateBoost(PlayerBoost pb) async {
    if (_boostBusyId != null) return;
    setState(() => _boostBusyId = pb.id);
    try {
      await ProfileService.instance.activateBoost(pb.id);
      await AuthService.instance.refreshActiveBoosts();
      await _loadBoosts();
    } catch (e) {
      _toast(_humanError(e));
    }
    if (mounted) setState(() => _boostBusyId = null);
  }

  String _humanError(Object e) {
    final s = e.toString();
    if (s.contains('Not enough Coins')) return 'Not enough Coins.';
    if (s.contains('Not enough DNA')) return 'Not enough DNA.';
    if (s.contains('already active')) return 'A boost of this type is already active.';
    return s.replaceAll('Exception: ', '').replaceAll('PostgrestException: ', '');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF1B1247),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      _stats = await ProfileService.instance.fetchStats();
    } catch (_) {
      _stats = null;
    }
    if (mounted) setState(() => _loadingStats = false);
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      _history = await ProfileService.instance.fetchMatchHistory();
    } catch (_) {
      _history = null;
    }
    if (mounted) setState(() => _loadingHistory = false);
  }

  Future<void> _loadInventory() async {
    setState(() => _loadingInventory = true);
    try {
      _inventory = await ProfileService.instance.fetchInventory();
    } catch (_) {
      _inventory = null;
    }
    if (mounted) setState(() => _loadingInventory = false);
  }

  Future<void> _loadAchievements() async {
    setState(() => _loadingAchievements = true);
    try {
      _achievements = await ProfileService.instance.fetchAchievements();
    } catch (_) {
      _achievements = null;
    }
    if (mounted) setState(() => _loadingAchievements = false);
  }

  Future<void> _logout() async {
    await AuthService.instance.signOut();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E2A),
      body: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: AuthService.instance,
          builder: (context, _) {
            final profile = AuthService.instance.profile;
            return Stack(
              children: [
                _backgroundGradient(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  child: Column(
                    children: [
                      _topBar(),
                      const SizedBox(height: 8),
                      _headerCard(profile),
                      const SizedBox(height: 10),
                      _tabBar(),
                      const SizedBox(height: 8),
                      Expanded(child: _tabContent(profile)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _backgroundGradient() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0A0E2A),
              const Color(0xFF1B1247),
              const Color(0xFF0E2147),
              const Color(0xFF0A1E3A),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -80,
              top: -60,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFFA63CFF).withValues(alpha: 0.5),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            Positioned(
              right: -100,
              bottom: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF00C8E0).withValues(alpha: 0.45),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        _circleAction(Icons.arrow_back, () => Navigator.of(context).pop()),
        const SizedBox(width: 12),
        Text(
          'PROFILE',
          style: GoogleFonts.baloo2(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout, size: 16, color: Color(0xFFFF4D5E)),
          label: Text(
            'LOGOUT',
            style: GoogleFonts.baloo2(
              color: const Color(0xFFFF4D5E),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _circleAction(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFA63CFF), Color(0xFF1E9BFF)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFA63CFF).withValues(alpha: 0.4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _headerCard(Profile? profile) {
    return _glassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          _avatar(profile),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.displayName ?? '—',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.baloo2(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  profile?.email ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.baloo2(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                _xpBar(profile),
                if (AuthService.instance.activeBoosts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _activeBoostStrip(),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _currencyPill(
            icon: Icons.bubble_chart,
            value: profile?.dna ?? 0,
            color: const Color(0xFFFFD60A),
          ),
          const SizedBox(width: 6),
          _currencyPill(
            icon: Icons.monetization_on,
            value: profile?.coins ?? 0,
            color: const Color(0xFF34C924),
          ),
        ],
      ),
    );
  }

  Widget _activeBoostStrip() {
    final boosts = AuthService.instance.activeBoosts;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final b in boosts) _activeBoostBadge(b),
      ],
    );
  }

  Widget _activeBoostBadge(PlayerBoost b) {
    final color = b.isMass
        ? const Color(0xFFFF6A00)
        : const Color(0xFF00C8E0);
    final icon = b.isMass ? Icons.fitness_center : Icons.bolt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          color.withValues(alpha: 0.30),
          color.withValues(alpha: 0.10),
        ]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            '${b.multiplier.toStringAsFixed(b.multiplier % 1 == 0 ? 0 : 1)}× ${b.isMass ? 'MASS' : 'XP'}',
            style: GoogleFonts.baloo2(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _formatCountdown(b.remaining),
            style: GoogleFonts.baloo2(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCountdown(Duration d) {
    if (d.inSeconds <= 0) return '00:00';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _avatar(Profile? profile) {
    final level = profile?.level ?? 1;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFA63CFF), Color(0xFF1E9BFF)],
            ),
            border: Border.all(color: Colors.white24, width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFA63CFF).withValues(alpha: 0.5),
                blurRadius: 18,
              ),
            ],
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 32),
        ),
        Positioned(
          right: -4,
          bottom: -4,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFC107), Color(0xFFFF6A00)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF0A0E2A), width: 2),
            ),
            child: Text(
              'LV $level',
              style: GoogleFonts.baloo2(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _xpBar(Profile? profile) {
    final progress = profile?.xpProgress ?? 0.0;
    final xp = profile?.xp ?? 0;
    final need = profile?.xpForNextLevel ?? 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text('XP',
                style: GoogleFonts.baloo2(
                    color: Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
            const Spacer(),
            Text(
              '${_fmt.format(xp)} / ${_fmt.format(need)}',
              style: GoogleFonts.baloo2(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Container(
                height: 8,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 8,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Color(0xFFA63CFF),
                      Color(0xFF1E9BFF),
                      Color(0xFF00C8E0),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _currencyPill({
    required IconData icon,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Text(
            _fmt.format(value),
            style: GoogleFonts.baloo2(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- tabs
  Widget _tabBar() {
    const labels = ['Overview', 'Stats', 'Boosts', 'Inventory', 'Achievements', 'History'];
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    gradient: _tab == i
                        ? const LinearGradient(colors: [
                            Color(0xFFA63CFF),
                            Color(0xFF1E9BFF),
                          ])
                        : null,
                    color: _tab == i ? null : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _tab == i
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.10),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i].toUpperCase(),
                    style: GoogleFonts.baloo2(
                      color: _tab == i ? Colors.white : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabContent(Profile? profile) {
    switch (_tab) {
      case 0:
        return _overviewTab(profile);
      case 1:
        return _statsTab();
      case 2:
        return _boostsTab();
      case 3:
        return _inventoryTab();
      case 4:
        return _achievementsTab();
      case 5:
        return _historyTab();
    }
    return const SizedBox.shrink();
  }

  Widget _overviewTab(Profile? profile) {
    final s = _stats;
    return SingleChildScrollView(
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.6,
            children: [
              _statTile('Matches', _fmt.format(s?.matchesPlayed ?? 0),
                  Icons.flag, const Color(0xFF1E9BFF)),
              _statTile('Best Score', _fmt.format(s?.bestScore ?? 0),
                  Icons.emoji_events, const Color(0xFFFFC107)),
              _statTile('Kills', _fmt.format(s?.totalKills ?? 0),
                  Icons.bolt, const Color(0xFFFF6A00)),
              _statTile('Deaths', _fmt.format(s?.totalDeaths ?? 0),
                  Icons.heart_broken, const Color(0xFFFF4D5E)),
            ],
          ),
          const SizedBox(height: 10),
          _glassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('SUMMARY'),
                const SizedBox(height: 8),
                _kv('Level', '${profile?.level ?? 1}'),
                _kv('XP', _fmt.format(profile?.xp ?? 0)),
                _kv('Coins', _fmt.format(profile?.coins ?? 0)),
                _kv('DNA', _fmt.format(profile?.dna ?? 0)),
                _kv('Wins', _fmt.format(s?.wins ?? 0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsTab() {
    if (_loadingStats) return _loading();
    final s = _stats;
    if (s == null) return _empty('No stats yet — play a match to populate this.');
    return SingleChildScrollView(
      child: _glassCard(
        child: Column(
          children: [
            _sectionTitle('PLAYER STATS'),
            const SizedBox(height: 8),
            _kv('Matches played', _fmt.format(s.matchesPlayed)),
            _kv('Wins', _fmt.format(s.wins)),
            _kv('Best score', _fmt.format(s.bestScore)),
            _kv('Total score', _fmt.format(s.totalScore)),
            _kv('Total mass collected', _fmt.format(s.totalMassCollected)),
            _kv('Total kills/eats', _fmt.format(s.totalKills)),
            _kv('Total deaths', _fmt.format(s.totalDeaths)),
            _kv('Total playtime', _formatTime(s.totalSurvivalSeconds)),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- boosts tab
  Widget _boostsTab() {
    if (_loadingBoosts && _boostStore == null) return _loading();
    final store = _boostStore ?? const <BoostDefinition>[];
    final owned = (_ownedBoosts ?? const <PlayerBoost>[])
        .where((b) => b.status == 'owned')
        .toList();
    final active = AuthService.instance.activeBoosts;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // -------- active ----------------------------------------------
          if (active.isNotEmpty) ...[
            _sectionTitle('ACTIVE'),
            const SizedBox(height: 8),
            for (final b in active) _activeBoostCard(b),
            const SizedBox(height: 14),
          ],

          // -------- owned -----------------------------------------------
          _sectionTitle('OWNED'),
          const SizedBox(height: 8),
          if (owned.isEmpty)
            _emptyInline('No owned boosts yet. Buy one below.')
          else
            for (final b in owned) _ownedBoostCard(b),
          const SizedBox(height: 14),

          // -------- store ----------------------------------------------
          _sectionTitle('STORE'),
          const SizedBox(height: 8),
          if (store.isEmpty)
            _emptyInline('No boosts available right now.')
          else
            for (final def in store) _storeBoostCard(def),
        ],
      ),
    );
  }

  Widget _activeBoostCard(PlayerBoost b) {
    final color = b.isMass
        ? const Color(0xFFFF6A00)
        : const Color(0xFF00C8E0);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          color.withValues(alpha: 0.22),
          color.withValues(alpha: 0.06),
        ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        children: [
          _boostIcon(b.type, color, big: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_mult(b.multiplier)}× ${b.isMass ? 'Mass Boost' : 'XP Boost'}',
                  style: GoogleFonts.baloo2(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Ends in ${_formatCountdown(b.remaining)}',
                  style: GoogleFonts.baloo2(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'ACTIVE',
              style: GoogleFonts.baloo2(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ownedBoostCard(PlayerBoost b) {
    final color = b.isMass
        ? const Color(0xFFFF6A00)
        : const Color(0xFF00C8E0);
    final hasSameTypeActive = AuthService.instance.activeBoosts
        .any((a) => a.type == b.type);
    final busy = _boostBusyId == b.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.10), width: 1),
      ),
      child: Row(
        children: [
          _boostIcon(b.type, color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_mult(b.multiplier)}× ${b.isMass ? 'Mass Boost' : 'XP Boost'}',
                  style: GoogleFonts.baloo2(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Duration: ${_durationLabel(b.durationSeconds)}',
                  style: GoogleFonts.baloo2(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _smallButton(
            label: hasSameTypeActive ? 'LOCKED' : 'ACTIVATE',
            enabled: !hasSameTypeActive && !busy,
            busy: busy,
            color: color,
            onTap: () => _activateBoost(b),
          ),
        ],
      ),
    );
  }

  Widget _storeBoostCard(BoostDefinition def) {
    final color = def.isMass
        ? const Color(0xFFFF6A00)
        : const Color(0xFF00C8E0);
    final coins = AuthService.instance.profile?.coins ?? 0;
    final dna = AuthService.instance.profile?.dna ?? 0;
    final affordable = def.priceCoins > 0
        ? coins >= def.priceCoins
        : dna >= def.priceDna;
    final busy = _boostBusyId == def.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.10), width: 1),
      ),
      child: Row(
        children: [
          _boostIcon(def.type, color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_mult(def.multiplier)}× ${def.isMass ? 'Mass Boost' : 'XP Boost'}',
                  style: GoogleFonts.baloo2(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  _durationLabel(def.durationSeconds),
                  style: GoogleFonts.baloo2(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _pricePill(def),
          const SizedBox(width: 8),
          _smallButton(
            label: 'BUY',
            enabled: affordable && !busy,
            busy: busy,
            color: color,
            onTap: () => _buyBoost(def),
          ),
        ],
      ),
    );
  }

  Widget _pricePill(BoostDefinition def) {
    final isDna = def.priceDna > 0;
    final value = isDna ? def.priceDna : def.priceCoins;
    final color = isDna ? const Color(0xFFFFD60A) : const Color(0xFF34C924);
    final icon = isDna ? Icons.bubble_chart : Icons.monetization_on;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            _fmt.format(value),
            style: GoogleFonts.baloo2(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _boostIcon(String type, Color color, {bool big = false}) {
    final size = big ? 40.0 : 32.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          color.withValues(alpha: 0.9),
          color.withValues(alpha: 0.55),
        ]),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 12,
          ),
        ],
      ),
      child: Icon(
        type == 'mass' ? Icons.fitness_center : Icons.bolt,
        color: Colors.white,
        size: big ? 22 : 18,
      ),
    );
  }

  Widget _smallButton({
    required String label,
    required bool enabled,
    required bool busy,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(colors: [
                  color,
                  color.withValues(alpha: 0.7),
                ])
              : const LinearGradient(
                  colors: [Color(0xFF555575), Color(0xFF3F3F5C)]),
          borderRadius: BorderRadius.circular(10),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: busy
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: GoogleFonts.baloo2(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }

  Widget _emptyInline(String msg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        child: Text(
          msg,
          style: GoogleFonts.baloo2(
            color: Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  static String _mult(double m) =>
      m % 1 == 0 ? m.toStringAsFixed(0) : m.toStringAsFixed(1);

  static String _durationLabel(int seconds) {
    if (seconds >= 3600) {
      final h = seconds / 3600;
      return h == h.toInt() ? '${h.toInt()} hour${h == 1 ? '' : 's'}' : '${h.toStringAsFixed(1)}h';
    }
    final m = (seconds / 60).round();
    return '$m min';
  }

  Widget _inventoryTab() {
    if (_loadingInventory) return _loading();
    final items = _inventory;
    if (items == null || items.isEmpty) {
      return _empty('Inventory is empty. Earn or buy items to fill it up.');
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final entry = items[i];
        final raw = entry['inventory_items'];
        final item = raw is Map ? raw.cast<String, dynamic>() : null;
        final name = item?['name'] as String? ?? 'Item';
        final equipped = entry['equipped'] == true;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: equipped
                    ? const Color(0xFF00C8E0)
                    : Colors.white.withValues(alpha: 0.1),
                width: equipped ? 2 : 1),
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield, color: Colors.white70, size: 24),
              const SizedBox(height: 4),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _achievementsTab() {
    if (_loadingAchievements) return _loading();
    final list = _achievements;
    if (list == null || list.isEmpty) {
      return _empty('No achievements yet. Keep playing to unlock them.');
    }
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final entry = list[i];
        final raw = entry['achievements'];
        final ach = raw is Map ? raw.cast<String, dynamic>() : null;
        return _glassCard(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              const Icon(Icons.emoji_events,
                  color: Color(0xFFFFC107), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ach?['name'] as String? ?? 'Achievement',
                      style: GoogleFonts.baloo2(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      ach?['description'] as String? ?? '',
                      style: GoogleFonts.baloo2(
                        color: Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _historyTab() {
    if (_loadingHistory) return _loading();
    final list = _history;
    if (list == null || list.isEmpty) {
      return _empty('No matches played yet. Hit Classic to start.');
    }
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final m = list[i];
        return _glassCard(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [
                    Color(0xFFA63CFF),
                    Color(0xFF1E9BFF),
                  ]),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '#${m.rank}',
                  style: GoogleFonts.baloo2(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Score ${_fmt.format(m.score)} · ${m.kills} kills · ${_formatTime(m.survivalSeconds)}',
                      style: GoogleFonts.baloo2(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '+${m.xpEarned} XP · +${m.coinsEarned} coins · +${m.dnaEarned} DNA',
                      style: GoogleFonts.baloo2(
                        color: Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                DateFormat('MMM d, HH:mm').format(m.createdAt.toLocal()),
                style: GoogleFonts.baloo2(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------- helpers
  Widget _glassCard({required Widget child, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.10), width: 1),
          ),
          padding:
              padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: child,
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: GoogleFonts.baloo2(
                      color: Colors.white60,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    )),
                Text(value,
                    style: GoogleFonts.baloo2(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String label) => Text(
        label,
        style: GoogleFonts.baloo2(
          color: const Color(0xFF00C8E0),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
        ),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(k,
                  style: GoogleFonts.baloo2(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  )),
            ),
            Text(v,
                style: GoogleFonts.baloo2(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                )),
          ],
        ),
      );

  Widget _loading() => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E9BFF)),
        ),
      );

  Widget _empty(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined,
                  color: Colors.white.withValues(alpha: 0.4), size: 36),
              const SizedBox(height: 8),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  color: Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}
