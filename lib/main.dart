import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/timer_provider.dart';
import 'screens/home_screen.dart';
import 'services/settings_service.dart';

/// Entry point for Zen Focus.
///
/// ### ANR Prevention at the app level:
///
/// 1. The only async work before runApp() is [SettingsService.init()],
///    which loads SharedPreferences. This typically takes < 5ms and
///    is well within the Android 5-second ANR threshold.
///
/// 2. We use [ChangeNotifierProvider] to lazily create [TimerProvider].
///    No heavy allocations happen during widget tree construction.
///
/// 3. The entire UI is driven by Provider's notification system,
///    ensuring that the framework only rebuilds the minimal set of
///    widgets when state changes — keeping frame times well under 16ms.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences before the app starts.
  // This is fast (< 5ms) and guarantees that all subsequent
  // reads from SettingsService are synchronous.
  final settingsService = SettingsService();
  await settingsService.init();

  runApp(ZenFocusApp(settingsService: settingsService));
}

class ZenFocusApp extends StatelessWidget {
  const ZenFocusApp({super.key, required this.settingsService});

  final SettingsService settingsService;

  @override
  Widget build(BuildContext context) {
    // Determine theme mode from saved preference.
    final savedMode = settingsService.getThemeMode();
    ThemeMode themeMode;
    switch (savedMode) {
      case 'light':
        themeMode = ThemeMode.light;
        break;
      case 'dark':
        themeMode = ThemeMode.dark;
        break;
      default:
        themeMode = ThemeMode.system;
    }

    return MultiProvider(
      providers: [
        // Provide the SettingsService as a simple value — it's already
        // initialized, so no async overhead.
        Provider<SettingsService>.value(value: settingsService),

        // TimerProvider depends on SettingsService for reading/writing
        // preferences. ChangeNotifierProvider handles disposal automatically.
        ChangeNotifierProvider<TimerProvider>(
          create: (_) => TimerProvider(settingsService),
        ),
      ],
      child: MaterialApp(
        title: 'Zen Focus',
        debugShowCheckedModeBanner: false,

        // ─── Theme Configuration ───
        // Using Material 3 with a teal-flavored color scheme.
        themeMode: themeMode,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),

        home: const HomeScreen(),
      ),
    );
  }

  /// Builds a Material 3 [ThemeData] for the given brightness.
  ///
  /// We use the locally bundled Inter font for clean, minimalist
  /// typography that renders consistently on all Android devices,
  /// without needing INTERNET permission.
  ThemeData _buildTheme(Brightness brightness) {
    // Seed color for Material 3 dynamic color scheme.
    // Teal gives a calm, focus-friendly vibe.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2D7D9A),
      brightness: brightness,
    );

    // Inter font — locally bundled, declared in pubspec.yaml.
    // No network call needed (unlike google_fonts package).
    final baseTextTheme = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;

    // Apply Inter font to all text styles.
    final textTheme = baseTextTheme.apply(fontFamily: 'Inter');

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: colorScheme.surface,

      // FilledButton style — rounded, padded.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),

      // AppBar matches the surface for minimal look.
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
    );
  }
}
