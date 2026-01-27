import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:recipe_keeper/models/recipe.dart';
import 'package:recipe_keeper/services/web_database_service.dart';
import 'package:recipe_keeper/services/logger_service.dart';

class DatabaseService {
  static late dynamic _instance;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) {
      LoggerService.debug('Database already initialized', 'Database');
      return;
    }
    
    try {
      LoggerService.info('Initializing database service...', 'Database');
      
      if (kIsWeb) {
        _instance = WebDatabaseService();
        await WebDatabaseService.initialize();
      } else {
        // For now, use WebDatabaseService for all platforms until Isar schema is generated
        _instance = WebDatabaseService();
        await WebDatabaseService.initialize();
      }
      
      _initialized = true;
      LoggerService.success('Database service initialized', 'Database');
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to initialize database',
        error: e,
        stackTrace: stackTrace,
        tag: 'Database',
      );
      rethrow;
    }
  }

  static void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('DatabaseService not initialized. Call initialize() first.');
    }
  }

  // Delegate all methods to the appropriate implementation
  static Future<int> createRecipe(Recipe recipe) async {
    _ensureInitialized();
    
    if (kIsWeb) {
      return await (_instance as WebDatabaseService).createRecipe(recipe);
    } else {
      return await _instance.createRecipe(recipe);
    }
  }

  static Future<List<Recipe>> getAllRecipes() async {
    _ensureInitialized();
    
    if (kIsWeb) {
      return await (_instance as WebDatabaseService).getAllRecipes();
    } else {
      return await _instance.getAllRecipes();
    }
  }

  static Future<Recipe?> getRecipeById(int id) async {
    _ensureInitialized();
    
    if (kIsWeb) {
      return await (_instance as WebDatabaseService).getRecipeById(id);
    } else {
      return await _instance.getRecipeById(id);
    }
  }

  static Future<List<Recipe>> searchRecipes(String query) async {
    _ensureInitialized();
    
    if (kIsWeb) {
      return await (_instance as WebDatabaseService).searchRecipes(query);
    } else {
      return await _instance.searchRecipes(query);
    }
  }

  static Future<List<Recipe>> getRecipesByCategory(String category) async {
    _ensureInitialized();
    
    if (kIsWeb) {
      return await (_instance as WebDatabaseService).getRecipesByCategory(category);
    } else {
      return await _instance.getRecipesByCategory(category);
    }
  }

  static Future<List<Recipe>> getFavoriteRecipes() async {
    _ensureInitialized();
    
    if (kIsWeb) {
      return await (_instance as WebDatabaseService).getFavoriteRecipes();
    } else {
      return await _instance.getFavoriteRecipes();
    }
  }

  static Future<void> updateRecipe(Recipe recipe) async {
    _ensureInitialized();
    
    recipe.updatedAt = DateTime.now();
    
    if (kIsWeb) {
      await (_instance as WebDatabaseService).updateRecipe(recipe);
    } else {
      await _instance.updateRecipe(recipe);
    }
  }

  static Future<bool> deleteRecipe(int id) async {
    _ensureInitialized();
    
    if (kIsWeb) {
      return await (_instance as WebDatabaseService).deleteRecipe(id);
    } else {
      return await _instance.deleteRecipe(id);
    }
  }

  static Future<void> deleteAllRecipes() async {
    if (kIsWeb) {
      await (_instance as WebDatabaseService).deleteAllRecipes();
    } else {
      await _instance.deleteAllRecipes();
    }
  }

  static Future<void> importRecipes(List<Recipe> recipes) async {
    if (kIsWeb) {
      await (_instance as WebDatabaseService).importRecipes(recipes);
    } else {
      await _instance.importRecipes(recipes);
    }
  }

  static Future<List<String>> getAllCategories() async {
    if (kIsWeb) {
      return await (_instance as WebDatabaseService).getAllCategories();
    } else {
      return await _instance.getAllCategories();
    }
  }

  static Future<List<String>> getAllTags() async {
    if (kIsWeb) {
      return await (_instance as WebDatabaseService).getAllTags();
    } else {
      return await _instance.getAllTags();
    }
  }
}
