class RecipeIngredientModel {

  final int slot;

  final String spiceName;

  final double grams;

  RecipeIngredientModel({
    required this.slot,
    required this.spiceName,
    required this.grams,
  });

  Map<String, dynamic> toJson() {

    return {
      'slot': slot,
      'spice_name': spiceName,
      'grams': grams,
    };
  }

  factory RecipeIngredientModel.fromJson(
      Map<String, dynamic> json,
      ) {

    return RecipeIngredientModel(

      slot: json['slot'],

      spiceName:
      json['spice_name'],

      grams:
      (json['grams'] as num)
          .toDouble(),
    );
  }
}