/// Input validation utilities for recipe fields
class Validators {
  /// Validate recipe title
  static String? validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a recipe name';
    }
    if (value.trim().length < 3) {
      return 'Name must be at least 3 characters';
    }
    if (value.length > 100) {
      return 'Name must be under 100 characters';
    }
    return null;
  }

  /// Validate recipe description
  static String? validateDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please add a short description';
    }
    if (value.trim().length < 10) {
      return 'Description must be at least 10 characters';
    }
    return null;
  }

  /// Validate servings
  static String? validateServings(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter the number of servings';
    }
    final servings = int.tryParse(value);
    if (servings == null) {
      return 'Servings must be a number';
    }
    if (servings < 1) {
      return 'Recipes must serve at least 1';
    }
    if (servings > 1000) {
      return 'Servings must be 1000 or fewer';
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
      return '$field cannot be negative';
    }
    if (time > 1440) {
      return '$field must be 24 hours or less';
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

    if (!urlPattern.hasMatch(value.trim())) {
      return 'Please enter a valid URL';
    }
    return null;
  }

  /// Validate ingredient name
  static String? validateIngredientName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please name this ingredient';
    }
    if (value.trim().length < 2) {
      return 'Ingredient name is too short';
    }
    return null;
  }

  /// Validate ingredient amount
  static String? validateIngredientAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter an amount';
    }
    return null;
  }

  /// Validate step description
  static String? validateStepDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please describe this step';
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
