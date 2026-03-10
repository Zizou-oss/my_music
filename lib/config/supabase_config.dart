class SupabaseConfig {
  // Remplace ces valeurs par tes vraies credentials Supabase.
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  // Deep link redirect for OAuth/email confirmations.
  // Default keeps current custom-scheme behavior and can be overridden in prod:
  // --dart-define=SUPABASE_EMAIL_REDIRECT_TO=https://2block-web-ctth.vercel.app/auth-callback
  static const String emailRedirectTo = String.fromEnvironment(
    'SUPABASE_EMAIL_REDIRECT_TO',
    defaultValue: 'mymusic://auth-callback',
  );
}
