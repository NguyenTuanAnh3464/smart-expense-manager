import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

enum AppThemePreset {
  lightGreen("light_green", "Light Green"),
  forestGreen("forest_green", "Forest Green"),
  monotoneBlack("monotone_black", "Monotone Black");

  final String id;
  final String label;

  const AppThemePreset(this.id, this.label);

  static AppThemePreset fromId(String? id) {
    return AppThemePreset.values.firstWhere(
      (theme) => theme.id == id,
      orElse: () => AppThemePreset.lightGreen,
    );
  }
}

class ThemeService extends ChangeNotifier {
  static final ThemeService instance = ThemeService._();
  static const String _themeKey = "theme_mode";
  static const String _themePresetKey = "theme_preset";

  ThemeMode _themeMode = ThemeMode.system;
  AppThemePreset _preset = AppThemePreset.lightGreen;

  factory ThemeService() => instance;

  ThemeService._();

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  AppThemePreset get preset => _preset;

  ThemeData get lightTheme {
    return switch (_preset) {
      AppThemePreset.forestGreen => AppTheme.forestGreenTheme,
      AppThemePreset.monotoneBlack => AppTheme.monotoneBlackTheme,
      AppThemePreset.lightGreen => AppTheme.lightGreenTheme,
    };
  }

  ThemeData get darkTheme {
    return switch (_preset) {
      AppThemePreset.monotoneBlack => AppTheme.monotoneBlackTheme,
      AppThemePreset.forestGreen => AppTheme.forestGreenTheme,
      AppThemePreset.lightGreen => AppTheme.lightGreenTheme,
    };
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    String? presetId = prefs.getString(_themePresetKey);
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();
      final remotePreset = snapshot.data()?["themeMode"]?.toString();
      if (remotePreset != null && remotePreset.isNotEmpty) {
        presetId = remotePreset;
        await prefs.setString(_themePresetKey, remotePreset);
      }
    }
    _preset = AppThemePreset.fromId(presetId);
    _themeMode = _modeForPreset(_preset);
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    await setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, _modeToString(mode));
  }

  Future<void> setThemePreset(AppThemePreset preset) async {
    _preset = preset;
    _themeMode = _modeForPreset(preset);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePresetKey, preset.id);
    await prefs.setString(_themeKey, _modeToString(_themeMode));

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        "themeMode": preset.id,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  ThemeMode _modeForPreset(AppThemePreset preset) {
    return preset == AppThemePreset.monotoneBlack
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  static String _modeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return "light";
      case ThemeMode.dark:
        return "dark";
      case ThemeMode.system:
        return "system";
    }
  }
}
