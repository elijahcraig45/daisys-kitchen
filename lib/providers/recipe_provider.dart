import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipe_keeper/models/recipe.dart';
import 'package:recipe_keeper/services/database_service.dart';

final recipesProvider = StreamProvider<List<Recipe>>((ref) async* {
  // Initial load
  yield await DatabaseService.getAllRecipes();
  
  // Listen for changes (simple polling approach)
  // In a production app, you might use Isar's watch functionality
  while (true) {
    await Future.delayed(const Duration(milliseconds: 500));
    yield await DatabaseService.getAllRecipes();
  }
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final filteredRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  
  if (query.isEmpty) {
    return await DatabaseService.getAllRecipes();
  }
  
  return await DatabaseService.searchRecipes(query);
});

final favoriteRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  return await DatabaseService.getFavoriteRecipes();
});

final categoriesProvider = FutureProvider<List<String>>((ref) async {
  return await DatabaseService.getAllCategories();
});

final tagsProvider = FutureProvider<List<String>>((ref) async {
  return await DatabaseService.getAllTags();
});
