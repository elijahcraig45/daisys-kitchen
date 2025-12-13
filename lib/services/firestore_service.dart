import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recipe_keeper/models/recipe.dart';
import 'package:recipe_keeper/models/ingredient.dart';
import 'package:recipe_keeper/models/recipe_step.dart';

/// Firestore database service for recipes
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get recipes collection reference
  CollectionReference get _recipesCollection =>
      _firestore.collection('recipes');

  /// Get all recipes (real-time stream)
  Stream<List<Recipe>> getRecipesStream() {
    return _recipesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _recipeFromFirestore(doc.id, data);
      }).toList();
    });
  }

  /// Get single recipe by ID
  Future<Recipe?> getRecipeById(String id) async {
    try {
      final doc = await _recipesCollection.doc(id).get();
      if (!doc.exists) return null;
      return _recipeFromFirestore(doc.id, doc.data() as Map<String, dynamic>);
    } catch (e) {
      // ignore: avoid_print
      print('Error getting recipe: $e');
      return null;
    }
  }

  /// Add new recipe
  Future<String?> addRecipe(Recipe recipe) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        // ignore: avoid_print
        print('Error: User must be signed in to add recipes');
        return null;
      }

      final data = _recipeToFirestore(recipe);
      // Add creator information
      data['createdBy'] = user.uid;
      data['createdByEmail'] = user.email;
      data['createdByName'] = user.displayName ?? user.email;

      final docRef = await _recipesCollection.add(data);
      return docRef.id;
    } catch (e) {
      // ignore: avoid_print
      print('Error adding recipe: $e');
      return null;
    }
  }

  /// Update existing recipe
  Future<bool> updateRecipe(String id, Recipe recipe) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        // ignore: avoid_print
        print('Error: User must be signed in to update recipes');
        return false;
      }

      final data = _recipeToFirestore(recipe);
      // Add update information
      data['updatedBy'] = user.uid;
      data['updatedByEmail'] = user.email;
      data['updatedByName'] = user.displayName ?? user.email;

      await _recipesCollection.doc(id).update(data);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Error updating recipe: $e');
      return false;
    }
  }

  /// Delete recipe
  Future<bool> deleteRecipe(String id) async {
    try {
      await _recipesCollection.doc(id).delete();
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Error deleting recipe: $e');
      return false;
    }
  }

  /// Toggle favorite status
  Future<bool> toggleFavorite(String id, bool isFavorite) async {
    try {
      await _recipesCollection.doc(id).update({'isFavorite': isFavorite});
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Error toggling favorite: $e');
      return false;
    }
  }

  /// Convert Recipe to Firestore map
  Map<String, dynamic> _recipeToFirestore(Recipe recipe) {
    return {
      'title': recipe.title,
      'description': recipe.description,
      'prepTimeMinutes': recipe.prepTimeMinutes,
      'cookTimeMinutes': recipe.cookTimeMinutes,
      'servings': recipe.servings,
      'difficulty': recipe.difficulty.name,
      'category': recipe.category,
      'imageUrl': recipe.imageUrl,
      'notes': recipe.notes,
      'isFavorite': recipe.isFavorite,
      'tags': recipe.tags,
      'ingredients': recipe.ingredients
          .map((i) => {
                'name': i.name,
                'amount': i.amount,
                'unit': i.unit,
                'measurementSystem': i.measurementSystem.name,
                'secondaryAmount': i.secondaryAmount,
                'secondaryUnit': i.secondaryUnit,
                'secondarySystem': i.secondarySystem?.name,
              })
          .toList(),
      'steps': recipe.steps
          .map((s) => {
                'stepNumber': s.stepNumber,
                'title': s.title,
                'instruction': s.description,
                'timerSeconds': s.timerSeconds,
                'timerLabel': s.timerLabel,
                'ingredientsForStep': s.ingredientsForStep
                    ?.map((ingredient) => {
                          'name': ingredient.name,
                          'amount': ingredient.amount,
                          'unit': ingredient.unit,
                          'measurementSystem':
                              ingredient.measurementSystem.name,
                          'secondaryAmount': ingredient.secondaryAmount,
                          'secondaryUnit': ingredient.secondaryUnit,
                          'secondarySystem': ingredient.secondarySystem?.name,
                        })
                    .toList(),
              })
          .toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Convert Firestore data to Recipe
  Recipe _recipeFromFirestore(String id, Map<String, dynamic> data) {
    final recipe = Recipe(
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      servings: data['servings'] ?? 1,
    );

    recipe.firestoreId = id;
    recipe.prepTimeMinutes = data['prepTimeMinutes'];
    recipe.cookTimeMinutes = data['cookTimeMinutes'];
    recipe.difficulty = data['difficulty'] != null
        ? DifficultyLevel.values.firstWhere(
            (e) => e.name == data['difficulty'],
            orElse: () => DifficultyLevel.medium,
          )
        : DifficultyLevel.medium;
    recipe.category = data['category'];
    recipe.imageUrl = data['imageUrl'];
    recipe.notes = data['notes'];
    recipe.isFavorite = data['isFavorite'] ?? false;

    // Handle tags
    if (data['tags'] != null) {
      final tags = (data['tags'] as List).cast<String>();
      if (recipe.tags != null) {
        recipe.tags!.addAll(tags);
      }
    }

    // Handle ingredients
    if (data['ingredients'] != null) {
      final ingredients = (data['ingredients'] as List).map((i) {
        return Ingredient(
          name: i['name'] ?? '',
          amount: i['amount'] ?? '',
          unit: i['unit'],
          measurementSystem: i['measurementSystem'] != null
              ? MeasurementSystem.values.firstWhere(
                  (system) => system.name == i['measurementSystem'],
                  orElse: () => MeasurementSystem.customary,
                )
              : MeasurementSystem.customary,
          secondaryAmount: i['secondaryAmount'],
          secondaryUnit: i['secondaryUnit'],
          secondarySystem: i['secondarySystem'] != null
              ? MeasurementSystem.values.firstWhere(
                  (system) => system.name == i['secondarySystem'],
                  orElse: () => MeasurementSystem.metric,
                )
              : null,
        );
      }).toList();
      recipe.ingredients.addAll(ingredients);
    }

    // Handle steps
    if (data['steps'] != null) {
      final steps = (data['steps'] as List).map((s) {
        final step = RecipeStep(
          stepNumber: s['stepNumber'] ?? 0,
          title: (s['title'] ?? '').toString(),
          description: (s['instruction'] ?? s['description'])?.toString(),
        )
          ..timerSeconds = s['timerSeconds']
          ..timerLabel = s['timerLabel'];

        if (s['ingredientsForStep'] != null) {
          final stepIngredients = (s['ingredientsForStep'] as List).map((i) {
            return Ingredient(
              name: i['name'] ?? '',
              amount: i['amount'] ?? '',
              unit: i['unit'],
              measurementSystem: i['measurementSystem'] != null
                  ? MeasurementSystem.values.firstWhere(
                      (system) => system.name == i['measurementSystem'],
                      orElse: () => MeasurementSystem.customary,
                    )
                  : MeasurementSystem.customary,
              secondaryAmount: i['secondaryAmount'],
              secondaryUnit: i['secondaryUnit'],
              secondarySystem: i['secondarySystem'] != null
                  ? MeasurementSystem.values.firstWhere(
                      (system) => system.name == i['secondarySystem'],
                      orElse: () => MeasurementSystem.metric,
                    )
                  : null,
            );
          }).toList();
          step.ingredientsForStep = stepIngredients;
        }
        if (step.title.isEmpty) {
          final displayNumber =
              step.stepNumber == 0 ? recipe.steps.length + 1 : step.stepNumber;
          step.title = 'Step $displayNumber';
        }
        return step;
      }).toList();
      recipe.steps.addAll(steps);
    }

    return recipe;
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
