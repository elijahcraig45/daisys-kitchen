import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipe_keeper/router.dart';
import 'package:recipe_keeper/services/database_service.dart';
import 'package:recipe_keeper/services/firebase_service.dart';
import 'package:recipe_keeper/services/remote_config_service.dart';
import 'package:recipe_keeper/services/logger_service.dart';

const _blueGlitterBanner1 = Color(0xFF025159);
const _blueGlitterBanner2 = Color(0xFF3E848C);
const _blueGlitterBanner3 = Color(0xFF7AB8BF);
const _blueGlitterBanner4 = Color(0xFFC4EEF2);
const _blueGlitterBanner5 = Color(0xFFA67458);

const _lightDaisysColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: _blueGlitterBanner1,
  onPrimary: Colors.white,
  primaryContainer: _blueGlitterBanner2,
  onPrimaryContainer: Colors.white,
  secondary: _blueGlitterBanner5,
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFF9E4D6),
  onSecondaryContainer: _blueGlitterBanner5,
  tertiary: _blueGlitterBanner3,
  onTertiary: _blueGlitterBanner1,
  tertiaryContainer: _blueGlitterBanner4,
  onTertiaryContainer: _blueGlitterBanner1,
  error: Color(0xFFB3261E),
  onError: Colors.white,
  errorContainer: Color(0xFFF9DEDC),
  onErrorContainer: Color(0xFF410E0B),
  surface: _blueGlitterBanner4,
  onSurface: _blueGlitterBanner1,
  background: _blueGlitterBanner4,
  onBackground: _blueGlitterBanner1,
  surfaceVariant: Color(0xFFE0F4F6),
  onSurfaceVariant: _blueGlitterBanner1,
  outline: Color(0xFF5B7A80),
  outlineVariant: Color(0xFF9EC1C7),
  shadow: Color(0x33000000),
  scrim: Color(0x66000000),
  inverseSurface: _blueGlitterBanner1,
  onInverseSurface: _blueGlitterBanner4,
  inversePrimary: _blueGlitterBanner3,
  surfaceTint: _blueGlitterBanner3,
);

const _darkDaisysColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: _blueGlitterBanner3,
  onPrimary: Colors.black,
  primaryContainer: _blueGlitterBanner2,
  onPrimaryContainer: Colors.black,
  secondary: _blueGlitterBanner5,
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFF4A3629),
  onSecondaryContainer: Colors.white,
  tertiary: _blueGlitterBanner2,
  onTertiary: Colors.black,
  tertiaryContainer: Color(0xFF0F1F22),
  onTertiaryContainer: _blueGlitterBanner4,
  error: Color(0xFFF2B8B5),
  onError: Color(0xFF601410),
  errorContainer: Color(0xFF8C1D18),
  onErrorContainer: Color(0xFFF2B8B5),
  surface: Color(0xFF0F1F22),
  onSurface: _blueGlitterBanner4,
  background: Color(0xFF0F1F22),
  onBackground: _blueGlitterBanner4,
  surfaceVariant: Color(0xFF18353B),
  onSurfaceVariant: _blueGlitterBanner4,
  outline: Color(0xFF4E6D72),
  outlineVariant: Color(0xFF203D43),
  shadow: Color(0xCC000000),
  scrim: Color(0xCC000000),
  inverseSurface: _blueGlitterBanner4,
  onInverseSurface: _blueGlitterBanner1,
  inversePrimary: _blueGlitterBanner1,
  surfaceTint: _blueGlitterBanner2,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    LoggerService.info('Initializing Recipe Keeper app...', 'Main');
    
    // Initialize Firebase first
    LoggerService.info('Initializing Firebase...', 'Main');
    await FirebaseService.initialize();
    LoggerService.success('Firebase initialized successfully', 'Main');
    
    // Initialize Remote Config for API keys
    try {
      await RemoteConfigService.instance.initialize();
      LoggerService.success('Remote Config initialized', 'Main');
    } catch (e) {
      LoggerService.warning('Remote Config initialization failed: $e', 'Main');
    }

    // Then initialize local database
    LoggerService.info('Initializing local database...', 'Main');
    await DatabaseService.initialize();
    LoggerService.success('Database initialized successfully', 'Main');

    runApp(const ProviderScope(child: RecipeKeeperApp()));
  } catch (e, stackTrace) {
    LoggerService.error(
      'Failed to initialize app',
      error: e,
      stackTrace: stackTrace,
      tag: 'Main',
    );
    
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Shiver me timbers! Failed to launch',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error: $e',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // Attempt to restart
                      runApp(const ProviderScope(child: RecipeKeeperApp()));
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RecipeKeeperApp extends StatelessWidget {
  const RecipeKeeperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: "Daisy's Kitchen",
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        colorScheme: _lightDaisysColorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: _blueGlitterBanner4,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 2,
          backgroundColor: _blueGlitterBanner1,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          color: Colors.white,
          surfaceTintColor: _blueGlitterBanner3.withOpacity(0.2),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: 4,
          backgroundColor: _blueGlitterBanner5,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: _blueGlitterBanner3.withOpacity(0.2),
          labelStyle: const TextStyle(color: _blueGlitterBanner1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: _darkDaisysColorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: _darkDaisysColorScheme.background,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 2,
          backgroundColor: Color(0xFF0F1F22),
          foregroundColor: _blueGlitterBanner4,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          color: const Color(0xFF18353B),
          surfaceTintColor: _blueGlitterBanner2.withOpacity(0.1),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: 4,
          backgroundColor: _blueGlitterBanner5,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF152B30),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: _blueGlitterBanner2.withOpacity(0.25),
          labelStyle: const TextStyle(color: _blueGlitterBanner4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
    );
  }
}
