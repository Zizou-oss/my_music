import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'supabase_service.dart';

class AuthService {
  bool get isEnabled => SupabaseService.isEnabled;

  User? get currentUser => SupabaseService.currentUser;

  Stream<AuthState> get authStateChanges {
    if (!isEnabled) {
      return Stream<AuthState>.empty();
    }
    return SupabaseService.client.auth.onAuthStateChange;
  }

  Future<String?> checkSignupAvailability({
    required String email,
    String? fullName,
  }) async {
    if (!isEnabled) return null;
    final trimmedEmail = email.trim();
    final trimmedName = fullName?.trim();
    if (trimmedEmail.isEmpty && (trimmedName == null || trimmedName.isEmpty)) {
      return null;
    }

    try {
      final rows = await SupabaseService.client
          .rpc(
            'check_signup_availability',
            params: <String, dynamic>{
              'p_email': trimmedEmail,
              'p_full_name': trimmedName ?? '',
            },
          )
          .timeout(const Duration(seconds: 5));

      final row = (rows as List<dynamic>).cast<Map<String, dynamic>>().first;
      final emailTaken = row['email_taken'] == true;
      final nameTaken = row['full_name_taken'] == true;
      if (emailTaken) {
        return 'Cet email est déjà utilisé.';
      }
      if (trimmedName != null && trimmedName.isNotEmpty && nameTaken) {
        return 'Ce nom est déjà utilisé.';
      }
      return null;
    } catch (e) {
      debugPrint('AuthService.checkSignupAvailability failed: $e');
      return null;
    }
  }

  Future<String?> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    if (!isEnabled) return 'Supabase non configure';
    try {
      await SupabaseService.client.auth.signUp(
        email: email.trim(),
        password: password.trim(),
        emailRedirectTo: SupabaseConfig.emailRedirectTo,
        data: (fullName == null || fullName.trim().isEmpty)
            ? null
            : {'full_name': fullName.trim()},
      );
      return null;
    } on AuthException catch (e) {
      return _friendlyAuthMessage(e.message,
          fallback: 'Inscription impossible');
    } catch (_) {
      return 'Inscription impossible';
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    if (!isEnabled) return 'Supabase non configure';
    try {
      await SupabaseService.client.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return null;
    } on AuthException catch (e) {
      return _friendlyAuthMessage(e.message, fallback: 'Connexion impossible');
    } catch (_) {
      return 'Connexion impossible';
    }
  }

  Future<String?> signInWithGoogle() async {
    if (!isEnabled) return 'Supabase non configure';
    try {
      final launchMode = Platform.isAndroid
          ? LaunchMode.inAppBrowserView
          : LaunchMode.inAppWebView;
      final opened = await SupabaseService.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: SupabaseConfig.emailRedirectTo,
        authScreenLaunchMode: launchMode,
      );
      if (!opened) {
        return 'Impossible d ouvrir Google';
      }
      return null;
    } on AuthException catch (e) {
      return _friendlyAuthMessage(
        e.message,
        fallback: 'Connexion Google impossible',
      );
    } catch (_) {
      return 'Connexion Google impossible';
    }
  }

  Future<void> signOut() async {
    if (!isEnabled) return;
    await SupabaseService.client.auth.signOut(scope: SignOutScope.local);
    try {
      await SupabaseService.client.auth.signOut();
    } catch (_) {
      // Ignore network/global sign-out errors.
    }
  }

  String _friendlyAuthMessage(
    String raw, {
    required String fallback,
  }) {
    final msg = raw.toLowerCase();
    if (msg.contains('rate limit') || msg.contains('too many requests')) {
      return 'Trop de tentatives. Patiente puis r\u00e9essaie.';
    }
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials') ||
        msg.contains('email or password')) {
      return 'Email ou mot de passe incorrect.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Confirme ton email puis r\u00e9essaie.';
    }
    if (msg.contains('already registered') ||
        msg.contains('user already registered') ||
        msg.contains('already been registered')) {
      return 'Un compte existe déjà avec cet email.';
    }
    if (msg.contains('network') ||
        msg.contains('failed to fetch') ||
        msg.contains('timeout') ||
        msg.contains('socket')) {
      return 'V\u00e9rifie ta connexion Internet puis r\u00e9essaie.';
    }
    if (msg.contains('jwt') ||
        msg.contains('permission') ||
        msg.contains('unauthorized') ||
        msg.contains('forbidden')) {
      return 'Session invalide. Reconnecte-toi puis r\u00e9essaie.';
    }
    return fallback;
  }
}
