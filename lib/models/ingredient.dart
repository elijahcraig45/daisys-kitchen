import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ingredient.g.dart';

@JsonSerializable()
@embedded
class Ingredient {
  late String name;
  late String amount;
  late String unit;
  
  @JsonKey(includeFromJson: true, includeToJson: true)
  String? notes;

  Ingredient({
    this.name = '',
    this.amount = '',
    this.unit = '',
    this.notes,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) =>
      _$IngredientFromJson(json);

  Map<String, dynamic> toJson() => _$IngredientToJson(this);

  Ingredient copyWith({
    String? name,
    String? amount,
    String? unit,
    String? notes,
  }) {
    return Ingredient(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      notes: notes ?? this.notes,
    );
  }
}
