import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';
import 'ingredient.dart';

part 'recipe_step.g.dart';

@JsonSerializable()
@embedded
class RecipeStep {
  late int stepNumber;
  String title;
  
  @JsonKey(name: 'instruction')
  String? description;
  
  @JsonKey(includeFromJson: true, includeToJson: true)
  int? timerSeconds;
  
  @JsonKey(includeFromJson: true, includeToJson: true)
  String? timerLabel;
  
  List<Ingredient>? ingredientsForStep;

  RecipeStep({
    this.stepNumber = 0,
    this.title = '',
    this.description,
    this.timerSeconds,
    this.timerLabel,
    this.ingredientsForStep,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    final mapped = Map<String, dynamic>.from(json);
    // Backwards compatibility: older data stored description under "instruction"
    if (!mapped.containsKey('instruction') && mapped.containsKey('description')) {
      mapped['instruction'] = mapped['description'];
    }
    return _$RecipeStepFromJson(mapped);
  }

  Map<String, dynamic> toJson() => _$RecipeStepToJson(this);

  RecipeStep copyWith({
    int? stepNumber,
    String? title,
    String? description,
    int? timerSeconds,
    String? timerLabel,
    List<Ingredient>? ingredientsForStep,
  }) {
    return RecipeStep(
      stepNumber: stepNumber ?? this.stepNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      timerLabel: timerLabel ?? this.timerLabel,
      ingredientsForStep: ingredientsForStep ?? this.ingredientsForStep,
    );
  }
}
