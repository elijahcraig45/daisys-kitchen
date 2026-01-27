/// Application-wide constants and configuration
/// Makes the app easier to maintain and customize
class AppConstants {
  // App Metadata
  static const String appName = "Daisy's Kitchen";
  static const String appVersion = '1.0.0';
  static const String appTagline = 'A pirate\'s treasure chest for culinary adventures';
  
  // Performance
  static const Duration searchDebounceDelay = Duration(milliseconds: 300);
  static const Duration cacheExpiry = Duration(minutes: 5);
  static const int maxRetryAttempts = 3;
  static const Duration initialRetryDelay = Duration(seconds: 1);
  static const Duration maxRetryDelay = Duration(seconds: 10);
  
  // UI Configuration
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;
  static const int maxRecentRecipes = 10;
  static const int recipesPerPage = 20;
  
  // Recipe Limits
  static const int minTitleLength = 3;
  static const int maxTitleLength = 100;
  static const int minDescriptionLength = 10;
  static const int maxDescriptionLength = 1000;
  static const int minServings = 1;
  static const int maxServings = 1000;
  static const int maxTimeMinutes = 1440; // 24 hours
  static const int maxIngredients = 100;
  static const int maxSteps = 100;
  static const int maxTags = 20;
  
  // Image Configuration
  static const List<String> supportedImageFormats = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
  static const int maxImageSizeBytes = 10 * 1024 * 1024; // 10MB
  
  // Search Configuration
  static const int minSearchLength = 2;
  static const int maxSearchResults = 100;
  
  // Feature Flags
  static const bool enableOfflineMode = true;
  static const bool enablePerformanceMonitoring = true;
  static const bool enableAnalytics = false;
  static const bool enableCrashReporting = false;
  
  // API Configuration
  static const Duration apiTimeout = Duration(seconds: 30);
  static const int maxConcurrentRequests = 5;
  
  // Local Storage Keys
  static const String localRecipesKey = 'recipes';
  static const String userPreferencesKey = 'user_preferences';
  static const String cacheKey = 'recipe_cache';
  
  // Error Messages
  static const String genericErrorMessage = 'Shiver me timbers! Something went wrong.';
  static const String networkErrorMessage = 'Can\'t reach the open seas! Check yer internet.';
  static const String authErrorMessage = 'Authentication failed, matey. Try again!';
  
  // Success Messages
  static const String recipeSavedMessage = 'Recipe saved to the galley! 🏴‍☠️';
  static const String recipeDeletedMessage = 'Recipe sent to Davy Jones\' locker!';
  static const String recipeImportedMessage = 'Recipes imported successfully! ⚓';
  
  // Pirate Themed Messages
  static const List<String> loadingMessages = [
    'Hoisting the sails...',
    'Navigating the seven seas...',
    'Charting the course...',
    'Loading the cargo...',
    'Preparing the galley...',
    'Swabbing the deck...',
    'Setting sail...',
  ];
  
  static const List<String> emptyStateMessages = [
    'No recipes yet, matey!',
    'The galley be empty!',
    'No treasure here yet!',
    'Time to stock the pantry!',
  ];
  
  // Keyboard Shortcuts Help Text
  static const Map<String, String> keyboardShortcuts = {
    'Cmd/Ctrl + N': 'Create new recipe',
    'Cmd/Ctrl + F': 'Focus search',
    'Cmd/Ctrl + S': 'Save recipe',
    'Escape': 'Clear search',
    'F1': 'Show help',
  };
}
