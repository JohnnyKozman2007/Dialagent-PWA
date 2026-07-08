// lib/supabase_options.dart

class SupabaseOptions {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'YOUR_SUPABASE_URL', // You can also paste your URL here directly
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_SUPABASE_ANON_KEY', // You can also paste your Anon Key here directly
  );
}
