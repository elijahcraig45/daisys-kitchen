import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_keeper/models/recipe.dart';
import 'package:recipe_keeper/screens/home_screen.dart';
import 'package:recipe_keeper/screens/grocery_screen.dart';
import 'package:recipe_keeper/screens/household_screen.dart';
import 'package:recipe_keeper/screens/privacy_screen.dart';
import 'package:recipe_keeper/screens/recipe_detail_screen.dart';
import 'package:recipe_keeper/screens/recipe_editor_screen.dart';
import 'package:recipe_keeper/screens/cooking_mode_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/groceries',
      name: 'groceries',
      builder: (context, state) => const GroceryScreen(),
    ),
    GoRoute(
      path: '/privacy',
      name: 'privacy',
      builder: (context, state) => const PrivacyScreen(),
    ),
    GoRoute(
      path: '/household',
      name: 'household',
      builder: (context, state) => const HouseholdScreen(),
    ),
    GoRoute(
      path: '/recipe/new',
      name: 'recipe-new',
      builder: (context, state) => const RecipeEditorScreen(),
    ),
    GoRoute(
      path: '/recipe/:id/edit',
      name: 'recipe-edit',
      builder: (context, state) {
        final recipe = state.extra as Recipe?;
        return RecipeEditorScreen(recipe: recipe);
      },
    ),
    GoRoute(
      path: '/recipe/:id',
      name: 'recipe-detail',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final recipe = state.extra as Recipe?;
        return RecipeDetailScreen(recipeId: id, recipe: recipe);
      },
    ),
    GoRoute(
      path: '/recipe/:id/cook',
      name: 'cooking-mode',
      builder: (context, state) {
        final recipe = state.extra as Recipe;
        return CookingModeScreen(recipe: recipe);
      },
    ),
    GoRoute(
      path: '/category/:category',
      name: 'category',
      builder: (context, state) {
        final category = state.pathParameters['category']!;
        return HomeScreen(initialCategory: category);
      },
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Page Not Found')),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'Recipe not found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/'),
            child: const Text('Back to Recipes'),
          ),
        ],
      ),
    ),
  ),
);
