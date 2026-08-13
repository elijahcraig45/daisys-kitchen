import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_keeper/models/ingredient.dart';
import 'package:recipe_keeper/models/recipe.dart';
import 'package:recipe_keeper/models/recipe_step.dart';
import 'package:recipe_keeper/services/recipe_mapper.dart';

Recipe _sampleRecipe() {
  final recipe = Recipe(
    title: 'Cacio e Pepe',
    description: 'Roman pasta with pecorino and black pepper.',
    servings: 2,
    prepTimeMinutes: 5,
    cookTimeMinutes: 15,
    category: 'Main Course',
    cuisine: 'Italian',
    difficulty: DifficultyLevel.easy,
    notes: 'Reserve the pasta water.',
    source: 'https://example.com/cacio-e-pepe',
    tags: ['pasta', 'quick'],
  );

  recipe.ingredients.add(Ingredient(
    name: 'Pecorino Romano',
    amount: '100',
    unit: 'g',
    measurementSystem: MeasurementSystem.metric,
  ));
  recipe.steps.add(RecipeStep(
    stepNumber: 1,
    title: 'Boil',
    description: 'Cook the pasta until al dente.',
    timerSeconds: 480,
  ));

  return recipe;
}

void main() {
  group('RecipeMapper round trip', () {
    test('preserves tags', () {
      final data = RecipeMapper.toFirestore(_sampleRecipe());
      final restored = RecipeMapper.fromFirestore('abc123', data);

      expect(restored.tags, ['pasta', 'quick']);
    });

    test('preserves cuisine and source', () {
      final data = RecipeMapper.toFirestore(_sampleRecipe());
      final restored = RecipeMapper.fromFirestore('abc123', data);

      expect(restored.cuisine, 'Italian');
      expect(restored.source, 'https://example.com/cacio-e-pepe');
    });

    test('preserves scalar fields, ingredients and steps', () {
      final data = RecipeMapper.toFirestore(_sampleRecipe());
      final restored = RecipeMapper.fromFirestore('abc123', data);

      expect(restored.firestoreId, 'abc123');
      expect(restored.title, 'Cacio e Pepe');
      expect(restored.servings, 2);
      expect(restored.prepTimeMinutes, 5);
      expect(restored.difficulty, DifficultyLevel.easy);
      expect(restored.notes, 'Reserve the pasta water.');
      expect(restored.ingredients.single.name, 'Pecorino Romano');
      expect(restored.ingredients.single.measurementSystem,
          MeasurementSystem.metric);
      expect(
          restored.steps.single.description, 'Cook the pasta until al dente.');
      expect(restored.steps.single.timerSeconds, 480);
    });

    test('never writes createdAt, so edits cannot reorder the list', () {
      final data = RecipeMapper.toFirestore(_sampleRecipe());

      expect(data.containsKey('createdAt'), isFalse);
      expect(data.containsKey('updatedAt'), isFalse);
    });
  });

  group('RecipeMapper.fromFirestore tolerance', () {
    test('falls back to defaults on an empty document', () {
      final restored = RecipeMapper.fromFirestore('empty', {});

      expect(restored.title, '');
      expect(restored.servings, 1);
      expect(restored.difficulty, DifficultyLevel.medium);
      expect(restored.isFavorite, isFalse);
      expect(restored.ingredients, isEmpty);
      expect(restored.steps, isEmpty);
    });

    test('reads legacy steps stored under "description"', () {
      final restored = RecipeMapper.fromFirestore('legacy', {
        'steps': [
          {
            'stepNumber': 1,
            'title': 'Mix',
            'description': 'Combine wet and dry.'
          }
        ],
      });

      expect(restored.steps.single.description, 'Combine wet and dry.');
    });

    test('names untitled steps by position', () {
      final restored = RecipeMapper.fromFirestore('untitled', {
        'steps': [
          {'instruction': 'Preheat the oven.'},
          {'instruction': 'Bake for 20 minutes.'},
        ],
      });

      expect(restored.steps.map((s) => s.title), ['Step 1', 'Step 2']);
    });

    test('ignores unusable difficulty and tag values', () {
      final restored = RecipeMapper.fromFirestore('messy', {
        'difficulty': 'impossible',
        'tags': ['ok', 7],
      });

      expect(restored.difficulty, DifficultyLevel.medium);
      expect(restored.tags, ['ok']);
    });
  });
}
