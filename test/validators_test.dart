import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_keeper/utils/validators.dart';

void main() {
  group('validateTitle', () {
    test('accepts a reasonable name', () {
      expect(Validators.validateTitle('Cacio e Pepe'), isNull);
    });

    test('rejects blank and whitespace-only names', () {
      expect(Validators.validateTitle(null), isNotNull);
      expect(Validators.validateTitle('   '), isNotNull);
    });

    test('rejects names that are too short or too long', () {
      expect(Validators.validateTitle('Pi'), isNotNull);
      expect(Validators.validateTitle('a' * 101), isNotNull);
    });
  });

  group('validateServings', () {
    test('accepts positive integers', () {
      expect(Validators.validateServings('4'), isNull);
    });

    test('rejects non-numeric, zero and oversized values', () {
      expect(Validators.validateServings('four'), isNotNull);
      expect(Validators.validateServings('0'), isNotNull);
      expect(Validators.validateServings('1001'), isNotNull);
    });
  });

  group('validateTime', () {
    test('treats an empty value as optional', () {
      expect(Validators.validateTime('', field: 'Prep time'), isNull);
      expect(Validators.validateTime(null, field: 'Prep time'), isNull);
    });

    test('names the offending field in the message', () {
      expect(
        Validators.validateTime('abc', field: 'Cook time'),
        contains('Cook time'),
      );
    });

    test('rejects negative values and anything over 24 hours', () {
      expect(Validators.validateTime('-1', field: 'Prep time'), isNotNull);
      expect(Validators.validateTime('1441', field: 'Prep time'), isNotNull);
      expect(Validators.validateTime('1440', field: 'Prep time'), isNull);
    });
  });

  group('validateUrl', () {
    test('treats an empty value as optional', () {
      expect(Validators.validateUrl(''), isNull);
    });

    test('accepts http and https URLs', () {
      expect(Validators.validateUrl('https://example.com/recipe'), isNull);
      expect(Validators.validateUrl('http://example.com'), isNull);
    });

    test('rejects malformed URLs', () {
      expect(Validators.validateUrl('example'), isNotNull);
      expect(Validators.validateUrl('ftp://example.com'), isNotNull);
    });
  });

  group('sanitize', () {
    test('strips script and iframe tags and trims', () {
      expect(
        Validators.sanitize('  <script>alert(1)</script>Chop onions  '),
        'alert(1)Chop onions',
      );
    });
  });
}
