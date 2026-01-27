import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipe_keeper/models/recipe.dart';
import 'package:recipe_keeper/services/database_service.dart';
import 'package:recipe_keeper/services/logger_service.dart';

final recipesProvider = StreamProvider<List<Recipe>>((ref) async* {
  try {
    // Initial load with error handling
    try {
      yield await DatabaseService.getAllRecipes();
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error loading initial recipes',
        error: e,
        stackTrace: stackTrace,
        tag: 'RecipeProvider',
      );
      yield [];
    }
    
    // Listen for changes (simple polling approach)
    // In a production app, you might use Isar's watch functionality
    while (true) {
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        yield await DatabaseService.getAllRecipes();
      } catch (e) {
        LoggerService.warning(
          'Error refreshing recipes: $e',
          'RecipeProvider',
        );
        // Keep yielding last known state on errors
      }
    }
  } catch (e, stackTrace) {
    LoggerService.error(
      'Fatal error in recipes provider',
      error: e,
      stackTrace: stackTrace,
      tag: 'RecipeProvider',
    );
    yield [];
  }
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final filteredRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  try {
    final query = ref.watch(searchQueryProvider);
    
    if (query.isEmpty) {
      return await DatabaseService.getAllRecipes();
    }
    
    return await DatabaseService.searchRecipes(query);
  } catch (e, stackTrace) {
    LoggerService.error(
      'Error filtering recipes',
      error: e,
      stackTrace: stackTrace,
      tag: 'RecipeProvider',
    );
    return [];
  }
});

final favoriteRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  try {
    return await DatabaseService.getFavoriteRecipes();
  } catch (e, stackTrace) {
    LoggerService.error(
      'Error loading favorite recipes',
      error: e,
      stackTrace: stackTrace,
      tag: 'RecipeProvider',
    );
    return [];
  }
});

final categoriesProvider = FutureProvider<List<String>>((ref) async {
  try {
    return await DatabaseService.getAllCategories();
  } catch (e, stackTrace) {
    LoggerService.error(
      'Error loading categories',
      error: e,
      stackTrace: stackTrace,
      tag: 'RecipeProvider',
    );
    return [];
  }
});

final tagsProvider = FutureProvider<List<String>>((ref) async {
  try {
    return await DatabaseService.getAllTags();
  } catch (e, stackTrace) {
    LoggerService.error(
      'Error loading tags',
      error: e,
      stackTrace: stackTrace,
      tag: 'RecipeProvider',
    );
    return [];
  }
});
