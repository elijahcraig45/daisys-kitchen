/// Turns recipe ingredients into grocery list items.
///
/// Pure and free of Firebase singletons, like `RecipeMapper`, so it can be unit tested —
/// and it needs to be, because the data is messier than the schema suggests. Real values
/// in this database include `1.5 cups (180g)`, `1 1/4 cups`, `500 grams`, `2 tablespoons`,
/// `1`, `to taste`, `—`, and rows where the amount is `—` and the quantity is sitting in
/// the *name* (`1/2 cup breadcrumbs (plain or panko)`).
///
/// Two rules run through all of it:
///
///   * Never invent a quantity. An ingredient with no readable amount goes on the list
///     without one, because "flour" is a useful line and "1 flour" is a wrong one.
///   * Never convert between volume and weight. Cups to grams depends on what is being
///     measured, so `1 cup` plus `200 g` stays as both terms. A confidently wrong
///     shopping list is worse than an honest two-part one.
library;

/// Which family a unit belongs to. Conversion happens inside a family and never across.
enum UnitFamily { volume, weight, count }

/// A quantity and unit pulled out of free text.
class ParsedAmount {
  const ParsedAmount({this.quantity, this.unit, this.note, this.leftover});

  /// Null when there is no readable quantity — `to taste`, `—`, or an empty amount.
  final double? quantity;

  /// Canonical unit token: `cup`, `tbsp`, `tsp`, `ml`, `l`, `g`, `kg`, `oz`, `lb`, or
  /// null for a bare count.
  final String? unit;

  /// Anything worth keeping that was not a quantity, such as `to taste`.
  final String? note;

  /// What remained of the input after a quantity was taken out of it. Used when the
  /// quantity turned out to be inside the ingredient's name.
  final String? leftover;

  bool get hasQuantity => quantity != null;

  UnitFamily? get family => unit == null ? UnitFamily.count : IngredientParser.familyOf(unit!);
}

/// One line on a grocery list, possibly built from several recipes.
class ListItem {
  ListItem({
    required this.canonicalName,
    required this.display,
    this.quantity,
    this.unit,
    this.aisle = 'other',
    List<String>? raw,
    List<ListTerm>? extraTerms,
    List<String>? sourceTitles,
  })  : raw = raw ?? [],
        extraTerms = extraTerms ?? [],
        sourceTitles = sourceTitles ?? [];

  final String canonicalName;
  String display;
  double? quantity;
  String? unit;
  String aisle;

  /// The original strings, so a reader can always see what a merged line came from.
  final List<String> raw;

  /// Quantities in a different unit family, kept separate rather than converted.
  final List<ListTerm> extraTerms;

  final List<String> sourceTitles;

  /// `2.5 cups`, or `2.5 cups + 200 g`, or just the name when nothing was parseable.
  String get quantityLabel {
    final parts = <String>[
      if (quantity != null) IngredientParser.formatTerm(quantity!, unit),
      ...extraTerms.map((t) => IngredientParser.formatTerm(t.quantity, t.unit)),
    ];
    return parts.join(' + ');
  }
}

class ListTerm {
  const ListTerm(this.quantity, this.unit);
  final double quantity;
  final String? unit;
}

class IngredientParser {
  IngredientParser._();

  // Canonical unit per family, and the factor to it.
  static const Map<String, (UnitFamily, double)> _units = {
    // volume, canonical ml
    'ml': (UnitFamily.volume, 1),
    'l': (UnitFamily.volume, 1000),
    'tsp': (UnitFamily.volume, 4.92892),
    'tbsp': (UnitFamily.volume, 14.7868),
    'cup': (UnitFamily.volume, 236.588),
    'floz': (UnitFamily.volume, 29.5735),
    'pint': (UnitFamily.volume, 473.176),
    'quart': (UnitFamily.volume, 946.353),
    // weight, canonical g
    'g': (UnitFamily.weight, 1),
    'kg': (UnitFamily.weight, 1000),
    'oz': (UnitFamily.weight, 28.3495),
    'lb': (UnitFamily.weight, 453.592),
  };

  static const Map<String, String> _unitSynonyms = {
    'cup': 'cup', 'cups': 'cup', 'c': 'cup',
    'tablespoon': 'tbsp', 'tablespoons': 'tbsp', 'tbsp': 'tbsp', 'tbs': 'tbsp', 'tb': 'tbsp',
    'teaspoon': 'tsp', 'teaspoons': 'tsp', 'tsp': 'tsp', 'ts': 'tsp',
    'gram': 'g', 'grams': 'g', 'g': 'g', 'gr': 'g',
    'kilogram': 'kg', 'kilograms': 'kg', 'kg': 'kg',
    'ounce': 'oz', 'ounces': 'oz', 'oz': 'oz',
    'pound': 'lb', 'pounds': 'lb', 'lb': 'lb', 'lbs': 'lb',
    'milliliter': 'ml', 'milliliters': 'ml', 'millilitre': 'ml', 'ml': 'ml',
    'liter': 'l', 'liters': 'l', 'litre': 'l', 'litres': 'l', 'l': 'l',
    'fluid ounce': 'floz', 'fl oz': 'floz', 'floz': 'floz',
    'pint': 'pint', 'pints': 'pint',
    'quart': 'quart', 'quarts': 'quart',
  };

  /// Words that mean "no measurable quantity" rather than a missing one.
  static const Set<String> _noQuantity = {
    'to taste', 'as needed', 'a pinch', 'pinch', 'optional', 'for serving',
    'for garnish', 'divided', '—', '-', '–', '',
  };

  static const Map<String, double> _unicodeFractions = {
    '½': 0.5, '⅓': 1 / 3, '⅔': 2 / 3, '¼': 0.25, '¾': 0.75,
    '⅕': 0.2, '⅖': 0.4, '⅗': 0.6, '⅘': 0.8, '⅙': 1 / 6, '⅛': 0.125,
    '⅜': 0.375, '⅝': 0.625, '⅞': 0.875,
  };

  static UnitFamily familyOf(String unit) => _units[unit]?.$1 ?? UnitFamily.count;

  /// Pulls a quantity and unit out of free text.
  ///
  /// Never throws: this parses third-party data, and a shopping list that fails to build
  /// because of one odd row is worse than one line without a quantity.
  static ParsedAmount parseAmount(String? raw) {
    try {
      return _parseAmount(raw);
    } catch (_) {
      return ParsedAmount(note: raw?.trim());
    }
  }

  static ParsedAmount _parseAmount(String? raw) {
    var text = (raw ?? '').trim();
    if (text.isEmpty) return const ParsedAmount();

    final lower = text.toLowerCase();
    if (_noQuantity.contains(lower)) {
      return ParsedAmount(note: lower == '—' || lower == '-' || lower == '–' ? null : lower);
    }

    // A parenthetical metric equivalent is a restatement of the same amount, not a
    // second one: `1.5 cups (180g)` is one quantity. Drop it before reading numbers, or
    // the 180 gets picked up instead.
    text = text.replaceAll(RegExp(r'\([^)]*\)'), ' ').trim();
    if (text.isEmpty) return ParsedAmount(note: raw?.trim());

    // A range takes its upper bound — buying too little is the worse failure — and says
    // so, so the reader knows it was a range.
    final range = RegExp(r'^(\d+(?:\.\d+)?)\s*(?:-|–|to)\s*(\d+(?:\.\d+)?)').firstMatch(text);
    String? note;
    if (range != null) {
      text = text.replaceRange(0, range.end, range.group(2)!);
      note = 'recipe says ${range.group(1)}–${range.group(2)}';
    }

    final quantity = _leadingQuantity(text);
    if (quantity == null) {
      return ParsedAmount(note: note ?? text);
    }

    final rest = text.substring(quantity.$2).trim();
    final unit = _unitFrom(rest);
    return ParsedAmount(
      quantity: quantity.$1,
      unit: unit.$1,
      note: note,
      leftover: unit.$2.isEmpty ? null : unit.$2,
    );
  }

  /// The number at the start of the text, and how many characters it used.
  ///
  /// Handles `1 1/4` (mixed), `1/2`, `1.5`, `1½` and `½`. Mixed fractions are checked
  /// first: reading `1 1/4` as a bare `1` would silently drop a quarter of the recipe.
  static (double, int)? _leadingQuantity(String text) {
    final mixed = RegExp(r'^(\d+)\s+(\d+)\s*/\s*(\d+)').firstMatch(text);
    if (mixed != null) {
      final whole = double.parse(mixed.group(1)!);
      final n = double.parse(mixed.group(2)!);
      final d = double.parse(mixed.group(3)!);
      if (d != 0) return (whole + n / d, mixed.end);
    }

    final mixedUnicode = RegExp('^(\\d+)\\s*([${_unicodeFractions.keys.join()}])').firstMatch(text);
    if (mixedUnicode != null) {
      return (
        double.parse(mixedUnicode.group(1)!) + _unicodeFractions[mixedUnicode.group(2)!]!,
        mixedUnicode.end,
      );
    }

    final fraction = RegExp(r'^(\d+)\s*/\s*(\d+)').firstMatch(text);
    if (fraction != null) {
      final d = double.parse(fraction.group(2)!);
      if (d != 0) return (double.parse(fraction.group(1)!) / d, fraction.end);
    }

    final unicode = RegExp('^([${_unicodeFractions.keys.join()}])').firstMatch(text);
    if (unicode != null) {
      return (_unicodeFractions[unicode.group(1)!]!, unicode.end);
    }

    final decimal = RegExp(r'^(\d+(?:\.\d+)?)').firstMatch(text);
    if (decimal != null) {
      return (double.parse(decimal.group(1)!), decimal.end);
    }
    return null;
  }

  /// The canonical unit at the start of the text, and whatever followed it.
  static (String?, String) _unitFrom(String text) {
    if (text.isEmpty) return (null, '');
    final match = RegExp(r'^([a-zA-Z]+\.?)').firstMatch(text);
    if (match == null) return (null, text);
    final word = match.group(1)!.replaceAll('.', '').toLowerCase();
    final unit = _unitSynonyms[word];
    if (unit == null) return (null, text);
    return (unit, text.substring(match.end).trim());
  }

  /// A name reduced to something two recipes can agree on.
  ///
  /// `All-purpose flour` and `all-purpose flour (spooned & leveled)` are the same
  /// shopping item; `Ground cinnamon (for crust)` is cinnamon.
  static String canonicalName(String name) {
    var text = name.toLowerCase().trim();
    text = text.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    // Everything after a comma is preparation, not identity: "onion, finely chopped".
    final comma = text.indexOf(',');
    if (comma > 0) text = text.substring(0, comma);
    text = text.replaceAll(RegExp(r'\b(for|to)\s+(the\s+)?\w+$'), ' ');
    text = text.replaceAll(RegExp(r'[*†]'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return _singularise(text);
  }

  // Only where it is safe. Blind trailing-s removal turns molasses into molasse and
  // couscous into couscou.
  static const Set<String> _neverSingularise = {
    'molasses', 'couscous', 'hummus', 'asparagus', 'greens', 'oats', 'chives',
    'grits', 'sprouts', 'brussels', 'peas', 'lentils', 'capers', 'noodles',
  };

  static String _singularise(String text) {
    final words = text.split(' ');
    if (words.isEmpty) return text;
    final last = words.last;
    if (_neverSingularise.contains(last) || last.length <= 3) return text;
    if (last.endsWith('ies')) {
      words[words.length - 1] = '${last.substring(0, last.length - 3)}y';
    } else if (last.endsWith('es') && !last.endsWith('ses')) {
      words[words.length - 1] = last.substring(0, last.length - 2);
    } else if (last.endsWith('s') && !last.endsWith('ss')) {
      words[words.length - 1] = last.substring(0, last.length - 1);
    }
    return words.join(' ');
  }

  /// Store section, so a list can be walked once rather than criss-crossed.
  ///
  /// Keyword matching against an ordered map. It will be wrong sometimes; being wrong in
  /// a consistent order still beats alphabetical.
  static const List<String> aisleOrder = [
    'produce', 'bakery', 'meat', 'seafood', 'dairy', 'frozen',
    'pantry', 'spices', 'drinks', 'household', 'other',
  ];

  static const Map<String, List<String>> _aisleKeywords = {
    'produce': ['lettuce', 'spinach', 'kale', 'tomato', 'onion', 'garlic', 'potato',
      'carrot', 'celery', 'cucumber', 'apple', 'banana', 'lemon', 'lime',
      'orange', 'berry', 'berries', 'avocado', 'mushroom', 'broccoli', 'zucchini',
      'squash', 'herb', 'parsley', 'cilantro', 'basil', 'ginger', 'scallion', 'shallot',
      'corn', 'bean sprout', 'cabbage', 'peach', 'pear', 'grape', 'bell pepper'],
    'bakery': ['bread', 'bun', 'roll', 'tortilla', 'pita', 'bagel', 'baguette',
      'breadcrumb', 'panko', 'croissant'],
    // Specific rather than bare 'ground': that made "ground cinnamon" a meat, because
    // the first matching aisle wins.
    'meat': ['chicken', 'beef', 'pork', 'lamb', 'turkey', 'bacon', 'sausage', 'ham',
      'mince', 'steak', 'ground beef', 'ground chicken', 'ground pork', 'ground turkey',
      'ground lamb'],
    'seafood': ['salmon', 'tuna', 'shrimp', 'prawn', 'cod', 'tilapia', 'fish', 'scallop',
      'crab', 'lobster', 'anchovy'],
    'dairy': ['milk', 'butter', 'cheese', 'yogurt', 'yoghurt', 'cream', 'egg',
      'parmesan', 'pecorino', 'mozzarella', 'cheddar', 'feta', 'ricotta', 'mascarpone'],
    'frozen': ['frozen', 'ice cream', 'puff pastry'],
    'pantry': ['flour', 'sugar', 'rice', 'pasta', 'orzo', 'oat', 'oil', 'vinegar',
      'stock', 'broth', 'sauce', 'tomato paste', 'bean', 'lentil', 'chickpea', 'honey',
      'syrup', 'chocolate', 'cocoa', 'vanilla', 'yeast', 'baking powder', 'baking soda',
      'cornstarch', 'nut', 'almond', 'walnut', 'pecan', 'peanut', 'raisin', 'coconut',
      'noodle', 'quinoa', 'couscous', 'molasses', 'jam', 'mustard', 'mayonnaise',
      'ketchup', 'soy sauce', 'canned', 'tuna can'],
    'spices': ['salt', 'pepper', 'cinnamon', 'cumin', 'paprika', 'oregano', 'thyme',
      'rosemary', 'chili', 'chilli', 'curry', 'turmeric', 'nutmeg', 'clove', 'bay leaf',
      'seasoning', 'spice'],
    'drinks': ['water', 'juice', 'wine', 'beer', 'coffee', 'tea', 'soda'],
    'household': ['foil', 'parchment', 'wrap', 'bag', 'towel'],
  };

  static String aisleFor(String canonicalName) {
    for (final aisle in aisleOrder) {
      final keywords = _aisleKeywords[aisle];
      if (keywords == null) continue;
      for (final keyword in keywords) {
        if (canonicalName.contains(keyword)) return aisle;
      }
    }
    return 'other';
  }

  /// Combines ingredients into list lines, merging the same item across recipes.
  ///
  /// Quantities add inside a unit family and are kept as separate terms across families,
  /// because converting cups to grams needs a density this does not have.
  static List<ListItem> combine(Iterable<IngredientInput> inputs) {
    final items = <String, ListItem>{};

    for (final input in inputs) {
      var amount = parseAmount(input.amount);
      var name = input.name;

      // Real rows exist where the amount is '—' and the quantity is in the name:
      // `1/2 cup breadcrumbs (plain or panko)`. Try the name before giving up, and take
      // the quantity out of what gets displayed.
      if (!amount.hasQuantity) {
        final fromName = parseAmount(name);
        if (fromName.hasQuantity) {
          amount = fromName;
          name = fromName.leftover ?? name;
        }
      }

      final canonical = canonicalName(name);
      if (canonical.isEmpty) continue;

      final existing = items[canonical];
      if (existing == null) {
        items[canonical] = ListItem(
          canonicalName: canonical,
          display: _titleCase(canonical),
          quantity: amount.quantity,
          unit: amount.unit,
          aisle: aisleFor(canonical),
          raw: [input.rawLabel],
          sourceTitles: input.sourceTitle == null ? [] : [input.sourceTitle!],
        );
        continue;
      }

      existing.raw.add(input.rawLabel);
      if (input.sourceTitle != null && !existing.sourceTitles.contains(input.sourceTitle)) {
        existing.sourceTitles.add(input.sourceTitle!);
      }
      if (!amount.hasQuantity) continue;

      if (existing.quantity == null) {
        existing.quantity = amount.quantity;
        existing.unit = amount.unit;
      } else if (_sameFamily(existing.unit, amount.unit)) {
        existing.quantity = existing.quantity! + _converted(amount, existing.unit);
      } else {
        // Different families: hold both rather than invent a conversion.
        final term = existing.extraTerms.firstWhere(
          (t) => _sameFamily(t.unit, amount.unit),
          orElse: () => const ListTerm(0, null),
        );
        if (term.quantity == 0 && term.unit == null && amount.unit != null) {
          existing.extraTerms.add(ListTerm(amount.quantity!, amount.unit));
        } else {
          existing.extraTerms.remove(term);
          existing.extraTerms.add(
            ListTerm(term.quantity + _converted(amount, term.unit), term.unit),
          );
        }
      }
    }

    final ordered = items.values.toList()
      ..sort((a, b) {
        final byAisle = aisleOrder.indexOf(a.aisle).compareTo(aisleOrder.indexOf(b.aisle));
        return byAisle != 0 ? byAisle : a.display.compareTo(b.display);
      });
    return ordered;
  }

  static bool _sameFamily(String? a, String? b) {
    final famA = a == null ? UnitFamily.count : familyOf(a);
    final famB = b == null ? UnitFamily.count : familyOf(b);
    return famA == famB;
  }

  /// The amount expressed in [targetUnit], which must be in the same family.
  static double _converted(ParsedAmount amount, String? targetUnit) {
    if (amount.unit == null || targetUnit == null) return amount.quantity!;
    final from = _units[amount.unit!];
    final to = _units[targetUnit];
    if (from == null || to == null || from.$1 != to.$1) return amount.quantity!;
    return amount.quantity! * from.$2 / to.$2;
  }

  /// `2.5 cups`, `200 g`, `3` — trailing zeros trimmed, plural where it reads naturally.
  static String formatTerm(double quantity, String? unit) {
    final rounded = (quantity * 100).round() / 100;
    final number = rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toString();
    if (unit == null) return number;
    final plural = rounded > 1 && (unit == 'cup' || unit == 'pint' || unit == 'quart');
    return '$number ${plural ? '${unit}s' : unit}';
  }

  static String _titleCase(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

/// One ingredient on its way to a list.
class IngredientInput {
  const IngredientInput({
    required this.name,
    this.amount,
    this.sourceTitle,
  });

  final String name;
  final String? amount;

  /// The recipe this came from, so a merged line can say where it came from.
  final String? sourceTitle;

  String get rawLabel =>
      [amount, name].where((p) => p != null && p.trim().isNotEmpty).join(' ').trim();
}
