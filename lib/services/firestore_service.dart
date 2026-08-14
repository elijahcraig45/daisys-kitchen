import 'dart:async';

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

  /// Every recipe this viewer is allowed to see, as one stream.
  ///
  /// Three constrained queries merged here rather than one query over the collection.
  /// Security rules do not filter: Firestore rejects any query that *could* return a
  /// document the reader may not read, so an unfiltered `orderBy('createdAt')` — which
  /// is what this used to be — fails outright rather than returning less. Each scope
  /// below is provably readable, which is what makes it allowed.
  ///
  /// Also the cheap shape: a signed-out visitor runs one query for public recipes and
  /// reads nothing else.
  Stream<List<Recipe>> getRecipesStream() {
    return _auth.authStateChanges().asyncExpand((user) {
      final public = _scoped('visibility', 'public');
      if (user == null) return public;

      // The household id has to be read before the household query can be built, and it
      // changes when someone joins or leaves, so it is watched rather than read once.
      final householdIds = _firestore
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((snap) => snap.data()?['householdId'] as String?)
          .distinct();

      return _switchLatest(householdIds, (String? householdId) {
        return _mergeById([
          public,
          _scoped('createdBy', user.uid),
          if (householdId != null) _scoped('householdId', householdId),
        ]);
      });
    });
  }

  /// One scope of the recipe collection, ordered newest first.
  Stream<List<Recipe>> _scoped(String field, String value) {
    return _recipesCollection
        .where(field, isEqualTo: value)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error, stackTrace) {
      LoggerService.error(
        'Error in recipes stream ($field)',
        error: error,
        stackTrace: stackTrace,
        tag: 'Firestore',
      );
    }).map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) =>
                RecipeMapper.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
            .toList();
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

  /// Re-subscribes to a new inner stream each time the outer one emits, dropping the
  /// previous subscription.
  ///
  /// `asyncExpand` cannot do this: it waits for each inner stream to finish, and a
  /// Firestore snapshot stream never does, so the household query would never switch
  /// when someone joins or leaves. rxdart has `switchMap`, but this is the only place
  /// that needs it and a dependency for one operator is not worth carrying.
  Stream<T> _switchLatest<S, T>(Stream<S> outer, Stream<T> Function(S) select) {
    final controller = StreamController<T>();
    StreamSubscription<S>? outerSub;
    StreamSubscription<T>? innerSub;

    controller.onListen = () {
      outerSub = outer.listen((value) async {
        await innerSub?.cancel();
        innerSub = select(value).listen(
          controller.add,
          onError: controller.addError,
        );
      }, onError: controller.addError);
    };
    controller.onCancel = () async {
      await innerSub?.cancel();
      await outerSub?.cancel();
    };

    return controller.stream;
  }

  /// Combines the scopes, keeping one copy of anything that appears in more than one —
  /// a public recipe you wrote arrives from two of them.
  Stream<List<Recipe>> _mergeById(List<Stream<List<Recipe>>> streams) {
    final latest = List<List<Recipe>>.filled(streams.length, const <Recipe>[]);
    final controller = StreamController<List<Recipe>>();
    final subs = <StreamSubscription<List<Recipe>>>[];

    void emit() {
      final byId = <String, Recipe>{};
      for (final batch in latest) {
        for (final recipe in batch) {
          final id = recipe.firestoreId;
          if (id != null) byId[id] = recipe;
        }
      }
      final merged = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!controller.isClosed) controller.add(merged);
    }

    controller.onListen = () {
      for (var i = 0; i < streams.length; i++) {
        final index = i;
        subs.add(streams[index].listen((batch) {
          latest[index] = batch;
          emit();
        }, onError: (Object e) {
          LoggerService.error('Recipe scope failed', error: e, tag: 'Firestore');
        }));
      }
    };
    controller.onCancel = () async {
      for (final sub in subs) {
        await sub.cancel();
      }
    };

    return controller.stream;
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
      // No createdByEmail: recipes are world-readable, so writing an address here
      // published it. Attribution is by display name.
      data['createdByName'] = user.displayName ?? 'Someone';

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

  /// Toggle a favourite for the signed-in user.
  ///
  /// Writes to users/{uid}/favorites rather than the recipe document. It used to set an
  /// `isFavorite` flag on the recipe itself, which made it shared state: one person
  /// favouriting something marked it for everyone, and the rules needed a carve-out
  /// letting any signed-in user write any recipe in order to allow it.
  Future<bool> toggleFavorite(String id, bool isFavorite) async {
    final user = _auth.currentUser;
    if (user == null) {
      LoggerService.warning('Cannot favourite while signed out', 'Firestore');
      return false;
    }
    try {
      final ref = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(id);
      if (isFavorite) {
        await ref.set({'addedAt': FieldValue.serverTimestamp()});
      } else {
        await ref.delete();
      }
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


  /// The signed-in user's favourite recipe ids.
  ///
  /// Empty for a signed-out visitor, which is correct: favourites are personal, so
  /// there is nothing to show rather than everyone's.
  Stream<Set<String>> watchFavoriteIds() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(<String>{});
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .snapshots()
          .map((snap) => snap.docs.map((d) => d.id).toSet());
    });
  }

  /// Recipe ids the signed-in user has saved from the community.
  ///
  /// A save is a reference, not a copy, so the author's later corrections are what the
  /// reader sees. It becomes a copy the moment they edit it — see [forkForEditing].
  Stream<Set<String>> watchSavedRecipeIds() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(<String>{});
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('savedRecipes')
          .snapshots()
          .map((snap) => snap.docs.map((d) => d.id).toSet());
    });
  }

  /// Save or unsave a community recipe.
  Future<bool> setSaved(Recipe recipe, bool saved) async {
    final user = _auth.currentUser;
    final id = recipe.firestoreId;
    if (user == null || id == null) return false;
    try {
      final ref = _firestore
          .collection('users').doc(user.uid)
          .collection('savedRecipes').doc(id);
      if (saved) {
        await ref.set({
          'savedAt': FieldValue.serverTimestamp(),
          'authorUid': recipe.createdBy,
          'authorName': recipe.createdByName,
        });
      } else {
        await ref.delete();
      }
      return true;
    } catch (e) {
      LoggerService.error('Could not change saved state', error: e, tag: 'Firestore');
      return false;
    }
  }

  /// Copies someone else's recipe so the signed-in user can edit their own version.
  ///
  /// Returns the new id. The original is untouched: the rules would refuse a write to it
  /// anyway, and quietly editing a stranger's recipe is not what "edit" should mean. The
  /// copy starts private — republishing someone else's work without being asked is not a
  /// decision this should make on the user's behalf.
  Future<String?> forkForEditing(Recipe original) async {
    final user = _auth.currentUser;
    if (user == null || original.firestoreId == null) return null;
    try {
      final data = RecipeMapper.toFirestore(original);
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      data['createdBy'] = user.uid;
      data['createdByName'] = user.displayName ?? 'Someone';
      data['forkedFrom'] = original.firestoreId;
      data['visibility'] = 'private';
      data['householdId'] = null;

      final docRef = await _recipesCollection.add(data);
      // The reference is replaced by the copy, so the shelf shows one of them.
      await setSaved(original, false);
      LoggerService.success('Forked ${original.title} -> ${docRef.id}', 'Firestore');
      return docRef.id;
    } catch (e) {
      LoggerService.error('Could not fork recipe', error: e, tag: 'Firestore');
      return null;
    }
  }

  /// Reports a public recipe for an admin to look at.
  ///
  /// The reporter is recorded so a report can be traced, and the rules make reports
  /// readable only by admins so an author never learns who reported them.
  Future<bool> reportRecipe(String recipeId, String reason) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await _firestore.collection('reports').add({
        'recipeId': recipeId,
        'reportedBy': user.uid,
        'reason': reason.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      LoggerService.error('Could not file report', error: e, tag: 'Firestore');
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
