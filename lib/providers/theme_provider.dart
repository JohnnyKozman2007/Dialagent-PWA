import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier(ref);
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  final Ref ref;

  ThemeNotifier(this.ref) : super(ThemeMode.system) {
    _loadTheme();
    // Automatically load theme settings when user authentication state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      if (user != null) {
        _loadThemeFromSupabase(user.id);
      }
    });
  }

  Future<void> _loadTheme() async {
    // 1. First, load from local SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final localPref = prefs.getString('theme_preference');
      if (localPref != null) {
        state = _parseThemeMode(localPref);
      }
    } catch (e) {
      print('Error loading local theme: $e');
    }

    // 2. Load from Supabase if user is already signed in
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await _loadThemeFromSupabase(user.id);
    }
  }

  Future<void> _loadThemeFromSupabase(String uid) async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('theme_preference, darkMode')
          .eq('id', uid)
          .maybeSingle();

      if (data == null) return;

      final themePref = data['theme_preference'] as String?;
      if (themePref != null) {
        final mode = _parseThemeMode(themePref);
        state = mode;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('theme_preference', themePref);
      } else {
        // Fallback for legacy darkMode boolean field
        final isDark = data['darkMode'] as bool?;
        if (isDark != null) {
          final mode = isDark ? ThemeMode.dark : ThemeMode.light;
          state = mode;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('theme_preference', isDark ? 'dark' : 'light');
        }
      }
    } catch (e) {
      print('Error loading Supabase theme: $e');
    }
  }

  ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;

    String prefString = 'system';
    if (mode == ThemeMode.light) prefString = 'light';
    if (mode == ThemeMode.dark) prefString = 'dark';

    // Save to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_preference', prefString);
    } catch (e) {
      print('Error saving local theme: $e');
    }

    // Save to Supabase if user is signed in
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({
          'theme_preference': prefString,
          'darkMode': mode == ThemeMode.dark, // Keep backward compatibility
        })
            .eq('id', user.id);
      } catch (e) {
        print('Error saving Supabase theme: $e');
      }
    }
  }

  Future<void> toggleTheme() async {
    final nextMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setTheme(nextMode);
  }
}

