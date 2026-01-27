import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:recipe_keeper/models/ingredient.dart';
import 'package:recipe_keeper/models/recipe_step.dart';
import 'package:recipe_keeper/services/gemini_service.dart';
import 'package:recipe_keeper/services/logger_service.dart';

/// Fetches recipe data from URLs using AI-powered extraction (Gemini)
/// Falls back to HTML parsing for Tasty Recipes compatible print pages
class RecipeAutofillService {
  final GeminiService _geminiService = GeminiService();
  static const String _defaultWebProxyUrl = String.fromEnvironment(
    'RECIPE_AUTOFILL_PROXY_URL',
    defaultValue:
        'https://us-central1-recipe-f644f.cloudfunctions.net/recipeAutofillProxy',
  );

  RecipeAutofillService({http.Client? client, String? webProxyUrl})
      : _client = client ?? http.Client(),
        _webProxyUrl = (webProxyUrl ?? _defaultWebProxyUrl).trim().isEmpty
            ? null
            : (webProxyUrl ?? _defaultWebProxyUrl);

  final http.Client _client;
  final String? _webProxyUrl;

  void dispose() {
    _client.close();
  }

  Future<RecipeAutofillResult> fetchRecipe(
    String url, {
    MeasurementSystem preferredSystem = MeasurementSystem.customary,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw RecipeAutofillException('Please enter a valid http or https URL.');
    }

    // Try Gemini first if enabled (smarter extraction)
    if (_geminiService.isEnabled) {
      LoggerService.info('Using Gemini AI to extract recipe from URL', 'RecipeAutofill');
      try {
        final recipe = await _geminiService.extractRecipeFromUrl(url);
        if (recipe != null) {
          LoggerService.success('Successfully extracted recipe using Gemini', 'RecipeAutofill');
          return RecipeAutofillResult(
            title: recipe.title,
            description: recipe.description,
            imageUrl: recipe.imageUrl,
            servings: recipe.servings,
            prepTimeMinutes: recipe.prepTimeMinutes,
            cookTimeMinutes: recipe.cookTimeMinutes,
            ingredients: recipe.ingredients,
            steps: recipe.steps,
          );
        }
      } catch (e) {
        LoggerService.warning('Gemini extraction failed, falling back to HTML parsing: $e', 'RecipeAutofill');
      }
    }

    // Fallback to HTML parsing
    LoggerService.info('Using HTML parsing to extract recipe', 'RecipeAutofill');
    final requestUri = _buildRequestUri(uri);
    final response = await _client.get(requestUri);
    if (response.statusCode != 200) {
      throw RecipeAutofillException(
          'Unable to load recipe. (${response.statusCode})');
    }

    final document = html_parser.parse(response.body);
    final root = document.querySelector('.tasty-recipes') ?? document.body;
    if (root == null) {
      throw RecipeAutofillException(
          'Recipe layout not recognized on that page.');
    }

    final title = root.querySelector('.tasty-recipes-title')?.text.trim() ??
        document.querySelector('h1')?.text.trim();
    final summary =
        root.querySelector('.tasty-recipes-description')?.text.trim();
    final imageUrl =
        root.querySelector('.tasty-recipes-image img')?.attributes['src'];
    final servings =
        _parseServings(root.querySelector('.tasty-recipes-yield')?.text);
    final prepMinutes =
        _parseMinutes(root.querySelector('.tasty-recipes-prep-time')?.text);
    final cookMinutes =
        _parseMinutes(root.querySelector('.tasty-recipes-cook-time')?.text);
    final ingredientNodes =
        root.querySelectorAll('.tasty-recipes-ingredients li');
    final instructionNodes =
        root.querySelectorAll('.tasty-recipes-instructions li');

    final ingredients = ingredientNodes.isNotEmpty
        ? ingredientNodes
            .map((node) => _ingredientFromNode(node, preferredSystem))
            .whereType<Ingredient>()
            .toList()
        : _parseFallbackIngredients(root, preferredSystem);
    final steps = instructionNodes.isNotEmpty
        ? _parseInstructionNodes(instructionNodes)
        : _parseFallbackInstructions(root);

    if (ingredients.isEmpty || steps.isEmpty) {
      throw RecipeAutofillException(
        'Could not find structured ingredients or instructions on that page.',
      );
    }

    final descriptionBuffer = StringBuffer();
    if (summary != null && summary.isNotEmpty) {
      descriptionBuffer.writeln(summary.trim());
      descriptionBuffer.writeln();
    }
    descriptionBuffer.writeln('Original recipe: ${uri.toString()}');

    return RecipeAutofillResult(
      title: title,
      description: descriptionBuffer.toString().trim(),
      imageUrl: imageUrl,
      servings: servings,
      prepTimeMinutes: prepMinutes,
      cookTimeMinutes: cookMinutes,
      ingredients: ingredients,
      steps: steps,
      sourceUrl: uri.toString(),
      preferredSystem: preferredSystem,
    );
  }

  Uri _buildRequestUri(Uri original) {
    if (!kIsWeb) {
      return original;
    }
    final proxyUrl = _webProxyUrl;
    if (proxyUrl == null) {
      throw RecipeAutofillException(
        'Autofill from the browser requires the RECIPE_AUTOFILL_PROXY_URL to be configured.',
      );
    }
    final proxy = Uri.tryParse(proxyUrl);
    if (proxy == null) {
      throw RecipeAutofillException('Invalid proxy URL configured.');
    }
    final params = Map<String, String>.from(proxy.queryParameters);
    params['url'] = original.toString();
    return proxy.replace(queryParameters: params);
  }

  List<Ingredient> _parseFallbackIngredients(
      dom.Element root, MeasurementSystem preferredSystem) {
    final bullets = root.querySelectorAll('li');
    return bullets
        .map((node) => _ingredientFromNode(node, preferredSystem))
        .whereType<Ingredient>()
        .toList();
  }

  List<RecipeStep> _parseInstructionNodes(List<dom.Element> nodes) {
    final steps = <RecipeStep>[];
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final strong = node.querySelector('strong');
      final title = (strong?.text.trim().isNotEmpty ?? false)
          ? strong!.text.trim()
          : 'Step ${i + 1}';
      var description = node.text.trim();
      if (strong != null) {
        description = description.replaceFirst(strong.text, '').trim();
      }
      steps.add(
        RecipeStep(
          stepNumber: i + 1,
          title: title,
          description: description.isNotEmpty ? description : null,
        ),
      );
    }
    return steps;
  }

  List<RecipeStep> _parseFallbackInstructions(dom.Element root) {
    final paragraphs = root.querySelectorAll('p');
    final steps = <RecipeStep>[];
    for (var i = 0; i < paragraphs.length; i++) {
      final text = paragraphs[i].text.trim();
      if (text.isEmpty) continue;
      final stepTitle = text.length > 60 ? text.substring(0, 60).trim() : text;
      steps.add(
        RecipeStep(
          stepNumber: i + 1,
          title: stepTitle,
          description: text,
        ),
      );
    }
    return steps;
  }

  _MeasurementExtraction _extractMeasurementSections(String text) {
    final matches = RegExp(r'\(([^)]+)\)').allMatches(text);
    final alternatives = <String>[];
    final buffer = StringBuffer();
    var lastIndex = 0;
    for (final match in matches) {
      final candidate = match.group(1)?.trim();
      if (candidate != null &&
          candidate.isNotEmpty &&
          RegExp(r'\d').hasMatch(candidate)) {
        alternatives.add(candidate);
        buffer.write(text.substring(lastIndex, match.start));
        lastIndex = match.end;
      }
    }
    if (lastIndex < text.length) {
      buffer.write(text.substring(lastIndex));
    }
    final cleaned = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return _MeasurementExtraction(
        cleaned.isNotEmpty ? cleaned : text, alternatives);
  }

  _IngredientMeasurementChoice _resolveMeasurementChoice(
    _IngredientParseResult primary,
    List<_IngredientParseResult> alternatives,
  ) {
    _IngredientMeasurement? customary;
    _IngredientMeasurement? metric;

    void addCandidate(_IngredientParseResult result) {
      final measurement = _IngredientMeasurement.fromParseResult(result);
      if (measurement == null) return;
      if (measurement.system == MeasurementSystem.customary &&
          customary == null) {
        customary = measurement;
      } else if (measurement.system == MeasurementSystem.metric &&
          metric == null) {
        metric = measurement;
      }
    }

    addCandidate(primary);
    for (final alt in alternatives) {
      addCandidate(alt);
    }

    metric ??= customary != null
        ? _convertMeasurement(customary!, MeasurementSystem.metric)
        : null;
    customary ??= metric != null
        ? _convertMeasurement(metric!, MeasurementSystem.customary)
        : null;

    return _IngredientMeasurementChoice(
      customary: customary,
      metric: metric,
    );
  }

  Ingredient? _ingredientFromNode(
    dom.Element node,
    MeasurementSystem preferredSystem,
  ) {
    final nameText =
        node.querySelector('.tasty-recipes-ingredient-name')?.text.trim();
    final extraction = _extractMeasurementSections(node.text.trim());
    final parsedPrimary = _parseFreeFormIngredient(extraction.baseText);
    final altParses = extraction.alternativeSections
        .map(_parseFreeFormIngredient)
        .where((parsed) => parsed.amount.isNotEmpty)
        .toList();
    final choice = _resolveMeasurementChoice(parsedPrimary, altParses);
    final displayName = (nameText != null && nameText.isNotEmpty)
        ? nameText
        : parsedPrimary.name;

    if (displayName.isEmpty && parsedPrimary.amount.isEmpty) {
      return null;
    }

    final measurement = choice.getForSystem(preferredSystem) ??
        choice.fallbackMeasurement ??
        _IngredientMeasurement.fromParseResult(parsedPrimary);
    if (measurement == null) {
      return Ingredient(
        name: displayName.isNotEmpty ? displayName : 'Ingredient',
        amount: parsedPrimary.amount.isNotEmpty ? parsedPrimary.amount : '—',
        unit: parsedPrimary.unit,
        measurementSystem: preferredSystem,
      );
    }

    final secondary = choice.getOpposite(measurement.system);

    return Ingredient(
      name: displayName.isNotEmpty ? displayName : parsedPrimary.name,
      amount: measurement.amountText.isNotEmpty ? measurement.amountText : '—',
      unit: measurement.unit,
      measurementSystem: measurement.system,
      secondaryAmount: secondary?.amountText,
      secondaryUnit: secondary?.unit,
      secondarySystem: secondary?.system,
    );
  }

  _IngredientParseResult _parseFreeFormIngredient(String text) {
    var working =
        text.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (working.isEmpty) {
      return _IngredientParseResult.empty();
    }

    working = _stripListPrefixes(working);
    if (working.isEmpty) {
      return _IngredientParseResult.empty();
    }

    working = working.replaceAllMapped(
      RegExp(r'(\d)([a-zA-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    for (final entry in _fractionReplacements.entries) {
      working = working.replaceAll(entry.key, entry.value);
    }
    working = working.replaceAllMapped(
      RegExp(r'(\d)\s*/\s*(\d)'),
      (match) => '${match.group(1)}/${match.group(2)}',
    );
    working = working.replaceAllMapped(
      RegExp(r'(\d)\s+and\s+(\d+\/\d+)'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    working = working.replaceAllMapped(
      RegExp(r'(\d+)\s+to\s+(\d+)'),
      (match) => '${match.group(1)}-${match.group(2)}',
    );

    final amountMatch = RegExp(
      r'^((?:\d+(?:\s+)?\/(?:\s+)?\d+|\d+(?:\s+\d+\/\d+)?|\d+\/\d+|\d+(?:\.\d+)?|[¼½¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚⅐⅑⅒]+|an?|a))\b\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(working);

    if (amountMatch == null) {
      return _IngredientParseResult(
        amount: '',
        unit: null,
        name: _cleanIngredientName(working),
      );
    }

    var amount = amountMatch.group(1)!.trim();
    if (amount.toLowerCase() == 'a' || amount.toLowerCase() == 'an') {
      amount = '1';
    }
    var remainder = amountMatch.group(2)!.trim();
    String? unit;
    final unitCandidates = remainder.split(RegExp(r'\s+'));
    if (unitCandidates.isNotEmpty) {
      final maybeUnit = _normalizeUnitToken(unitCandidates.first);
      if (_unitRegistry.containsKey(maybeUnit)) {
        unit = unitCandidates.removeAt(0);
        remainder = unitCandidates.join(' ');
      }
    }

    remainder = _cleanIngredientName(remainder);
    final normalizedUnit = unit != null ? _normalizeUnitToken(unit) : null;
    final descriptor =
        normalizedUnit != null ? _unitRegistry[normalizedUnit] : null;
    final numericQuantity =
        amount.isNotEmpty ? _parseAmountToDouble(amount) : null;
    final canonicalValue = descriptor != null && numericQuantity != null
        ? numericQuantity * descriptor.toCanonicalFactor
        : null;

    return _IngredientParseResult(
      amount: amount,
      unit: unit,
      name: remainder.isNotEmpty ? remainder : working,
      system: descriptor?.system,
      category: descriptor?.category,
      canonicalValue: canonicalValue,
    );
  }

  int? _parseMinutes(String? text) {
    if (text == null) return null;
    final lower = text.toLowerCase();
    var minutes = 0;
    var matched = false;
    for (final match
        in RegExp(r'(\d+)\s*(hour|hr|minute|min)').allMatches(lower)) {
      matched = true;
      final value = int.tryParse(match.group(1) ?? '');
      if (value == null) continue;
      final unit = match.group(2);
      if (unit == null) continue;
      if (unit.startsWith('hour') || unit.startsWith('hr')) {
        minutes += value * 60;
      } else {
        minutes += value;
      }
    }
    return matched ? minutes : null;
  }

  int? _parseServings(String? text) {
    if (text == null) return null;
    final match = RegExp(r'(\d+)').firstMatch(text);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  double? _parseAmountToDouble(String amount) {
    var working = amount.toLowerCase();
    working = working.split(RegExp(r'\bto\b|-')).first.trim();
    if (working.isEmpty) return null;
    final parts = working.split(RegExp(r'\s+'));
    double total = 0;
    for (final part in parts) {
      if (part.isEmpty) continue;
      if (part.contains('/')) {
        final pieces = part.split('/');
        if (pieces.length == 2) {
          final numerator = double.tryParse(pieces[0]);
          final denominator = double.tryParse(pieces[1]);
          if (numerator != null && denominator != null && denominator != 0) {
            total += numerator / denominator;
            continue;
          }
        }
      }
      final value = double.tryParse(part);
      if (value != null) {
        total += value;
      }
    }
    return total == 0 ? null : total;
  }

  String _formatQuantity(double value) {
    final whole = value.floor();
    final fraction = value - whole;
    const fractionMap = <String, double>{
      '1/8': 0.125,
      '1/6': 1 / 6,
      '1/5': 0.2,
      '1/4': 0.25,
      '1/3': 1 / 3,
      '1/2': 0.5,
      '2/3': 2 / 3,
      '3/4': 0.75,
    };
    for (final entry in fractionMap.entries) {
      if ((fraction - entry.value).abs() < 0.02) {
        if (whole == 0) return entry.key;
        return '$whole ${entry.key}';
      }
    }
    final precision = value < 10 ? 2 : 1;
    final formatted =
        value.toStringAsFixed(precision).replaceAll(RegExp(r'\.?0+$'), '');
    return formatted;
  }

  _IngredientMeasurement? _convertMeasurement(
    _IngredientMeasurement source,
    MeasurementSystem targetSystem,
  ) {
    if (source.category == null || source.canonicalValue == null) {
      return null;
    }
    if (source.system == targetSystem) {
      return source;
    }
    if (targetSystem == MeasurementSystem.metric) {
      return _formatMetricMeasurement(
        source.canonicalValue!,
        source.category!,
      );
    }
    return _formatCustomaryMeasurement(
      source.canonicalValue!,
      source.category!,
    );
  }

  _IngredientMeasurement? _formatMetricMeasurement(
    double canonicalValue,
    _MeasurementCategory category,
  ) {
    switch (category) {
      case _MeasurementCategory.mass:
        if (canonicalValue >= 1000) {
          final value = canonicalValue / 1000;
          return _IngredientMeasurement(
            amountText: _formatQuantity(value),
            unit: 'kg',
            system: MeasurementSystem.metric,
            category: category,
            canonicalValue: canonicalValue,
          );
        }
        return _IngredientMeasurement(
          amountText: _formatQuantity(canonicalValue),
          unit: 'g',
          system: MeasurementSystem.metric,
          category: category,
          canonicalValue: canonicalValue,
        );
      case _MeasurementCategory.volume:
        if (canonicalValue >= 1000) {
          final value = canonicalValue / 1000;
          return _IngredientMeasurement(
            amountText: _formatQuantity(value),
            unit: 'L',
            system: MeasurementSystem.metric,
            category: category,
            canonicalValue: canonicalValue,
          );
        }
        return _IngredientMeasurement(
          amountText: _formatQuantity(canonicalValue),
          unit: 'ml',
          system: MeasurementSystem.metric,
          category: category,
          canonicalValue: canonicalValue,
        );
    }
  }

  _IngredientMeasurement? _formatCustomaryMeasurement(
    double canonicalValue,
    _MeasurementCategory category,
  ) {
    switch (category) {
      case _MeasurementCategory.mass:
        if (canonicalValue >= 453.592) {
          final value = canonicalValue / 453.592;
          return _IngredientMeasurement(
            amountText: _formatQuantity(value),
            unit: 'lb',
            system: MeasurementSystem.customary,
            category: category,
            canonicalValue: canonicalValue,
          );
        }
        final ounces = canonicalValue / 28.3495;
        return _IngredientMeasurement(
          amountText: _formatQuantity(ounces),
          unit: 'oz',
          system: MeasurementSystem.customary,
          category: category,
          canonicalValue: canonicalValue,
        );
      case _MeasurementCategory.volume:
        if (canonicalValue >= 240) {
          final cups = canonicalValue / 240;
          return _IngredientMeasurement(
            amountText: _formatQuantity(cups),
            unit: 'cup',
            system: MeasurementSystem.customary,
            category: category,
            canonicalValue: canonicalValue,
          );
        }
        if (canonicalValue >= 30) {
          final tablespoons = canonicalValue / 14.7868;
          return _IngredientMeasurement(
            amountText: _formatQuantity(tablespoons),
            unit: 'tbsp',
            system: MeasurementSystem.customary,
            category: category,
            canonicalValue: canonicalValue,
          );
        }
        final teaspoons = canonicalValue / 4.92892;
        return _IngredientMeasurement(
          amountText: _formatQuantity(teaspoons),
          unit: 'tsp',
          system: MeasurementSystem.customary,
          category: category,
          canonicalValue: canonicalValue,
        );
    }
  }

  static const Map<String, _UnitDescriptor> _unitRegistry = {
    'tsp': _UnitDescriptor(
      system: MeasurementSystem.customary,
      category: _MeasurementCategory.volume,
      toCanonicalFactor: 4.92892,
    ),
    'teaspoon': _UnitDescriptor(
      system: MeasurementSystem.customary,
      category: _MeasurementCategory.volume,
      toCanonicalFactor: 4.92892,
    ),
    'teaspoons': _UnitDescriptor(
      system: MeasurementSystem.customary,
      category: _MeasurementCategory.volume,
      toCanonicalFactor: 4.92892,
    ),
    'tbsp': _UnitDescriptor(
      system: MeasurementSystem.customary,
      category: _MeasurementCategory.volume,
      toCanonicalFactor: 14.7868,
    ),
    'tablespoon': _UnitDescriptor(
      system: MeasurementSystem.customary,
      category: _MeasurementCategory.volume,
      toCanonicalFactor: 14.7868,
    ),
    'tablespoons': _UnitDescriptor(
      system: MeasurementSystem.customary,
      category: _MeasurementCategory.volume,
      toCanonicalFactor: 14.7868,
    ),
    'cup': _UnitDescriptor(
      system: MeasurementSystem.customary,
      category: _MeasurementCategory.volume,
      toCanonicalFactor: 240,
    ),
    'cups': _UnitDescriptor(
      system: MeasurementSystem.customary,
      category: _MeasurementCategory.volume,
      toCanonicalFactor: 240,
    ),
    'floz': _UnitDescriptor(
      system: MeasurementSystem.customary,
      category: _MeasurementCategory.volume,
      toCanonicalFactor: 29.5735,
    ),
    'fluidounce': _UnitDescriptor(
      system: MeasurementSystem.customary,
      category: _MeasurementCategory.volume,
      toCanonicalFactor: 29.5735,
    ),
    'ml': _UnitDescriptor(
      system: MeasurementSystem.metric,
      category: _MeasurementCategory.volume,
      toCanonicalFactor: 1,
    ),
    'milliliter': _UnitDescriptor(
      system: MeasurementSystem.metric,
      category: _MeasurementCategory.volume,
      toCanonicalFactor: 1,
    ),
    'milliliters': _UnitDescriptor(
      system: MeasurementSystem.metric,
      category: _MeasurementCategory.volume,
      toCanonicalFactor: 1,
    ),
    'l': _UnitDescriptor(
      system: MeasurementSystem.metric,
      category: _MeasurementCategory.volume,
      toCanonicalFactor: 1000,
    ),
    'liter': _UnitDescriptor(
      system: MeasurementSystem.metric,
      category: _MeasurementCategory.volume,
      toCanonicalFactor: 1000,
    ),
    'liters': _UnitDescriptor(
      system: MeasurementSystem.metric,
      category: _MeasurementCategory.volume,
      toCanonicalFactor: 1000,
    ),
    'g': _UnitDescriptor(
      system: MeasurementSystem.metric,
      category: _MeasurementCategory.mass,
      toCanonicalFactor: 1,
    ),
    'gram': _UnitDescriptor(
      system: MeasurementSystem.metric,
      category: _MeasurementCategory.mass,
      toCanonicalFactor: 1,
    ),
    'grams': _UnitDescriptor(
      system: MeasurementSystem.metric,
      category: _MeasurementCategory.mass,
      toCanonicalFactor: 1,
    ),
    'kg': _UnitDescriptor(
      system: MeasurementSystem.metric,
      category: _MeasurementCategory.mass,
      toCanonicalFactor: 1000,
    ),
    'kilogram': _UnitDescriptor(
      system: MeasurementSystem.metric,
      category: _MeasurementCategory.mass,
      toCanonicalFactor: 1000,
    ),
    'kilograms': _UnitDescriptor(
      system: MeasurementSystem.metric,
      category: _MeasurementCategory.mass,
      toCanonicalFactor: 1000,
    ),
    'oz': _UnitDescriptor(
      system: MeasurementSystem.customary,
      category: _MeasurementCategory.mass,
      toCanonicalFactor: 28.3495,
    ),
    'ounce': _UnitDescriptor(
      system: MeasurementSystem.customary,
      category: _MeasurementCategory.mass,
      toCanonicalFactor: 28.3495,
    ),
    'ounces': _UnitDescriptor(
      system: MeasurementSystem.customary,
      category: _MeasurementCategory.mass,
      toCanonicalFactor: 28.3495,
    ),
    'lb': _UnitDescriptor(
      system: MeasurementSystem.customary,
      category: _MeasurementCategory.mass,
      toCanonicalFactor: 453.592,
    ),
    'lbs': _UnitDescriptor(
      system: MeasurementSystem.customary,
      category: _MeasurementCategory.mass,
      toCanonicalFactor: 453.592,
    ),
    'pound': _UnitDescriptor(
      system: MeasurementSystem.customary,
      category: _MeasurementCategory.mass,
      toCanonicalFactor: 453.592,
    ),
    'pounds': _UnitDescriptor(
      system: MeasurementSystem.customary,
      category: _MeasurementCategory.mass,
      toCanonicalFactor: 453.592,
    ),
  };
}

class RecipeAutofillResult {
  final String? title;
  final String? description;
  final String? imageUrl;
  final int? servings;
  final int? prepTimeMinutes;
  final int? cookTimeMinutes;
  final List<Ingredient> ingredients;
  final List<RecipeStep> steps;
  final String? sourceUrl;
  final MeasurementSystem preferredSystem;

  RecipeAutofillResult({
    this.title,
    this.description,
    this.imageUrl,
    this.servings,
    this.prepTimeMinutes,
    this.cookTimeMinutes,
    List<Ingredient>? ingredients,
    List<RecipeStep>? steps,
    this.sourceUrl,
    this.preferredSystem = MeasurementSystem.customary,
  })  : ingredients = ingredients ?? const [],
        steps = steps ?? const [];
}

class RecipeAutofillException implements Exception {
  RecipeAutofillException(this.message);
  final String message;

  @override
  String toString() => message;
}

class _IngredientParseResult {
  final String amount;
  final String? unit;
  final String name;
  final MeasurementSystem? system;
  final _MeasurementCategory? category;
  final double? canonicalValue;

  const _IngredientParseResult({
    required this.amount,
    required this.unit,
    required this.name,
    this.system,
    this.category,
    this.canonicalValue,
  });

  factory _IngredientParseResult.empty() =>
      const _IngredientParseResult(amount: '', unit: null, name: '');
}

class _IngredientMeasurement {
  const _IngredientMeasurement({
    required this.amountText,
    required this.unit,
    required this.system,
    required this.category,
    required this.canonicalValue,
  });

  final String amountText;
  final String? unit;
  final MeasurementSystem system;
  final _MeasurementCategory? category;
  final double? canonicalValue;

  static _IngredientMeasurement? fromParseResult(
    _IngredientParseResult result,
  ) {
    if (result.amount.isEmpty ||
        result.system == null ||
        result.category == null) {
      return null;
    }
    return _IngredientMeasurement(
      amountText: result.amount,
      unit: result.unit,
      system: result.system!,
      category: result.category,
      canonicalValue: result.canonicalValue,
    );
  }
}

class _IngredientMeasurementChoice {
  const _IngredientMeasurementChoice({
    this.customary,
    this.metric,
  });

  final _IngredientMeasurement? customary;
  final _IngredientMeasurement? metric;

  _IngredientMeasurement? getForSystem(MeasurementSystem system) {
    return system == MeasurementSystem.customary ? customary : metric;
  }

  _IngredientMeasurement? getOpposite(MeasurementSystem system) {
    return system == MeasurementSystem.customary ? metric : customary;
  }

  _IngredientMeasurement? get fallbackMeasurement => customary ?? metric;
}

String _normalizeUnitToken(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
}

String _stripListPrefixes(String input) {
  var working =
      input.replaceFirst(RegExp(r'^[\-\u2022•\s,.:;]+'), '').trimLeft();
  final noisePattern = RegExp(
    r'^(?:and|&|plus|with|about|around|approximately|approx\.?|roughly|almost|nearly)\b[\s,]+',
    caseSensitive: false,
  );
  while (true) {
    final match = noisePattern.firstMatch(working);
    if (match == null) break;
    working = working.substring(match.end).trimLeft();
  }
  return working;
}

String _cleanIngredientName(String input) {
  var result = input.trim();
  result =
      result.replaceFirst(RegExp(r'^(?:of|the)\s+', caseSensitive: false), '');
  result =
      result.replaceFirst(RegExp(r'^(?:and|&)\s+', caseSensitive: false), '');
  result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
  result = result.replaceAll(RegExp(r'[.,;:\s]+$'), '');
  return result;
}

class _MeasurementExtraction {
  _MeasurementExtraction(this.baseText, this.alternativeSections);

  final String baseText;
  final List<String> alternativeSections;
}

enum _MeasurementCategory {
  mass,
  volume,
}

class _UnitDescriptor {
  const _UnitDescriptor({
    required this.system,
    required this.category,
    required this.toCanonicalFactor,
  });

  final MeasurementSystem system;
  final _MeasurementCategory category;
  final double toCanonicalFactor;
}

const Map<String, String> _fractionReplacements = {
  '¼': ' 1/4',
  '½': ' 1/2',
  '¾': ' 3/4',
  '⅓': ' 1/3',
  '⅔': ' 2/3',
  '⅛': ' 1/8',
  '⅜': ' 3/8',
  '⅝': ' 5/8',
  '⅞': ' 7/8',
  '⅕': ' 1/5',
  '⅖': ' 2/5',
  '⅗': ' 3/5',
  '⅘': ' 4/5',
  '⅙': ' 1/6',
  '⅚': ' 5/6',
  '⅐': ' 1/7',
  '⅑': ' 1/9',
  '⅒': ' 1/10',
};
