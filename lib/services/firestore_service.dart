import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recipe_keeper/models/recipe.dart';
import 'package:recipe_keeper/services/logger_service.dart';
import 'package:recipe_keeper/services/recipe_cache.dart';
import 'package:recipe_keeper/services/recipe_mapper.dart';
import 'package:recipe_keeper/utils/retry_helper.dart';

/// Firestore database service for recipes with enhanced error handling, caching, and retries
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RecipeCache _cache = RecipeCache();

  /// Get recipes collection reference
  CollectionReference get _recipesCollection =>
      _firestore.collection('recipes');

  /// Get all recipes (real-time stream) with error handling
  Stream<List<Recipe>> getRecipesStream() {
    return _recipesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error, stackTrace) {
      LoggerService.error(
        'Error in recipes stream',
        error: error,
        stackTrace: stackTrace,
        tag: 'Firestore',
      );
    }).map((snapshot) {
      try {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return RecipeMapper.fromFirestore(doc.id, data);
        }).toList();
      } catch (e, stackTrace) {
        LoggerService.error(
          'Error mapping recipe documents',
          error: e,
          stackTrace: stackTrace,
          tag: 'Firestore',
        );
        return <Recipe>[];
      }
    });
  }

  /// Get single recipe by ID with error handling and caching
  Future<Recipe?> getRecipeById(String id) async {
    // Check cache first
    final cached = _cache.get(id);
    if (cached != null) {
      return cached;
    }

    try {
      LoggerService.debug('Fetching recipe from Firestore: $id', 'Firestore');
      
      final recipe = await RetryHelper.retry(
        operation: () async {
          final doc = await _recipesCollection.doc(id).get();
          if (!doc.exists) {
            LoggerService.warning('Recipe not found: $id', 'Firestore');
            return null;
          }
          final recipe = RecipeMapper.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
          
          // Cache the result
          _cache.put(id, recipe);
          
          return recipe;
        },
        operationName: 'getRecipeById',
        maxAttempts: 2,
        tag: 'Firestore',
      );
      
      return recipe;
    } on FirebaseException catch (e) {
      LoggerService.error(
        'Firebase error getting recipe: ${e.code}',
        error: e,
        tag: 'Firestore',
      );
      return null;
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error getting recipe',
        error: e,
        stackTrace: stackTrace,
        tag: 'Firestore',
      );
      return null;
    }
  }

  /// Add new recipe with validation and error handling
  Future<String?> addRecipe(Recipe recipe) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        LoggerService.warning('Attempted to add recipe without authentication', 'Firestore');
        return null;
      }

      LoggerService.info('Adding recipe: ${recipe.title}', 'Firestore');

      final data = RecipeMapper.toFirestore(recipe);
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      data['createdBy'] = user.uid;
      data['createdByEmail'] = user.email;
      data['createdByName'] = user.displayName ?? user.email;

      final docRef = await _recipesCollection.add(data);
      LoggerService.success('Recipe added: ${docRef.id}', 'Firestore');
      return docRef.id;
    } on FirebaseException catch (e) {
      LoggerService.error(
        'Firebase error adding recipe: ${e.code}',
        error: e,
        tag: 'Firestore',
      );
      return null;
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error adding recipe',
        error: e,
        stackTrace: stackTrace,
        tag: 'Firestore',
      );
      return null;
    }
  }

  /// Update existing recipe with validation and error handling
  Future<bool> updateRecipe(String id, Recipe recipe) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        LoggerService.warning('Attempted to update recipe without authentication', 'Firestore');
        return false;
      }

      LoggerService.info('Updating recipe: $id', 'Firestore');

      // createdAt is deliberately absent: the stream orders by it, so restamping
      // it on every edit would shuffle the recipe back to the top of the list.
      final data = RecipeMapper.toFirestore(recipe);
      data['updatedAt'] = FieldValue.serverTimestamp();
      data['updatedBy'] = user.uid;
      data['updatedByEmail'] = user.email;
      data['updatedByName'] = user.displayName ?? user.email;

      await _recipesCollection.doc(id).update(data);
      _cache.remove(id);
      LoggerService.success('Recipe updated: $id', 'Firestore');
      return true;
    } on FirebaseException catch (e) {
      LoggerService.error(
        'Firebase error updating recipe: ${e.code}',
        error: e,
        tag: 'Firestore',
      );
      return false;
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error updating recipe',
        error: e,
        stackTrace: stackTrace,
        tag: 'Firestore',
      );
      return false;
    }
  }

  /// Delete recipe with error handling and cache invalidation
  Future<bool> deleteRecipe(String id) async {
    try {
      LoggerService.info('Deleting recipe: $id', 'Firestore');
      
      await RetryHelper.retry(
        operation: () async {
          await _recipesCollection.doc(id).delete();
        },
        operationName: 'deleteRecipe',
        maxAttempts: 2,
        tag: 'Firestore',
      );
      
      // Remove from cache
      _cache.remove(id);
      
      LoggerService.success('Recipe deleted: $id', 'Firestore');
      return true;
    } on FirebaseException catch (e) {
      LoggerService.error(
        'Firebase error deleting recipe: ${e.code}',
        error: e,
        tag: 'Firestore',
      );
      return false;
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error deleting recipe',
        error: e,
        stackTrace: stackTrace,
        tag: 'Firestore',
      );
      return false;
    }
  }

  /// Toggle favorite status with error handling
  Future<bool> toggleFavorite(String id, bool isFavorite) async {
    try {
      await _recipesCollection.doc(id).update({'isFavorite': isFavorite});
      LoggerService.debug('Favorite toggled for: $id', 'Firestore');
      return true;
    } on FirebaseException catch (e) {
      LoggerService.error(
        'Firebase error toggling favorite: ${e.code}',
        error: e,
        tag: 'Firestore',
      );
      return false;
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error toggling favorite',
        error: e,
        stackTrace: stackTrace,
        tag: 'Firestore',
      );
      return false;
    }
  }


  /// Import recipes from JSON (bulk add)
  Future<int> importRecipes(List<Recipe> recipes) async {
    int count = 0;
    for (final recipe in recipes) {
      final id = await addRecipe(recipe);
      if (id != null) count++;
    }
    return count;
  }

  /// Export all recipes to JSON-compatible format
  Future<List<Map<String, dynamic>>> exportRecipes() async {
    final snapshot = await _recipesCollection.get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      // Remove Firestore-specific fields
      data.remove('createdAt');
      data.remove('updatedAt');
      return data;
    }).toList();
  }
}
