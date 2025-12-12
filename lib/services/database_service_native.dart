import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:recipe_keeper/models/recipe.dart';

Future<Isar> initializeNativeDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  return await Isar.open(
    [RecipeSchema],
    directory: dir.path,
  );
}

dynamic createNativeDatabaseService(dynamic isar) {
  return NativeDatabaseService(isar as Isar);
}

class NativeDatabaseService {
  final Isar _isar;

  NativeDatabaseService(this._isar);

  Future<int> createRecipe(Recipe recipe) async {
    return await _isar.writeTxn(() async {
      return await _isar.recipes.put(recipe);
    });
  }

  Future<List<Recipe>> getAllRecipes() async {
    return await _isar.recipes.where().sortByUpdatedAtDesc().findAll();
  }

  Future<Recipe?> getRecipeById(int id) async {
    return await _isar.recipes.get(id);
  }

  Future<List<Recipe>> searchRecipes(String query) async {
    if (query.isEmpty) {
      return await getAllRecipes();
    }

    final lowerQuery = query.toLowerCase();

    return await _isar.recipes
        .filter()
        .titleContains(lowerQuery, caseSensitive: false)
        .or()
        .descriptionContains(lowerQuery, caseSensitive: false)
        .or()
        .tagsElementContains(lowerQuery, caseSensitive: false)
        .sortByUpdatedAtDesc()
        .findAll();
  }

  Future<List<Recipe>> getRecipesByCategory(String category) async {
    return await _isar.recipes
        .filter()
        .categoryEqualTo(category, caseSensitive: false)
        .sortByUpdatedAtDesc()
        .findAll();
  }

  Future<List<Recipe>> getFavoriteRecipes() async {
    return await _isar.recipes
        .filter()
        .isFavoriteEqualTo(true)
        .sortByUpdatedAtDesc()
        .findAll();
  }

  Future<void> updateRecipe(Recipe recipe) async {
    recipe.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.recipes.put(recipe);
    });
  }

  Future<bool> deleteRecipe(int id) async {
    return await _isar.writeTxn(() async {
      return await _isar.recipes.delete(id);
    });
  }

  Future<void> deleteAllRecipes() async {
    await _isar.writeTxn(() async {
      await _isar.recipes.clear();
    });
  }

  Future<void> importRecipes(List<Recipe> recipes) async {
    await _isar.writeTxn(() async {
      await _isar.recipes.putAll(recipes);
    });
  }

  Future<List<String>> getAllCategories() async {
    final recipes = await _isar.recipes.where().findAll();
    final categories = recipes
        .where((r) => r.category != null && r.category!.isNotEmpty)
        .map((r) => r.category!)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  Future<List<String>> getAllTags() async {
    final recipes = await _isar.recipes.where().findAll();
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
}
