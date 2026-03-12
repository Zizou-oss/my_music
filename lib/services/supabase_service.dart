import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

class SupabaseService {
  static bool get isConfigured => SupabaseConfig.isConfigured;

  static SupabaseClient? get maybeClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static bool get isEnabled => isConfigured && maybeClient != null;

  static SupabaseClient get client {
    final client = maybeClient;
    if (client == null) {
      throw StateError('Supabase client is not initialized.');
    }
    return client;
  }

  static User? get currentUser => isEnabled ? client.auth.currentUser : null;
}
