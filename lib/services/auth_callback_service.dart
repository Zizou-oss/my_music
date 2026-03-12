import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

import '../config/supabase_config.dart';
import 'supabase_service.dart';

/// Handles Supabase auth callback deep links (email confirmation + OAuth).
///
/// Why this exists:
/// - `supabase_flutter` relies on `uriLinkStream` for mobile initial links.
/// - If Supabase is initialized after app start, the initial link can be missed.
/// - We capture the initial link ourselves and replay it once Supabase is ready.
class AuthCallbackService {
  AuthCallbackService._();

  static final AuthCallbackService instance = AuthCallbackService._();

  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _sub;
  Uri? _pendingAuthUri;
  bool _started = false;
  final Set<String> _handled = <String>{};
  final StreamController<String> _confirmationController =
      StreamController<String>.broadcast();

  Stream<String> get confirmationStream => _confirmationController.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    if (!kIsWeb) {
      _sub = _appLinks.uriLinkStream.listen(
        (uri) {
          unawaited(_handleUri(uri, source: 'stream'));
        },
        onError: (e) {
          debugPrint('AuthCallbackService: uriLinkStream error: $e');
        },
      );

      // Capture the initial deep link explicitly (reliable for cold start).
      try {
        final uri = await _appLinks.getInitialLink();
        if (uri != null) {
          await _handleUri(uri, source: 'initial');
        }
      } catch (e) {
        debugPrint('AuthCallbackService: getInitialLink failed: $e');
      }
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }

  /// Call this once Supabase is initialized to replay any pending auth link.
  Future<void> onSupabaseReady() async {
    final uri = _pendingAuthUri;
    _pendingAuthUri = null;
    if (uri == null) return;

    await _processAuthUri(uri);
  }

  bool _looksLikeAuthCallback(Uri uri) {
    if (uri.host == 'auth-callback' || uri.path.contains('auth-callback')) {
      return true;
    }
    final url = uri.toString();
    if (url.contains('access_token')) return true;
    if (url.contains('error_description')) return true;
    if (uri.queryParameters.containsKey('code')) return true;
    return false;
  }

  Future<void> _handleUri(Uri uri, {required String source}) async {
    if (!_looksLikeAuthCallback(uri)) return;

    final key = uri.toString();
    if (_handled.contains(key)) return;
    _handled.add(key);

    debugPrint('AuthCallbackService: received ($source) $uri');

    if (!SupabaseConfig.isConfigured) {
      debugPrint('AuthCallbackService: Supabase not configured; ignore');
      return;
    }

    if (!SupabaseService.isEnabled) {
      // Supabase init is still running; replay after init completes.
      _pendingAuthUri = uri;
      return;
    }

    await _processAuthUri(uri);
  }

  Future<void> _processAuthUri(Uri uri) async {
    try {
      final response = await SupabaseService.client.auth.getSessionFromUrl(uri);
      debugPrint('AuthCallbackService: session updated from callback');
      final redirectType = response.redirectType;
      final message = redirectType == 'signup'
          ? 'Email confirmé. Connexion réussie.'
          : 'Connexion réussie.';
      _confirmationController.add(message);
      return;
    } catch (e) {
      debugPrint('AuthCallbackService: getSessionFromUrl failed: $e');
    }

    final refreshToken = _extractRefreshToken(uri);
    if (refreshToken == null || refreshToken.isEmpty) return;

    try {
      await SupabaseService.client.auth.setSession(refreshToken);
      debugPrint('AuthCallbackService: session restored from refresh_token');
      _confirmationController.add('Connexion réussie.');
    } catch (e) {
      debugPrint('AuthCallbackService: setSession failed: $e');
    }
  }

  String? _extractRefreshToken(Uri uri) {
    final normalized = _normalizeAuthUri(uri);
    final token = normalized.queryParameters['refresh_token'];
    if (token == null || token.isEmpty) return null;
    return token;
  }

  Uri _normalizeAuthUri(Uri uri) {
    if (uri.hasQuery) {
      final decoded = uri.toString().replaceAll('#', '&');
      return Uri.parse(decoded);
    }
    final decoded = uri.toString().replaceAll('#', '?');
    return Uri.parse(decoded);
  }
}
