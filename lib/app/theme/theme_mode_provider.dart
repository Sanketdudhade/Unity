import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kThemePrefKey = 'unity_admin_theme_mode';

/// Riverpod Notifier managing the user's selected ThemeMode (Light, Dark, Follow System).
/// Persists preference locally using SharedPreferences without writing to Firestore.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _loadPreference();
    return ThemeMode.system;
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedValue = prefs.getString(_kThemePrefKey);
      if (savedValue != null) {
        switch (savedValue) {
          case 'light':
            state = ThemeMode.light;
            break;
          case 'dark':
            state = ThemeMode.dark;
            break;
          case 'system':
          default:
            state = ThemeMode.system;
            break;
        }
      }
    } catch (_) {
      // Fallback gracefully to system default
      state = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stringValue = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await prefs.setString(_kThemePrefKey, stringValue);
    } catch (_) {
      // Ignored if local storage is temporarily inaccessible
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
