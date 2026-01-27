import 'package:recipe_keeper/models/recipe.dart';
import 'package:recipe_keeper/services/logger_service.dart';

/// Simple in-memory cache for recipes
/// Reduces Firestore reads and improves performance
class RecipeCache {
  static final RecipeCache _instance = RecipeCache._internal();
  factory RecipeCache() => _instance;
  RecipeCache._internal();

  final Map<String, Recipe> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// Add or update a recipe in cache
  void put(String id, Recipe recipe) {
    _cache[id] = recipe;
    _cacheTimestamps[id] = DateTime.now();
    LoggerService.debug('Recipe cached: $id', 'Cache');
  }

  /// Get a recipe from cache
  Recipe? get(String id) {
    final timestamp = _cacheTimestamps[id];
    
    // Check if cache entry exists and is not expired
    if (timestamp == null) {
      return null;
    }
    
    final age = DateTime.now().difference(timestamp);
    if (age > _cacheExpiry) {
      // Cache expired
      _cache.remove(id);
      _cacheTimestamps.remove(id);
      LoggerService.debug('Cache expired for: $id', 'Cache');
      return null;
    }
    
    LoggerService.debug('Cache hit for: $id', 'Cache');
    return _cache[id];
  }

  /// Remove a recipe from cache
  void remove(String id) {
    _cache.remove(id);
    _cacheTimestamps.remove(id);
    LoggerService.debug('Recipe removed from cache: $id', 'Cache');
  }

  /// Clear all cached recipes
  void clear() {
    final count = _cache.length;
    _cache.clear();
    _cacheTimestamps.clear();
    LoggerService.info('Cache cleared: $count recipes', 'Cache');
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    final now = DateTime.now();
    int expired = 0;
    
    for (final entry in _cacheTimestamps.entries) {
      final age = now.difference(entry.value);
      if (age > _cacheExpiry) {
        expired++;
      }
    }
    
    return {
      'total': _cache.length,
      'valid': _cache.length - expired,
      'expired': expired,
    };
  }

  /// Cleanup expired entries
  void cleanup() {
    final now = DateTime.now();
    final expired = <String>[];
    
    for (final entry in _cacheTimestamps.entries) {
      final age = now.difference(entry.value);
      if (age > _cacheExpiry) {
        expired.add(entry.key);
      }
    }
    
    for (final id in expired) {
      _cache.remove(id);
      _cacheTimestamps.remove(id);
    }
    
    if (expired.isNotEmpty) {
      LoggerService.debug('Cleaned up ${expired.length} expired cache entries', 'Cache');
    }
  }
}
