import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/boost.dart';
import '../models/profile.dart';
import 'profile_service.dart';

/// Holds the current Supabase session + the player's profile and notifies
/// listeners when either changes. Use [AuthService.instance] everywhere; do
/// not construct new instances.
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  final SupabaseClient _client = Supabase.instance.client;
  StreamSubscription<AuthState>? _sub;

  Session? _session;
  Session? get session => _session;
  User? get user => _session?.user;
  bool get isLoggedIn => _session != null;

  Profile? _profile;
  Profile? get profile => _profile;

  bool _loadingProfile = false;
  bool get isLoadingProfile => _loadingProfile;

  // Active boost cache. Refreshed after login, buy, activate, match submit
  // and whenever the profile screen or game screen opens.
  List<PlayerBoost> _activeBoosts = [];
  List<PlayerBoost> get activeBoosts => _activeBoosts;

  PlayerBoost? get activeMassBoost {
    for (final b in _activeBoosts) {
      if (b.isMass && b.isActive) return b;
    }
    return null;
  }

  PlayerBoost? get activeXpBoost {
    for (final b in _activeBoosts) {
      if (b.isXp && b.isActive) return b;
    }
    return null;
  }

  /// 1.0 when no Mass Boost is live, otherwise the boost's multiplier
  /// (e.g. 2.0 or 3.0). Used by the game engine to scale starting mass.
  double get activeMassMultiplier => activeMassBoost?.multiplier ?? 1.0;

  /// Wire up the auth state listener and hydrate the existing session (if the
  /// user opened the app while already signed in).
  void bootstrap() {
    _session = _client.auth.currentSession;
    _sub ??= _client.auth.onAuthStateChange.listen(_onAuthChange);
    if (_session != null) {
      _refreshProfile();
      refreshActiveBoosts();
    }
  }

  void _onAuthChange(AuthState state) {
    _session = state.session;
    notifyListeners();
    if (state.session != null) {
      _refreshProfile();
      refreshActiveBoosts();
    } else {
      _profile = null;
      _activeBoosts = [];
      notifyListeners();
    }
  }

  /// Pull the server-validated active-boost list. The RPC auto-expires
  /// stale rows, so this also keeps `_activeBoosts` honest if the player
  /// leaves the app open past an expiration.
  Future<void> refreshActiveBoosts() async {
    if (_session == null) {
      if (_activeBoosts.isNotEmpty) {
        _activeBoosts = [];
        notifyListeners();
      }
      return;
    }
    try {
      _activeBoosts = await ProfileService.instance.getActiveBoosts();
    } catch (e) {
      debugPrint('refreshActiveBoosts failed: $e');
    }
    notifyListeners();
  }

  /// Step 1 of email login: send the OTP code to the address. Supabase emails
  /// both a magic link and a 6-digit code with its default template; we use
  /// the code (deep-link-free flow works everywhere).
  Future<void> sendLoginCode(String email) async {
    await _client.auth.signInWithOtp(
      email: email.trim(),
      shouldCreateUser: true,
    );
  }

  /// Step 2: verify the 6-digit code typed by the user.
  Future<void> verifyLoginCode({
    required String email,
    required String code,
  }) async {
    final res = await _client.auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      type: OtpType.email,
    );
    _session = res.session;
    notifyListeners();
    await _refreshProfile();
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    _session = null;
    _profile = null;
    notifyListeners();
  }

  Future<void> _refreshProfile() async {
    final u = _client.auth.currentUser;
    if (u == null) return;
    _loadingProfile = true;
    notifyListeners();
    try {
      _profile = await ProfileService.instance.fetchOrCreateProfile(u);
    } catch (e) {
      debugPrint('Failed to fetch profile: $e');
      _profile = null;
    } finally {
      _loadingProfile = false;
      notifyListeners();
    }
  }

  /// Re-fetch the profile from Supabase. Call this after submit_match_result
  /// returns updated values so listeners refresh.
  Future<void> refreshProfile() => _refreshProfile();

  /// Replace the in-memory profile (used after submit_match_result returns
  /// fresh totals — avoids a round-trip).
  void applyProfile(Profile p) {
    _profile = p;
    notifyListeners();
  }
}
