import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:readendar/di/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults to system when no preference is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());

    expect(ThemeModeNotifier(prefs).state, ThemeMode.system);
  });

  test('loads an explicit light or dark preference', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    final darkPrefs = PrefsStorage(await SharedPreferences.getInstance());
    expect(ThemeModeNotifier(darkPrefs).state, ThemeMode.dark);

    SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
    final lightPrefs = PrefsStorage(await SharedPreferences.getInstance());
    expect(ThemeModeNotifier(lightPrefs).state, ThemeMode.light);
  });

  test('loads a stored system preference', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'system'});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());

    expect(ThemeModeNotifier(prefs).state, ThemeMode.system);
  });

  test('setMode persists light, dark, and system', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PrefsStorage(await SharedPreferences.getInstance());
    final notifier = ThemeModeNotifier(prefs);

    await notifier.setMode(ThemeMode.light);
    expect(notifier.state, ThemeMode.light);
    expect(prefs.getTheme(), 'light');

    await notifier.setMode(ThemeMode.dark);
    expect(notifier.state, ThemeMode.dark);
    expect(prefs.getTheme(), 'dark');

    await notifier.setMode(ThemeMode.system);
    expect(notifier.state, ThemeMode.system);
    expect(prefs.getTheme(), 'system');
  });
}
