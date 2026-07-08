// lib/supabase_options.dart

class SupabaseOptions {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://tjtjxhxesyhjozpetyqw.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRqdGp4aHhlc3loam96cGV0eXF3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0MjcyMzksImV4cCI6MjA5OTAwMzIzOX0.1GW0uDSlHoUqV6uDXyA74RaGPDMor4hNZlnRKUi3W0Y',
  );
}
