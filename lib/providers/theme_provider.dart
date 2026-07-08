import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeModeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier(ref);
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  final Ref ref;

  ThemeNotifier(this.ref) : super(ThemeMode.system);

  Future<void> toggleTheme() async {
    // Locked to system theme: no manual toggle allowed
  }
}
