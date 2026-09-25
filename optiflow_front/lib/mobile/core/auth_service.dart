import 'package:supabase_flutter/supabase_flutter.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// AuthService — thin wrapper around Supabase Auth.
/// Supabase is used ONLY for email/password login and session persistence.
/// All data operations go through ApiService → FastAPI.
/// ─────────────────────────────────────────────────────────────────────────────
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final SupabaseClient _client = Supabase.instance.client;

  // ── Getters ─────────────────────────────────────────────────────────────────

  /// Returns true if a valid session is currently active.
  bool get isAuthenticated => _client.auth.currentSession != null;

  /// The current user object (null if not signed in).
  User? get currentUser => _client.auth.currentUser;

  /// The JWT access token to inject into every FastAPI request header.
  String? get accessToken => _client.auth.currentSession?.accessToken;

  /// Display-friendly user name (falls back to email prefix).
  String get displayName {
    final user = currentUser;
    if (user == null) return 'Worker';
    final meta = user.userMetadata;
    if (meta != null && meta['full_name'] != null) {
      return meta['full_name'] as String;
    }
    return user.email?.split('@').first ?? 'Worker';
  }

  // ── Auth Operations ─────────────────────────────────────────────────────────

  /// Sign in with email & password. Throws on failure.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (response.session == null) {
      throw Exception('Sign in failed. Please check your credentials.');
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
