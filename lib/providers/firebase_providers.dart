import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recipe_keeper/services/auth_service.dart';
import 'package:recipe_keeper/services/firestore_service.dart';
import 'package:recipe_keeper/models/recipe.dart';

// Filter state providers for Firestore
final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedCategoryProvider = StateProvider<String?>((ref) => null);
final selectedDifficultyProvider =
    StateProvider<DifficultyLevel?>((ref) => null);
final showFavoritesOnlyProvider = StateProvider<bool>((ref) => false);

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Firestore service provider
final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

/// Current user provider
final currentUserProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Is admin provider (reactive)
final isAdminProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  final authService = ref.watch(authServiceProvider);

  return userAsync.when(
    data: (user) => user != null && authService.isAdmin,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Is signed in provider (reactive)
final isSignedInProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(currentUserProvider);

  return userAsync.when(
    data: (user) => user != null,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Recipes stream provider (real-time updates)
final recipesStreamProvider = StreamProvider<List<Recipe>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getRecipesStream();
});

/// Filtered recipes provider for Firestore
final firestoreFilteredRecipesProvider = Provider<List<Recipe>>((ref) {
  final recipesAsync = ref.watch(recipesStreamProvider);
  final searchQuery = ref.watch(searchQueryProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final selectedDifficulty = ref.watch(selectedDifficultyProvider);
  final showFavoritesOnly = ref.watch(showFavoritesOnlyProvider);

  return recipesAsync.when(
    data: (recipes) {
      var filtered = recipes;

      // Search filter — matches what the search field advertises: name,
      // ingredients and tags, plus description, category and cuisine.
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        filtered = filtered.where((recipe) => _matches(recipe, query)).toList();
      }

      // Category filter
      if (selectedCategory != null) {
        final category = selectedCategory.toLowerCase();
        filtered = filtered
            .where((r) => r.category?.toLowerCase() == category)
            .toList();
      }

      // Difficulty filter
      if (selectedDifficulty != null) {
        filtered =
            filtered.where((r) => r.difficulty == selectedDifficulty).toList();
      }

      // Favorites filter
      if (showFavoritesOnly) {
        filtered = filtered.where((r) => r.isFavorite).toList();
      }

      return filtered;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

bool _matches(Recipe recipe, String query) {
  bool contains(String? value) =>
      value != null && value.toLowerCase().contains(query);

  return contains(recipe.title) ||
      contains(recipe.description) ||
      contains(recipe.category) ||
      contains(recipe.cuisine) ||
      (recipe.tags?.any(contains) ?? false) ||
      recipe.ingredients.any((i) => contains(i.name));
}

/// Categories provider (extracts unique categories from recipes)
final categoriesProvider = Provider<List<String>>((ref) {
  final recipesAsync = ref.watch(recipesStreamProvider);

  return recipesAsync.when(
    data: (recipes) {
      final categories = recipes
          .map((r) => r.category)
          .where((c) => c != null && c.isNotEmpty)
          .map((c) => c!)
          .toSet()
          .toList();
      categories.sort();
      return categories;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});
