import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gemini_service.dart';
import '../models/recipe.dart';

/// Provider for Gemini AI service
final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

/// Whether this user may use AI features.
///
/// Async because permission is a property of the signed-in account read from
/// Firestore, not of a key sitting in the client. Only a hint for the UI — the
/// binding decision is made server-side by the geminiProxy function.
final isGeminiEnabledProvider = FutureProvider<bool>((ref) async {
  final geminiService = ref.watch(geminiServiceProvider);
  return geminiService.isAllowed;
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
