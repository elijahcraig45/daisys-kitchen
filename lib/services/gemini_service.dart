import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'logger_service.dart';
import 'remote_config_service.dart';
import '../models/recipe.dart';
import '../models/ingredient.dart';
import '../models/recipe_step.dart';

/// Service for interacting with Google's Gemini API
/// Provides AI-powered recipe verification, cleanup, and extraction
class GeminiService {
  /// Whether this user may use AI features.
  ///
  /// Only a hint for the UI, so a feature can be hidden rather than offered and
  /// refused — the decision that matters is made by the `geminiProxy` function
  /// against the caller's verified uid. There is deliberately no API key here to
  /// check: it lives in Secret Manager, because Remote Config is delivered to every
  /// client and a key kept there is public.
  Future<bool> get isAllowed async {
    if (!RemoteConfigService.instance.geminiEnabled) return false;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      return snap.data()?['aiEnabled'] == true;
    } catch (e) {
      LoggerService.warning('Could not read AI permission', 'GeminiService');
      return false;
    }
  }

  /// Get the model name from Remote Config
  String get _model => RemoteConfigService.instance.geminiModel;
  
  /// Verify and clean up a recipe
  /// Fixes grammatical errors and adds both customary and metric units
  Future<Recipe?> verifyAndCleanRecipe(Recipe recipe) async {
    try {
      LoggerService.info('Sending recipe "${recipe.title}" to Gemini for verification', 'GeminiService');
      
      final prompt = _buildVerificationPrompt(recipe);
      final response = await _callGemini(prompt);
      
      if (response == null) return recipe;
      
      final cleanedRecipe = _parseRecipeResponse(response, recipe);
      LoggerService.success('Recipe verified and cleaned successfully', 'GeminiService');
      
      return cleanedRecipe;
    } catch (e) {
      LoggerService.error('Failed to verify recipe', error: e, tag: 'GeminiService');
      return recipe; // Return original on error
    }
  }
  
  /// Extract recipe from a URL
  /// Works with both print-friendly and regular website URLs
  Future<Recipe?> extractRecipeFromUrl(String url) async {
    try {
      LoggerService.info('Extracting recipe from URL: $url', 'GeminiService');
      
      final prompt = '''
You are a recipe extraction expert. Extract the recipe from this URL: $url

Return the recipe in the following JSON format:
{
  "title": "Recipe Title",
  "description": "Brief description",
  "servings": 4,
  "prepTime": 15,
  "cookTime": 30,
  "category": "Main Course",
  "ingredients": [
    {
      "name": "ingredient name",
      "amount": "1",
      "unit": "cup (240ml)",
      "notes": "optional notes"
    }
  ],
  "steps": [
    {
      "order": 1,
      "instruction": "Step instruction",
      "time": 5
    }
  ],
  "notes": "Additional notes",
  "tags": ["tag1", "tag2"]
}

Important:
- Include BOTH customary and metric units in the unit field (e.g., "1 cup (240ml)", "350°F (175°C)")
- Fix any grammatical errors
- Preserve the original recipe's style and tone
- If you cannot access the URL, return null
''';
      
      final response = await _callGemini(prompt);
      
      if (response == null) return null;
      
      final recipe = _parseRecipeFromJson(response);
      LoggerService.success('Recipe extracted from URL successfully', 'GeminiService');
      
      return recipe;
    } catch (e) {
      LoggerService.error('Failed to extract recipe from URL', error: e, tag: 'GeminiService');
      return null;
    }
  }
  
  /// Extract recipe from pasted text
  /// Useful for recipes copied from websites or documents
  Future<Recipe?> extractRecipeFromText(String text) async {
    try {
      LoggerService.info('Extracting recipe from pasted text', 'GeminiService');
      
      final prompt = '''
You are a recipe extraction expert. Extract and clean up this recipe text:

$text

Return the recipe in the following JSON format:
{
  "title": "Recipe Title",
  "description": "Brief description",
  "servings": 4,
  "prepTime": 15,
  "cookTime": 30,
  "category": "Main Course",
  "ingredients": [
    {
      "name": "ingredient name",
      "amount": "1",
      "unit": "cup (240ml)",
      "notes": "optional notes"
    }
  ],
  "steps": [
    {
      "order": 1,
      "instruction": "Step instruction",
      "time": 5
    }
  ],
  "notes": "Additional notes",
  "tags": ["tag1", "tag2"]
}

Important:
- Include BOTH customary and metric units in the unit field (e.g., "1 cup (240ml)", "350°F (175°C)")
- Fix any grammatical errors
- Preserve the original recipe's style and tone
- Extract servings, prep time, and cook time if mentioned
''';
      
      final response = await _callGemini(prompt);
      
      if (response == null) return null;
      
      final recipe = _parseRecipeFromJson(response);
      LoggerService.success('Recipe extracted from text successfully', 'GeminiService');
      
      return recipe;
    } catch (e) {
      LoggerService.error('Failed to extract recipe from text', error: e, tag: 'GeminiService');
      return null;
    }
  }
  
  /// Build prompt for recipe verification
  String _buildVerificationPrompt(Recipe recipe) {
    final recipeJson = {
      'title': recipe.title,
      'description': recipe.description,
      'servings': recipe.servings,
      'prepTime': recipe.prepTimeMinutes,
      'cookTime': recipe.cookTimeMinutes,
      'category': recipe.category,
      'ingredients': recipe.ingredients.map((i) => {
        'name': i.name,
        'amount': i.amount,
        'unit': i.unit,
        'notes': i.notes,
      }).toList(),
      'steps': recipe.steps.map((s) => {
        'stepNumber': s.stepNumber,
        'instruction': s.description,
        'timerSeconds': s.timerSeconds,
      }).toList(),
      'notes': recipe.notes,
      'tags': recipe.tags,
    };
    
    return '''
You are a recipe verification and enhancement expert. Review this recipe and:
1. Fix any grammatical errors in the recipe text
2. Add both customary and metric units to ALL measurements (e.g., "1 cup (240ml)", "350°F (175°C)")
3. Ensure consistency in formatting
4. Keep the original recipe's style and tone

Recipe to verify:
${json.encode(recipeJson)}

Return the improved recipe in the same JSON format. Include BOTH customary and metric units in the unit field.
''';
  }
  
  /// Send a prompt to Gemini through the `geminiProxy` function.
  ///
  /// Never calls generativelanguage.googleapis.com directly. It used to, with the key
  /// taken from Remote Config and placed in the query string — which meant every
  /// visitor to the site was handed a working key. The key now stays server-side and
  /// this sends only the prompt.
  Future<String?> _callGemini(String prompt) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('geminiProxy');
      final result = await callable.call<Map<String, dynamic>>({
        'prompt': prompt,
        'model': _model,
      });
      return result.data['text'] as String?;
    } on FirebaseFunctionsException catch (e) {
      // permission-denied is the expected answer for an account that isn't on the
      // allowlist, so it is not an error worth shouting about.
      if (e.code == 'permission-denied' || e.code == 'unauthenticated') {
        LoggerService.info('AI features are not enabled for this account', 'GeminiService');
      } else {
        LoggerService.error('Gemini proxy error: ${e.code}', error: e, tag: 'GeminiService');
      }
      return null;
    } catch (e) {
      LoggerService.error('Failed to call Gemini', error: e, tag: 'GeminiService');
      return null;
    }
  }
  
  /// Parse recipe response from Gemini
  Recipe _parseRecipeResponse(String response, Recipe original) {
    try {
      // Extract JSON from response (Gemini sometimes wraps it in markdown)
      String jsonStr = response;
      if (response.contains('```json')) {
        jsonStr = response.split('```json')[1].split('```')[0].trim();
      } else if (response.contains('```')) {
        jsonStr = response.split('```')[1].split('```')[0].trim();
      }
      
      return _parseRecipeFromJson(jsonStr, fallback: original);
    } catch (e) {
      LoggerService.error('Failed to parse Gemini response', error: e, tag: 'GeminiService');
      return original;
    }
  }
  
  /// Parse recipe from JSON response
  Recipe _parseRecipeFromJson(String jsonStr, {Recipe? fallback}) {
    try {
      // Extract JSON from response (Gemini sometimes wraps it in markdown)
      String cleanJson = jsonStr;
      if (jsonStr.contains('```json')) {
        cleanJson = jsonStr.split('```json')[1].split('```')[0].trim();
      } else if (jsonStr.contains('```')) {
        cleanJson = jsonStr.split('```')[1].split('```')[0].trim();
      }
      
      final data = json.decode(cleanJson);
      
      final recipe = Recipe(
        title: data['title'] ?? 'Untitled Recipe',
        description: data['description'] ?? '',
        servings: data['servings'] ?? 4,
        prepTimeMinutes: data['prepTime'] ?? 0,
        cookTimeMinutes: data['cookTime'] ?? 0,
        category: data['category'] ?? 'Other',
        notes: data['notes'],
        tags: (data['tags'] as List?)?.map((t) => t.toString()).toList(),
        isFavorite: fallback?.isFavorite ?? false,
      );
      
      // Set ingredients and steps after construction
      if (data['ingredients'] != null) {
        recipe.ingredients.addAll(
          (data['ingredients'] as List).map((i) => Ingredient(
            name: i['name'] ?? '',
            amount: i['amount'] ?? '',
            unit: i['unit'] ?? '',
            notes: i['notes'],
          ))
        );
      }
      
      if (data['steps'] != null) {
        recipe.steps.addAll(
          (data['steps'] as List).map((s) => RecipeStep(
            stepNumber: s['order'] ?? 0,
            description: s['instruction'] ?? '',
            timerSeconds: s['time'],
          ))
        );
      }
      
      return recipe;
    } catch (e) {
      LoggerService.error('Failed to parse recipe JSON', error: e, tag: 'GeminiService');
      if (fallback != null) return fallback;
      throw Exception('Failed to parse recipe from Gemini response');
    }
  }
}
