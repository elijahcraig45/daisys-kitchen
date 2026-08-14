import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:recipe_keeper/models/ingredient.dart';
import 'package:recipe_keeper/models/recipe.dart';
import 'package:recipe_keeper/models/recipe_step.dart';

/// Translates between [Recipe] and its Firestore document shape.
///
/// Deliberately free of Firebase singletons and server timestamps so it can be
/// unit tested; [FirestoreService] stamps the timestamps and authorship fields.
class RecipeMapper {
  const RecipeMapper._();

  static Map<String, dynamic> toFirestore(Recipe recipe) {
    return {
      'title': recipe.title,
      'description': recipe.description,
      'prepTimeMinutes': recipe.prepTimeMinutes,
      'cookTimeMinutes': recipe.cookTimeMinutes,
      'servings': recipe.servings,
      'difficulty': recipe.difficulty.name,
      'category': recipe.category,
      'cuisine': recipe.cuisine,
      'imageUrl': recipe.imageUrl,
      'notes': recipe.notes,
      'source': recipe.source,
      'tags': recipe.tags ?? <String>[],
      'ingredients': recipe.ingredients.map(_ingredientToMap).toList(),
      'steps': recipe.steps.map(_stepToMap).toList(),
      // isFavorite is deliberately absent: favourites are per-user and live in
      // users/{uid}/favorites, so writing one here would set it for everybody.
      'visibility': _visibility(recipe.visibility),
      'householdId': recipe.visibility == 'household' ? recipe.householdId : null,
      'forkedFrom': recipe.forkedFrom,
    };
  }

  static const Set<String> _visibilities = {'public', 'household', 'private'};

  /// Falls back to `private`, which is the safe direction: a value we cannot read
  /// should hide a recipe rather than publish it.
  static String _visibility(Object? raw) =>
      raw is String && _visibilities.contains(raw) ? raw : 'private';

  static Recipe fromFirestore(String id, Map<String, dynamic> data) {
    final recipe = Recipe(
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      servings: data['servings'] as int? ?? 1,
      tags: _stringList(data['tags']),
    );

    recipe.firestoreId = id;
    recipe.prepTimeMinutes = data['prepTimeMinutes'] as int?;
    recipe.cookTimeMinutes = data['cookTimeMinutes'] as int?;
    recipe.difficulty = _enumByName(
      DifficultyLevel.values,
      data['difficulty'],
      DifficultyLevel.medium,
    );
    recipe.category = data['category'] as String?;
    recipe.cuisine = data['cuisine'] as String?;
    recipe.imageUrl = data['imageUrl'] as String?;
    recipe.notes = data['notes'] as String?;
    recipe.source = data['source'] as String?;
    // Unrecognised or missing visibility reads as private, never public.
    recipe.visibility = _visibility(data['visibility']);
    recipe.householdId = data['householdId'] as String?;
    recipe.forkedFrom = data['forkedFrom'] as String?;
    recipe.createdAt = _dateTime(data['createdAt']) ?? recipe.createdAt;
    recipe.updatedAt = _dateTime(data['updatedAt']) ?? recipe.updatedAt;

    final ingredients = data['ingredients'];
    if (ingredients is List) {
      recipe.ingredients.addAll(ingredients.map(_ingredientFromMap));
    }

    final steps = data['steps'];
    if (steps is List) {
      var position = 0;
      for (final raw in steps) {
        position++;
        recipe.steps.add(_stepFromMap(raw, position));
      }
    }

    return recipe;
  }

  static Map<String, dynamic> _ingredientToMap(Ingredient ingredient) {
    return {
      'name': ingredient.name,
      'amount': ingredient.amount,
      'unit': ingredient.unit,
      'notes': ingredient.notes,
      'measurementSystem': ingredient.measurementSystem.name,
      'secondaryAmount': ingredient.secondaryAmount,
      'secondaryUnit': ingredient.secondaryUnit,
      'secondarySystem': ingredient.secondarySystem?.name,
    };
  }

  static Ingredient _ingredientFromMap(dynamic raw) {
    final map = raw is Map ? raw : const {};
    return Ingredient(
      name: map['name'] as String? ?? '',
      amount: map['amount'] as String? ?? '',
      unit: map['unit'] as String?,
      notes: map['notes'] as String?,
      measurementSystem: _enumByName(
        MeasurementSystem.values,
        map['measurementSystem'],
        MeasurementSystem.customary,
      ),
      secondaryAmount: map['secondaryAmount'] as String?,
      secondaryUnit: map['secondaryUnit'] as String?,
      secondarySystem: map['secondarySystem'] == null
          ? null
          : _enumByName(
              MeasurementSystem.values,
              map['secondarySystem'],
              MeasurementSystem.metric,
            ),
    );
  }

  static Map<String, dynamic> _stepToMap(RecipeStep step) {
    return {
      'stepNumber': step.stepNumber,
      'title': step.title,
      'instruction': step.description,
      'timerSeconds': step.timerSeconds,
      'timerLabel': step.timerLabel,
      'ingredientsForStep':
          step.ingredientsForStep?.map(_ingredientToMap).toList(),
    };
  }

  static RecipeStep _stepFromMap(dynamic raw, int position) {
    final map = raw is Map ? raw : const {};
    final stepNumber = map['stepNumber'] as int? ?? position;
    final step = RecipeStep(
      stepNumber: stepNumber == 0 ? position : stepNumber,
      title: map['title'] as String? ?? '',
      // Older documents stored the description under "description".
      description: (map['instruction'] ?? map['description']) as String?,
      timerSeconds: map['timerSeconds'] as int?,
      timerLabel: map['timerLabel'] as String?,
    );

    final stepIngredients = map['ingredientsForStep'];
    if (stepIngredients is List) {
      step.ingredientsForStep =
          stepIngredients.map(_ingredientFromMap).toList();
    }

    if (step.title.isEmpty) {
      step.title = 'Step ${step.stepNumber}';
    }

    return step;
  }

  static List<String>? _stringList(dynamic raw) {
    if (raw is! List) return null;
    return raw.whereType<String>().toList();
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    dynamic name,
    T fallback,
  ) {
    if (name is! String) return fallback;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  static DateTime? _dateTime(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}
