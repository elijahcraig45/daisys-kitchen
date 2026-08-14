import 'package:json_annotation/json_annotation.dart';
import 'ingredient.dart';
import 'recipe_step.dart';

part 'recipe.g.dart';

@JsonSerializable()
class Recipe {
  /// Firestore document ID; null until the recipe has been saved.
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? firestoreId;

  late String title;

  late String description;

  @JsonKey(includeFromJson: true, includeToJson: true)
  String? imageUrl;

  late int servings;

  @JsonKey(includeFromJson: true, includeToJson: true)
  int? prepTimeMinutes;

  @JsonKey(includeFromJson: true, includeToJson: true)
  int? cookTimeMinutes;

  List<String>? tags;

  @JsonKey(includeFromJson: true, includeToJson: true)
  String? category;

  @JsonKey(includeFromJson: true, includeToJson: true)
  String? cuisine;

  DifficultyLevel difficulty = DifficultyLevel.medium;

  List<Ingredient> ingredients = [];

  List<RecipeStep> steps = [];

  @JsonKey(includeFromJson: true, includeToJson: true)
  String? notes;

  @JsonKey(includeFromJson: true, includeToJson: true)
  String? source;

  @JsonKey(includeFromJson: false, includeToJson: false)
  late DateTime createdAt;

  @JsonKey(includeFromJson: false, includeToJson: false)
  late DateTime updatedAt;

  /// Per-user, and therefore NOT stored on the recipe document — it lives in
  /// users/{uid}/favorites. Kept on the model because the UI binds to it, filled in
  /// from the viewer's own favourites when a recipe is loaded.
  @JsonKey(includeFromJson: true, includeToJson: true)
  bool isFavorite = false;

  /// Who may see this: `public`, `household` or `private`.
  ///
  /// Anything unrecognised is treated as private. An unreadable value should hide a
  /// recipe rather than publish one.
  @JsonKey(includeFromJson: true, includeToJson: true)
  String visibility = 'private';

  /// Set only when [visibility] is `household`.
  @JsonKey(includeFromJson: true, includeToJson: true)
  String? householdId;

  /// The recipe this was copied from, when someone edited a community recipe they did
  /// not own.
  @JsonKey(includeFromJson: true, includeToJson: true)
  String? forkedFrom;

  Recipe({
    this.title = '',
    this.description = '',
    this.imageUrl,
    this.servings = 1,
    this.prepTimeMinutes,
    this.cookTimeMinutes,
    this.tags,
    this.category,
    this.cuisine,
    this.difficulty = DifficultyLevel.medium,
    this.notes,
    this.source,
    this.isFavorite = false,
  }) {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  factory Recipe.fromJson(Map<String, dynamic> json) => _$RecipeFromJson(json);

  Map<String, dynamic> toJson() => _$RecipeToJson(this);

  int get totalTimeMinutes =>
      (prepTimeMinutes ?? 0) + (cookTimeMinutes ?? 0);

  Recipe copyWith({
    String? title,
    String? description,
    String? imageUrl,
    int? servings,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    List<String>? tags,
    String? category,
    String? cuisine,
    DifficultyLevel? difficulty,
    String? notes,
    String? source,
    bool? isFavorite,
  }) {
    final updated = Recipe(
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      servings: servings ?? this.servings,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      cuisine: cuisine ?? this.cuisine,
      difficulty: difficulty ?? this.difficulty,
      notes: notes ?? this.notes,
      source: source ?? this.source,
      isFavorite: isFavorite ?? this.isFavorite,
    );
    updated.firestoreId = firestoreId;
    updated.createdAt = createdAt;
    updated.updatedAt = DateTime.now();
    updated.ingredients.addAll(ingredients);
    updated.steps.addAll(steps);
    return updated;
  }
}

@JsonEnum()
enum DifficultyLevel {
  easy,
  medium,
  hard,
}
