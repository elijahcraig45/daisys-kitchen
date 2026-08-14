import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recipe_keeper/services/auth_service.dart';
import 'package:recipe_keeper/services/firestore_service.dart';
import 'package:recipe_keeper/services/grocery_service.dart';
import 'package:recipe_keeper/services/household_service.dart';
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
///
/// Async because admin is a Firestore field rather than an email comparison — the same
/// field firestore.rules reads, so the app and the rules cannot disagree.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return false;
  return ref.watch(authServiceProvider).isAdmin;
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

/// Households: create, invite, join, leave.
final householdServiceProvider = Provider<HouseholdService>((ref) => HouseholdService());

/// The signed-in user's household, or null.
final myHouseholdProvider = StreamProvider<Household?>((ref) {
  return ref.watch(householdServiceProvider).watchMyHousehold();
});

/// Which slice of the library is on screen. Filtering happens here rather than in a
/// screen, so every surface agrees about what "mine" means.
enum RecipeScope { mine, household, community }

/// Community is the default because it is the only scope guaranteed to have something in
/// it for an arrival — signed out, or signed in with nothing written yet.
final recipeScopeProvider =
    StateProvider<RecipeScope>((ref) => RecipeScope.community);

/// The household grocery list.
final groceryServiceProvider = Provider<GroceryService>((ref) => GroceryService());

/// Items on a household's list. Family-scoped by household id, so the stream is torn
/// down and rebuilt if someone joins or leaves rather than watching a stale list.
final groceryItemsProvider =
    StreamProvider.family<List<GroceryItem>, String>((ref, householdId) {
  return ref.watch(groceryServiceProvider).watchItems(householdId);
});

/// Recipe ids saved from the community. A save is a reference; editing forks it.
final savedRecipeIdsProvider = StreamProvider<Set<String>>((ref) {
  return ref.watch(firestoreServiceProvider).watchSavedRecipeIds();
});

/// The signed-in user's favourite recipe ids.
///
/// Favourites moved off the recipe document — an `isFavorite` field there was shared
/// state, so one person favouriting something marked it for everyone.
final favoriteIdsProvider = StreamProvider<Set<String>>((ref) {
  return ref.watch(firestoreServiceProvider).watchFavoriteIds();
});

/// Filtered recipes provider for Firestore
final firestoreFilteredRecipesProvider = Provider<List<Recipe>>((ref) {
  final recipesAsync = ref.watch(recipesStreamProvider);
  final favoriteIds = ref.watch(favoriteIdsProvider).valueOrNull ?? const <String>{};
  final searchQuery = ref.watch(searchQueryProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final selectedDifficulty = ref.watch(selectedDifficultyProvider);
  final showFavoritesOnly = ref.watch(showFavoritesOnlyProvider);
  final scope = ref.watch(recipeScopeProvider);
  final myUid = ref.watch(currentUserProvider).valueOrNull?.uid;
  final myHouseholdId = ref.watch(myHouseholdProvider).valueOrNull?.id;
  final savedIds = ref.watch(savedRecipeIdsProvider).valueOrNull ?? const <String>{};

  return recipesAsync.when(
    data: (recipes) {
      // Stamped from the viewer's own favourites, since the document no longer carries
      // it. Done here so every screen reading this provider sees the same answer.
      for (final recipe in recipes) {
        recipe.isFavorite =
            recipe.firestoreId != null && favoriteIds.contains(recipe.firestoreId);
      }
      // The stream carries everything this viewer may see; the scope decides which
      // slice is on screen. Filtered here rather than in a screen so every surface
      // agrees about what "mine" means.
      var filtered = recipes.where((r) {
        switch (scope) {
          case RecipeScope.mine:
            // Mine is what I wrote plus what I saved from the community — the shelf,
            // not the authorship.
            return r.createdBy == myUid ||
                (r.firestoreId != null && savedIds.contains(r.firestoreId));
          case RecipeScope.household:
            return myHouseholdId != null &&
                r.visibility == 'household' &&
                r.householdId == myHouseholdId;
          case RecipeScope.community:
            return r.visibility == 'public';
        }
      }).toList();

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
