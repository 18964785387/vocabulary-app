import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeModeOption {
  system,
  light,
  dark,
}

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  
  ThemeModeOption _themeMode = ThemeModeOption.system;
  
  ThemeModeOption get themeMode => _themeMode;
  
  ThemeProvider() {
    _loadTheme();
  }
  
  /// 加载保存的主题偏好
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);
    if (savedTheme != null) {
      _themeMode = ThemeModeOption.values.firstWhere(
        (e) => e.name == savedTheme,
        orElse: () => ThemeModeOption.system,
      );
      notifyListeners();
    }
  }
  
  /// 保存主题偏好
  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, _themeMode.name);
  }
  
  /// 设置主题模式
  Future<void> setThemeMode(ThemeModeOption mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      await _saveTheme();
      notifyListeners();
    }
  }
  
  /// 获取 Flutter 的 ThemeMode
  ThemeMode get flutterThemeMode {
    switch (_themeMode) {
      case ThemeModeOption.system:
        return ThemeMode.system;
      case ThemeModeOption.light:
        return ThemeMode.light;
      case ThemeModeOption.dark:
        return ThemeMode.dark;
    }
  }
  
  /// 获取主题模式显示名称
  String getThemeModeName(ThemeModeOption mode) {
    switch (mode) {
      case ThemeModeOption.system:
        return '跟随系统';
      case ThemeModeOption.light:
        return '浅色模式';
      case ThemeModeOption.dark:
        return '深色模式';
    }
  }
}
