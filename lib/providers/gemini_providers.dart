import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gemini_service.dart';
import '../models/recipe.dart';

/// Provider for Gemini AI service
final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

/// Provider to check if Gemini is enabled and configured
final isGeminiEnabledProvider = Provider<bool>((ref) {
  final geminiService = ref.watch(geminiServiceProvider);
  return geminiService.isEnabled;
});

/// Provider for verifying and cleaning a recipe
final verifyRecipeProvider = FutureProvider.family<Recipe?, Recipe>((ref, recipe) async {
  final geminiService = ref.watch(geminiServiceProvider);
  return await geminiService.verifyAndCleanRecipe(recipe);
});

/// Provider for extracting recipe from URL
final extractRecipeFromUrlProvider = FutureProvider.family<Recipe?, String>((ref, url) async {
  final geminiService = ref.watch(geminiServiceProvider);
  return await geminiService.extractRecipeFromUrl(url);
});

/// Provider for extracting recipe from pasted text
final extractRecipeFromTextProvider = FutureProvider.family<Recipe?, String>((ref, text) async {
  final geminiService = ref.watch(geminiServiceProvider);
  return await geminiService.extractRecipeFromText(text);
});
