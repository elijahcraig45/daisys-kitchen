import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ingredient.g.dart';

@JsonSerializable()
@embedded
class Ingredient {
  late String name;
  late String amount;
  String? unit;
  @JsonKey(unknownEnumValue: MeasurementSystem.customary)
  MeasurementSystem measurementSystem = MeasurementSystem.customary;
  String? secondaryAmount;
  String? secondaryUnit;
  MeasurementSystem? secondarySystem;

  @JsonKey(includeFromJson: true, includeToJson: true)
  String? notes;

  Ingredient({
    this.name = '',
    this.amount = '',
    this.unit,
    this.measurementSystem = MeasurementSystem.customary,
    this.secondaryAmount,
    this.secondaryUnit,
    this.secondarySystem,
    this.notes,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) =>
      _$IngredientFromJson(json);

  Map<String, dynamic> toJson() => _$IngredientToJson(this);

  Ingredient copyWith({
    String? name,
    String? amount,
    String? unit,
    MeasurementSystem? measurementSystem,
    String? secondaryAmount,
    String? secondaryUnit,
    MeasurementSystem? secondarySystem,
    String? notes,
  }) {
    return Ingredient(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      measurementSystem: measurementSystem ?? this.measurementSystem,
      secondaryAmount: secondaryAmount ?? this.secondaryAmount,
      secondaryUnit: secondaryUnit ?? this.secondaryUnit,
      secondarySystem: secondarySystem ?? this.secondarySystem,
      notes: notes ?? this.notes,
    );
  }
}

@JsonEnum()
enum MeasurementSystem {
  customary,
  metric,
}
