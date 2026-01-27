/// Input validation utilities for recipe fields
class Validators {
  /// Validate recipe title
  static String? validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Avast! A recipe needs a name, matey';
    }
    if (value.trim().length < 3) {
      return 'Title be too short - needs at least 3 characters';
    }
    if (value.length > 100) {
      return 'Title be too long - keep it under 100 characters';
    }
    return null;
  }

  /// Validate recipe description
  static String? validateDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Tell us about this dish, sailor!';
    }
    if (value.trim().length < 10) {
      return 'Description needs more detail - at least 10 characters';
    }
    return null;
  }

  /// Validate servings
  static String? validateServings(String? value) {
    if (value == null || value.isEmpty) {
      return 'How many mouths will this feed?';
    }
    final servings = int.tryParse(value);
    if (servings == null) {
      return 'Must be a number, not a treasure map!';
    }
    if (servings < 1) {
      return 'Must serve at least 1 hungry pirate';
    }
    if (servings > 1000) {
      return 'That be too many servings, even for a ship\'s crew!';
    }
    return null;
  }

  /// Validate time in minutes
  static String? validateTime(String? value, {required String field}) {
    if (value == null || value.isEmpty) {
      return null; // Time is optional
    }
    final time = int.tryParse(value);
    if (time == null) {
      return '$field must be a number';
    }
    if (time < 0) {
      return '$field cannot be negative, we can\'t sail backwards in time!';
    }
    if (time > 1440) {
      return '$field seems a bit long - are ye sure? (max 24 hours)';
    }
    return null;
  }

  /// Validate URL format
  static String? validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // URL is optional
    }
    
    final urlPattern = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );
    
    if (!urlPattern.hasMatch(value)) {
      return 'That doesn\'t look like a proper URL, matey';
    }
    return null;
  }

  /// Validate ingredient name
  static String? validateIngredientName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'What be this ingredient called?';
    }
    if (value.trim().length < 2) {
      return 'Ingredient name too short';
    }
    return null;
  }

  /// Validate ingredient amount
  static String? validateIngredientAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'How much do we need?';
    }
    return null;
  }

  /// Validate step description
  static String? validateStepDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Describe this step, sailor!';
    }
    if (value.trim().length < 5) {
      return 'Step description needs more detail';
    }
    return null;
  }

  /// Sanitize user input to prevent XSS and injection
  static String sanitize(String input) {
    return input
        .replaceAll('<script>', '')
        .replaceAll('</script>', '')
        .replaceAll('<iframe>', '')
        .replaceAll('</iframe>', '')
        .trim();
  }
}
