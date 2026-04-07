import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/app_shell.dart';
import 'features/settings/providers/theme_provider.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appThemeModeAsync = ref.watch(themeModeProvider);

    // Enquanto carrega do SharedPreferences, usa system
    final appThemeMode =
        appThemeModeAsync.valueOrNull ?? AppThemeMode.system;

    final isSnoopy = appThemeMode == AppThemeMode.snoopy;

    final themeMode = switch (appThemeMode) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.snoopy => ThemeMode.light,
    };

    return MaterialApp(
      title: 'Quorum',
      debugShowCheckedModeBanner: false,
      theme: isSnoopy ? AppTheme.snoopy : AppTheme.light,
      darkTheme: isSnoopy ? AppTheme.snoopy : AppTheme.dark,
      themeMode: themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      locale: const Locale('pt', 'BR'),
      home: const AppShell(),
    );
  }
}