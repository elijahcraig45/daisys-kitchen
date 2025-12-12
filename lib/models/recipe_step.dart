import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';
import 'ingredient.dart';

part 'recipe_step.g.dart';

@JsonSerializable()
@embedded
class RecipeStep {
  late int stepNumber;
  late String instruction;
  
  @JsonKey(includeFromJson: true, includeToJson: true)
  int? timerSeconds;
  
  @JsonKey(includeFromJson: true, includeToJson: true)
  String? timerLabel;
  
  List<Ingredient>? ingredientsForStep;

  RecipeStep({
    this.stepNumber = 0,
    this.instruction = '',
    this.timerSeconds,
    this.timerLabel,
    this.ingredientsForStep,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json) =>
      _$RecipeStepFromJson(json);

  Map<String, dynamic> toJson() => _$RecipeStepToJson(this);

  RecipeStep copyWith({
    int? stepNumber,
    String? instruction,
    int? timerSeconds,
    String? timerLabel,
    List<Ingredient>? ingredientsForStep,
  }) {
    return RecipeStep(
      stepNumber: stepNumber ?? this.stepNumber,
      instruction: instruction ?? this.instruction,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      timerLabel: timerLabel ?? this.timerLabel,
      ingredientsForStep: ingredientsForStep ?? this.ingredientsForStep,
    );
  }
}
