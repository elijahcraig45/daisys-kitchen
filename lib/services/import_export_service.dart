import 'dart:convert';
import 'package:recipe_keeper/models/recipe.dart';
import 'import_export_service_stub.dart'
    if (dart.library.html) 'import_export_service_web.dart'
    if (dart.library.io) 'import_export_service_native.dart';

class ImportExportService {
  // Export a single recipe to JSON
  Future<void> exportRecipe(Recipe recipe) async {
    final jsonData = jsonEncode(recipe.toJson());
    final fileName = '${recipe.title.replaceAll(' ', '_')}_recipe.json';
    await exportFile(jsonData, fileName);
  }

  // Export all recipes to JSON
  Future<void> exportAllRecipes(List<Recipe> recipes) async {
    final recipesJson = recipes.map((r) => r.toJson()).toList();
    final jsonData = jsonEncode({
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'recipes': recipesJson,
    });
    
    final fileName = 'recipes_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    await exportFile(jsonData, fileName);
  }

  // Import recipes from JSON file
  Future<List<Recipe>> importRecipes() async {
    final contents = await importFile();
    if (contents == null || contents.isEmpty) {
      return [];
    }
    
    final data = jsonDecode(contents);

    // Handle both single recipe and batch export formats
    if (data is Map<String, dynamic>) {
      if (data.containsKey('recipes')) {
        // Batch export format
        final recipesData = data['recipes'] as List;
        return recipesData.map((json) => Recipe.fromJson(json)).toList();
      } else {
        // Single recipe format
        return [Recipe.fromJson(data)];
      }
    } else if (data is List) {
      // List of recipes
      return data.map((json) => Recipe.fromJson(json)).toList();
    }

    return [];
  }
}
