import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme with ChangeNotifier {
  static const String _themeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  AppTheme() {
    _loadThemeMode();
  }

  // Load theme mode from shared preferences
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeValue = prefs.getInt(_themeKey);

      if (themeModeValue != null) {
        _themeMode = ThemeMode.values[themeModeValue];
        notifyListeners();
      }
    } catch (e) {
      // Fallback to system theme if there's an error
      _themeMode = ThemeMode.system;
    }
  }

  // Save theme mode to shared preferences
  Future<void> _saveThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, mode.index);
    } catch (e) {
      // Ignore error if unable to save
    }
  }

  // Toggle between light and dark themes
  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _saveThemeMode(_themeMode);
    notifyListeners();
  }

  // Set specific theme mode
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _saveThemeMode(mode);
    notifyListeners();
  }

  // Get light theme
  ThemeData get lightTheme {
    return FlexThemeData.light(
      scheme: FlexScheme.indigo,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 7,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 10,
        blendOnColors: false,
        inputDecoratorRadius: 10.0,
        inputDecoratorBorderWidth: 1.0,
        elevatedButtonRadius: 10.0,
        outlinedButtonRadius: 10.0,
        textButtonRadius: 10.0,
        cardRadius: 12.0,
        popupMenuRadius: 8.0,
        dialogRadius: 16.0,
        bottomSheetRadius: 16.0,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
    );
  }

  // Get dark theme
  ThemeData get darkTheme {
    return FlexThemeData.dark(
      scheme: FlexScheme.indigo,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 10,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 20,
        blendOnColors: false,
        inputDecoratorRadius: 10.0,
        inputDecoratorBorderWidth: 1.0,
        elevatedButtonRadius: 10.0,
        outlinedButtonRadius: 10.0,
        textButtonRadius: 10.0,
        cardRadius: 12.0,
        popupMenuRadius: 8.0,
        dialogRadius: 16.0,
        bottomSheetRadius: 16.0,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
    );
  }
}
