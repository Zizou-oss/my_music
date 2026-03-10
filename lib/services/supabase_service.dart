import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

class SupabaseService {
  static bool get isEnabled => SupabaseConfig.isConfigured;

  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => isEnabled ? client.auth.currentUser : null;
}
