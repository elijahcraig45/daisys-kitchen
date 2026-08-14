import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_keeper/services/ingredient_parser.dart';

/// The awkward inputs here are not invented. They are the actual amount strings in this
/// database, read off the live API: `1.5 cups (180g)`, `1 1/4 cups`, `500 grams`,
/// `2 tablespoons`, `1`, `to taste`, `—`, and rows where the amount is `—` and the
/// quantity is sitting in the name.
void main() {
  group('parseAmount: the shapes this database actually contains', () {
    test('a parenthetical metric equivalent is a restatement, not a second quantity', () {
      // Reading the 180 instead of the 1.5 would silently shrink the recipe by a lot.
      final parsed = IngredientParser.parseAmount('1.5 cups (180g)');
      expect(parsed.quantity, 1.5);
      expect(parsed.unit, 'cup');
    });

    test('a mixed fraction keeps its fraction', () {
      // Read as a bare 1, this drops a quarter of the flour.
      final parsed = IngredientParser.parseAmount('1 1/4 cups');
      expect(parsed.quantity, closeTo(1.25, 0.001));
      expect(parsed.unit, 'cup');
    });

    test('grams, tablespoons and bare counts', () {
      expect(IngredientParser.parseAmount('500 grams').quantity, 500);
      expect(IngredientParser.parseAmount('500 grams').unit, 'g');
      expect(IngredientParser.parseAmount('2 tablespoons').unit, 'tbsp');
      final bare = IngredientParser.parseAmount('1');
      expect(bare.quantity, 1);
      expect(bare.unit, isNull);
    });

    test('"to taste" and an em dash mean no quantity, not a missing one', () {
      final taste = IngredientParser.parseAmount('to taste');
      expect(taste.hasQuantity, isFalse);
      expect(taste.note, 'to taste');

      final dash = IngredientParser.parseAmount('—');
      expect(dash.hasQuantity, isFalse);
      // Nothing worth showing: an em dash is an absence, not a note.
      expect(dash.note, isNull);
    });

    test('plain fractions, unicode fractions and decimals', () {
      expect(IngredientParser.parseAmount('1/2 cup').quantity, 0.5);
      expect(IngredientParser.parseAmount('½ cup').quantity, 0.5);
      expect(IngredientParser.parseAmount('1½ cups').quantity, closeTo(1.5, 0.001));
      expect(IngredientParser.parseAmount('0.75 tsp').quantity, 0.75);
    });

    test('a range takes the upper bound and says it was a range', () {
      final parsed = IngredientParser.parseAmount('2-3 tablespoons');
      expect(parsed.quantity, 3);
      expect(parsed.unit, 'tbsp');
      expect(parsed.note, contains('2'));
    });

    test('never throws, whatever it is handed', () {
      for (final input in [
        null, '', '   ', 'abc', '1/0 cup', '((()))', '½½½', '1 1/', '-', 'a pinch',
        '¼¾ mystery', '999999999999999999999 cups',
      ]) {
        expect(() => IngredientParser.parseAmount(input), returnsNormally,
            reason: 'input: $input');
      }
    });

    test('a divide by zero fraction does not become infinity', () {
      final parsed = IngredientParser.parseAmount('1/0 cup');
      expect(parsed.quantity == null || parsed.quantity!.isFinite, isTrue);
    });
  });

  group('canonicalName', () {
    test('preparation notes and parentheticals do not change what to buy', () {
      expect(IngredientParser.canonicalName('All-purpose flour'), 'all-purpose flour');
      expect(
        IngredientParser.canonicalName('all-purpose flour (spooned & leveled)'),
        'all-purpose flour',
      );
      expect(IngredientParser.canonicalName('Ground cinnamon (for crust)'), 'ground cinnamon');
      expect(
        IngredientParser.canonicalName('Light brown sugar, lightly packed'),
        'light brown sugar',
      );
      expect(IngredientParser.canonicalName('canned pumpkin puree*'), 'canned pumpkin puree');
    });

    test('singularises only where it is safe', () {
      expect(IngredientParser.canonicalName('eggs'), 'egg');
      expect(IngredientParser.canonicalName('tomatoes'), 'tomato');
      // Blind trailing-s removal would produce molasse, couscou and oat.
      expect(IngredientParser.canonicalName('molasses'), 'molasses');
      expect(IngredientParser.canonicalName('couscous'), 'couscous');
      expect(IngredientParser.canonicalName('rolled oats'), 'rolled oats');
    });
  });

  group('aisleFor', () {
    test('sorts the obvious things into the obvious sections', () {
      expect(IngredientParser.aisleFor('ground chicken'), 'meat');
      expect(IngredientParser.aisleFor('all-purpose flour'), 'pantry');
      expect(IngredientParser.aisleFor('greek yogurt'), 'dairy');
      expect(IngredientParser.aisleFor('lemon'), 'produce');
      expect(IngredientParser.aisleFor('ground cinnamon'), 'spices');
      expect(IngredientParser.aisleFor('breadcrumb'), 'bakery');
    });

    test('anything unrecognised lands in other rather than guessing', () {
      expect(IngredientParser.aisleFor('mystery paste'), 'other');
    });
  });

  group('combine', () {
    test('the same ingredient from two recipes becomes one line (R3.3)', () {
      final items = IngredientParser.combine([
        const IngredientInput(
          name: 'All-purpose flour',
          amount: '1 cup',
          sourceTitle: 'Bars',
        ),
        const IngredientInput(
          // Same ingredient, different preparation note — canonicalisation strips it.
          name: 'all-purpose flour (spooned & leveled)',
          amount: '1.5 cups (180g)',
          sourceTitle: 'Cookies',
        ),
      ]);
      final flour = items.where((i) => i.canonicalName.contains('flour')).toList();
      expect(flour.length, 1);
      expect(flour.first.quantity, closeTo(2.5, 0.001));
      expect(flour.first.unit, 'cup');
      expect(flour.first.sourceTitles, containsAll(['Bars', 'Cookies']));
    });

    test('names that differ in substance stay separate', () {
      // Merging a shorter name into a longer one that contains it sounds helpful until
      // it puts almond flour in the cake. Two honest lines beat one wrong one.
      final items = IngredientParser.combine([
        const IngredientInput(name: 'flour', amount: '1 cup'),
        const IngredientInput(name: 'almond flour', amount: '1 cup'),
        const IngredientInput(name: 'Self rising flour', amount: '500 grams'),
      ]);
      expect(items.length, 3);
    });

    test('units convert inside a family', () {
      final items = IngredientParser.combine([
        const IngredientInput(name: 'milk', amount: '1 cup'),
        const IngredientInput(name: 'milk', amount: '2 tbsp'),
      ]);
      // 1 cup is 16 tbsp, so this is 1.125 cups rather than 3 of something.
      expect(items.single.unit, 'cup');
      expect(items.single.quantity, closeTo(1.125, 0.01));
    });

    test('volume and weight are kept apart, never converted (R3.5)', () {
      final items = IngredientParser.combine([
        const IngredientInput(name: 'sugar', amount: '1 cup'),
        const IngredientInput(name: 'sugar', amount: '200 g'),
      ]);
      final sugar = items.single;
      expect(sugar.quantity, 1);
      expect(sugar.unit, 'cup');
      expect(sugar.extraTerms.length, 1);
      expect(sugar.extraTerms.single.unit, 'g');
      // Both terms are shown, because cups to grams needs a density we do not have.
      expect(sugar.quantityLabel, '1 cup + 200 g');
    });

    test('a quantity hiding in the name is still found', () {
      // A real row: amount is an em dash and the quantity is in the name.
      final items = IngredientParser.combine([
        const IngredientInput(
          name: '1/2 cup breadcrumbs (plain or panko)',
          amount: '—',
        ),
      ]);
      expect(items.single.quantity, 0.5);
      expect(items.single.unit, 'cup');
      // And the quantity is not left sitting in the displayed name.
      expect(items.single.display.toLowerCase(), isNot(contains('1/2')));
      expect(items.single.canonicalName, contains('breadcrumb'));
    });

    test('an unmeasurable ingredient still makes the list, without a quantity', () {
      final items = IngredientParser.combine([
        const IngredientInput(name: 'Salt', amount: 'to taste'),
      ]);
      // "salt" is a useful line; "1 salt" would be a wrong one.
      expect(items.single.canonicalName, 'salt');
      expect(items.single.quantity, isNull);
      expect(items.single.quantityLabel, isEmpty);
    });

    test('the list comes out in store order, not alphabetical', () {
      final items = IngredientParser.combine([
        const IngredientInput(name: 'flour', amount: '1 cup'),
        const IngredientInput(name: 'chicken breast', amount: '1 lb'),
        const IngredientInput(name: 'lemon', amount: '2'),
      ]);
      expect(items.map((i) => i.aisle).toList(), ['produce', 'meat', 'pantry']);
    });

    test('survives a whole recipe of real strings without throwing', () {
      final items = IngredientParser.combine(const [
        IngredientInput(name: 'All-purpose flour', amount: '1.5 cups (180g)'),
        IngredientInput(name: 'Quick-cooking rolled oats', amount: '3 cups (255g)'),
        IngredientInput(name: 'Ground cinnamon (for crust)', amount: '1 tablespoon (7g)'),
        IngredientInput(name: 'Light brown sugar, lightly packed', amount: '1.25 cups (250g)'),
        IngredientInput(name: 'canned pumpkin puree*', amount: '1 1/4 cups'),
        IngredientInput(name: 'unsalted butter, cut into 16 pieces', amount: '1 cup'),
        IngredientInput(name: 'Self rising flour', amount: '500 grams'),
        IngredientInput(name: '0% greek yogurt', amount: '520 grams'),
        IngredientInput(name: 'ground chicken', amount: '1 pound'),
        IngredientInput(name: 'large egg', amount: '1'),
        IngredientInput(name: '1/2 cup breadcrumbs (plain or panko)', amount: '—'),
        IngredientInput(name: 'olive oil (for cooking)', amount: '2 tablespoons'),
        IngredientInput(name: 'Salt and pepper', amount: 'to taste'),
      ]);
      expect(items, isNotEmpty);
      expect(items.every((i) => i.canonicalName.isNotEmpty), isTrue);
      // Every line either has a readable quantity or honestly has none.
      expect(items.every((i) => i.quantity == null || i.quantity!.isFinite), isTrue);
    });
  });

  group('formatTerm', () {
    test('trims trailing zeros and pluralises where it reads naturally', () {
      expect(IngredientParser.formatTerm(2, 'cup'), '2 cups');
      expect(IngredientParser.formatTerm(1, 'cup'), '1 cup');
      expect(IngredientParser.formatTerm(2.5, 'cup'), '2.5 cups');
      expect(IngredientParser.formatTerm(200, 'g'), '200 g');
      expect(IngredientParser.formatTerm(3, null), '3');
    });
  });
}
