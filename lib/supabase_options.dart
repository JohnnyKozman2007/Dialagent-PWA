// lib/supabase_options.dart

class SupabaseOptions {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://gzigshqricfihxiezdmu.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd6aWdzaHFyaWNmaWh4aWV6ZG11Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE5NDczMjksImV4cCI6MjA5NzUyMzMyOX0.ykCFlH2Ro8OH-LWOHUHz7QaCP2PWqepFd9QPzeyGlRI',
  );
}
