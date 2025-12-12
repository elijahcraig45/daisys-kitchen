import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_keeper/models/recipe.dart';
import 'package:recipe_keeper/screens/home_screen.dart';
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
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            '404 - Recipe Not Found',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
