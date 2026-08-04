import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

class ThemeNotifier extends Notifier<ThemeMode> {
  static const String _themeKey = 'theme_mode';
  late Box _box;

  @override
  ThemeMode build() {
    _box = Hive.box('settings_box');
    final stored = _box.get(_themeKey, defaultValue: 'light');
    return stored == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  void toggleTheme() {
    if (state == ThemeMode.light) {
      state = ThemeMode.dark;
      _box.put(_themeKey, 'dark');
    } else {
      state = ThemeMode.light;
      _box.put(_themeKey, 'light');
    }
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);
