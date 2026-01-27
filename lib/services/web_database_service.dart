import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recipe_keeper/models/recipe.dart';
import 'package:recipe_keeper/services/logger_service.dart';

class WebDatabaseService {
  static const String _recipesKey = 'recipes';
  static SharedPreferences? _prefs;

  static Future<void> initialize() async {
    try {
      LoggerService.info('Initializing web database...', 'WebDB');
      _prefs = await SharedPreferences.getInstance();
      LoggerService.success('Web database initialized', 'WebDB');
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to initialize web database',
        error: e,
        stackTrace: stackTrace,
        tag: 'WebDB',
      );
      rethrow;
    }
  }

  Future<int> createRecipe(Recipe recipe) async {
    try {
      final recipes = await getAllRecipes();
      
      // Generate ID
      recipe.id = recipes.isEmpty ? 1 : recipes.map((r) => r.id).reduce((a, b) => a > b ? a : b) + 1;
      
      recipes.add(recipe);
      await _saveRecipes(recipes);
      LoggerService.info('Recipe created with ID: ${recipe.id}', 'WebDB');
      return recipe.id;
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error creating recipe',
        error: e,
        stackTrace: stackTrace,
        tag: 'WebDB',
      );
      rethrow;
    }
  }

  Future<List<Recipe>> getAllRecipes() async {
    try {
      final String? recipesJson = _prefs?.getString(_recipesKey);
      if (recipesJson == null || recipesJson.isEmpty) {
        return [];
      }

      final List<dynamic> decoded = jsonDecode(recipesJson);
      return decoded.map((json) => Recipe.fromJson(json as Map<String, dynamic>)).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error loading recipes from storage',
        error: e,
        stackTrace: stackTrace,
        tag: 'WebDB',
      );
      return [];
    }
  }

  Future<Recipe?> getRecipeById(int id) async {
    try {
      final recipes = await getAllRecipes();
      return recipes.firstWhere((r) => r.id == id);
    } catch (e) {
      LoggerService.warning('Recipe not found: $id', 'WebDB');
      return null;
    }
  }

  Future<List<Recipe>> searchRecipes(String query) async {
    try {
      if (query.isEmpty) {
        return await getAllRecipes();
      }

      final recipes = await getAllRecipes();
      final lowerQuery = query.toLowerCase();

      return recipes.where((recipe) {
        return recipe.title.toLowerCase().contains(lowerQuery) ||
            recipe.description.toLowerCase().contains(lowerQuery) ||
            (recipe.tags?.any((tag) => tag.toLowerCase().contains(lowerQuery)) ?? false);
      }).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error searching recipes',
        error: e,
        stackTrace: stackTrace,
        tag: 'WebDB',
      );
      return [];
    }
  }

  Future<List<Recipe>> getRecipesByCategory(String category) async {
    try {
      final recipes = await getAllRecipes();
      return recipes.where((r) => 
        r.category?.toLowerCase() == category.toLowerCase()
      ).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error getting recipes by category',
        error: e,
        stackTrace: stackTrace,
        tag: 'WebDB',
      );
      return [];
    }
  }

  Future<List<Recipe>> getFavoriteRecipes() async {
    try {
      final recipes = await getAllRecipes();
      return recipes.where((r) => r.isFavorite).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error getting favorite recipes',
        error: e,
        stackTrace: stackTrace,
        tag: 'WebDB',
      );
      return [];
    }
  }

  Future<void> updateRecipe(Recipe recipe) async {
    try {
      final recipes = await getAllRecipes();
      final index = recipes.indexWhere((r) => r.id == recipe.id);
      
      if (index != -1) {
        recipe.updatedAt = DateTime.now();
        recipes[index] = recipe;
        await _saveRecipes(recipes);
        LoggerService.info('Recipe updated: ${recipe.id}', 'WebDB');
      } else {
        LoggerService.warning('Recipe not found for update: ${recipe.id}', 'WebDB');
      }
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error updating recipe',
        error: e,
        stackTrace: stackTrace,
        tag: 'WebDB',
      );
      rethrow;
    }
  }

  Future<bool> deleteRecipe(int id) async {
    try {
      final recipes = await getAllRecipes();
      final initialLength = recipes.length;
      recipes.removeWhere((r) => r.id == id);
      
      if (recipes.length < initialLength) {
        await _saveRecipes(recipes);
        LoggerService.info('Recipe deleted: $id', 'WebDB');
        return true;
      }
      LoggerService.warning('Recipe not found for deletion: $id', 'WebDB');
      return false;
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error deleting recipe',
        error: e,
        stackTrace: stackTrace,
        tag: 'WebDB',
      );
      return false;
    }
  }

  Future<void> deleteAllRecipes() async {
    await _prefs?.remove(_recipesKey);
  }

  Future<void> importRecipes(List<Recipe> recipes) async {
    final existing = await getAllRecipes();
    
    for (var recipe in recipes) {
      // Generate new ID
      final maxId = existing.isEmpty ? 0 : existing.map((r) => r.id).reduce((a, b) => a > b ? a : b);
      recipe.id = maxId + 1 + existing.length;
      existing.add(recipe);
    }
    
    await _saveRecipes(existing);
  }

  Future<List<String>> getAllCategories() async {
    final recipes = await getAllRecipes();
    final categories = recipes
        .where((r) => r.category != null && r.category!.isNotEmpty)
        .map((r) => r.category!)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  Future<List<String>> getAllTags() async {
    final recipes = await getAllRecipes();
    final tags = <String>{};
    for (final recipe in recipes) {
      if (recipe.tags != null) {
        tags.addAll(recipe.tags!);
      }
    }
    final tagList = tags.toList();
    tagList.sort();
    return tagList;
  }

  Future<void> _saveRecipes(List<Recipe> recipes) async {
    final recipesJson = jsonEncode(recipes.map((r) => r.toJson()).toList());
    await _prefs?.setString(_recipesKey, recipesJson);
  }
}
