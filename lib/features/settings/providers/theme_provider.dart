import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, system, snoopy }

const _prefKey = 'app_theme_mode';

class ThemeModeNotifier extends AsyncNotifier<AppThemeMode> {
  @override
  Future<AppThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    return switch (saved) {
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      'snoopy' => AppThemeMode.snoopy,
      _ => AppThemeMode.system,
    };
  }

  Future<void> setMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final key = switch (mode) {
      AppThemeMode.light => 'light',
      AppThemeMode.dark => 'dark',
      AppThemeMode.snoopy => 'snoopy',
      AppThemeMode.system => 'system',
    };
    await prefs.setString(_prefKey, key);
    state = AsyncValue.data(mode);
  }
}

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, AppThemeMode>(
  ThemeModeNotifier.new,
);