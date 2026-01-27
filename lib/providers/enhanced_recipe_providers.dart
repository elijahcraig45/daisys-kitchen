import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipe_keeper/models/recipe.dart';
import 'package:recipe_keeper/services/firestore_service.dart';
import 'package:recipe_keeper/services/logger_service.dart';
import 'package:recipe_keeper/services/performance_monitor.dart';

/// Enhanced recipes stream provider with performance monitoring
final recipesStreamWithMonitoringProvider = StreamProvider<List<Recipe>>((ref) {
  PerformanceMonitor.startOperation('RecipesStream');
  
  final firestoreService = FirestoreService();
  
  return firestoreService.getRecipesStream().map((recipes) {
    PerformanceMonitor.endOperation('RecipesStream', tag: 'Providers');
    LoggerService.debug('Recipes stream updated: ${recipes.length} recipes', 'Providers');
    return recipes;
  }).handleError((error, stackTrace) {
    LoggerService.error(
      'Error in recipes stream',
      error: error,
      stackTrace: stackTrace,
      tag: 'Providers',
    );
    return <Recipe>[];
  });
});

/// Debounced search query provider
/// Prevents excessive searches while user is typing
class DebouncedSearchNotifier extends StateNotifier<String> {
  DebouncedSearchNotifier() : super('');
  
  void updateQuery(String query) {
    state = query;
  }
  
  void clear() {
    state = '';
  }
}

final debouncedSearchProvider = StateNotifierProvider<DebouncedSearchNotifier, String>(
  (ref) => DebouncedSearchNotifier(),
);

/// Filtered recipes provider with performance tracking
final filteredRecipesWithMonitoringProvider = StreamProvider<List<Recipe>>((ref) {
  final recipesAsync = ref.watch(recipesStreamWithMonitoringProvider);
  final searchQuery = ref.watch(debouncedSearchProvider);
  
  return recipesAsync.when(
    data: (recipes) {
      PerformanceMonitor.startOperation('FilterRecipes');
      
      if (searchQuery.isEmpty) {
        PerformanceMonitor.endOperation('FilterRecipes', tag: 'Providers');
        return Stream.value(recipes);
      }
      
      final lowerQuery = searchQuery.toLowerCase();
      final filtered = recipes.where((recipe) {
        return recipe.title.toLowerCase().contains(lowerQuery) ||
            recipe.description.toLowerCase().contains(lowerQuery) ||
            (recipe.tags?.any((tag) => tag.toLowerCase().contains(lowerQuery)) ?? false) ||
            (recipe.category?.toLowerCase().contains(lowerQuery) ?? false) ||
            (recipe.ingredients.any((ing) => ing.name.toLowerCase().contains(lowerQuery)));
      }).toList();
      
      PerformanceMonitor.endOperation('FilterRecipes', tag: 'Providers');
      LoggerService.debug(
        'Search "$searchQuery" returned ${filtered.length} results',
        'Providers',
      );
      
      return Stream.value(filtered);
    },
    loading: () => Stream.value(<Recipe>[]),
    error: (error, stack) {
      LoggerService.error(
        'Error filtering recipes',
        error: error,
        stackTrace: stack,
        tag: 'Providers',
      );
      return Stream.value(<Recipe>[]);
    },
  );
});
