import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recipe_keeper/models/recipe.dart';

class WebDatabaseService {
  static const String _recipesKey = 'recipes';
  static SharedPreferences? _prefs;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<int> createRecipe(Recipe recipe) async {
    final recipes = await getAllRecipes();
    
    // Generate ID
    recipe.id = recipes.isEmpty ? 1 : recipes.map((r) => r.id).reduce((a, b) => a > b ? a : b) + 1;
    
    recipes.add(recipe);
    await _saveRecipes(recipes);
    return recipe.id;
  }

  Future<List<Recipe>> getAllRecipes() async {
    final String? recipesJson = _prefs?.getString(_recipesKey);
    if (recipesJson == null || recipesJson.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(recipesJson);
      return decoded.map((json) => Recipe.fromJson(json as Map<String, dynamic>)).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      return [];
    }
  }

  Future<Recipe?> getRecipeById(int id) async {
    final recipes = await getAllRecipes();
    try {
      return recipes.firstWhere((r) => r.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<List<Recipe>> searchRecipes(String query) async {
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
  }

  Future<List<Recipe>> getRecipesByCategory(String category) async {
    final recipes = await getAllRecipes();
    return recipes.where((r) => 
      r.category?.toLowerCase() == category.toLowerCase()
    ).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<List<Recipe>> getFavoriteRecipes() async {
    final recipes = await getAllRecipes();
    return recipes.where((r) => r.isFavorite).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> updateRecipe(Recipe recipe) async {
    final recipes = await getAllRecipes();
    final index = recipes.indexWhere((r) => r.id == recipe.id);
    
    if (index != -1) {
      recipe.updatedAt = DateTime.now();
      recipes[index] = recipe;
      await _saveRecipes(recipes);
    }
  }

  Future<bool> deleteRecipe(int id) async {
    final recipes = await getAllRecipes();
    final initialLength = recipes.length;
    recipes.removeWhere((r) => r.id == id);
    
    if (recipes.length < initialLength) {
      await _saveRecipes(recipes);
      return true;
    }
    return false;
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
