import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipe_keeper/router.dart';
import 'package:recipe_keeper/theme/app_theme.dart';
import 'package:recipe_keeper/services/firebase_service.dart';
import 'package:recipe_keeper/services/remote_config_service.dart';
import 'package:recipe_keeper/services/logger_service.dart';
import 'package:recipe_keeper/utils/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    LoggerService.info("Initializing Daisy's Kitchen...", 'Main');

    LoggerService.info('Initializing Firebase...', 'Main');
    await FirebaseService.initialize();
    LoggerService.success('Firebase initialized successfully', 'Main');

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Remote Config only supplies the Gemini keys, so a failure here degrades
    // AI features rather than blocking startup.
    try {
      await RemoteConfigService.instance.initialize();
      LoggerService.success('Remote Config initialized', 'Main');
    } catch (e) {
      LoggerService.warning('Remote Config initialization failed: $e', 'Main');
    }

    runApp(const ProviderScope(child: RecipeKeeperApp()));
  } catch (e, stackTrace) {
    LoggerService.error(
      'Failed to initialize app',
      error: e,
      stackTrace: stackTrace,
      tag: 'Main',
    );

    runApp(_StartupFailureApp(error: e));
  }
}

/// Shown when Firebase (and therefore every screen) cannot start.
class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 20),
                      Text(
                        '${AppConstants.appName} could not start',
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$error',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: () => runApp(
                            const ProviderScope(child: RecipeKeeperApp())),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class RecipeKeeperApp extends StatelessWidget {
  const RecipeKeeperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
    );
  }
}
