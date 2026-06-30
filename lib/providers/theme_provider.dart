import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main()');
});

final themeModeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier(ref);
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  final Ref ref;
  static const _themeKey = 'theme_mode';

  ThemeNotifier(this.ref) : super(ThemeMode.system) {
    _loadThemeFromPrefs();
  }

  void _loadThemeFromPrefs() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final themeStr = prefs.getString(_themeKey);
      if (themeStr == 'dark') {
        state = ThemeMode.dark;
      } else if (themeStr == 'light') {
        state = ThemeMode.light;
      } else {
        state = ThemeMode.system;
      }
    } catch (e) {
      print('Error loading theme from prefs: $e');
      state = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final String themeStr;
      if (mode == ThemeMode.dark) {
        themeStr = 'dark';
      } else if (mode == ThemeMode.light) {
        themeStr = 'light';
      } else {
        themeStr = 'system';
      }
      await prefs.setString(_themeKey, themeStr);
    } catch (e) {
      print('Error saving theme to prefs: $e');
    }
  }

  Future<void> toggleTheme() async {
    final ThemeMode newMode;
    if (state == ThemeMode.system) {
      newMode = ThemeMode.light;
    } else if (state == ThemeMode.light) {
      newMode = ThemeMode.dark;
    } else {
      newMode = ThemeMode.system;
    }
    await setThemeMode(newMode);
  }
}
