class RecipeModel {

  final String id;

  final String name;

  final List<String> ingredients;

  final int duration;

  RecipeModel({
    required this.id,
    required this.name,
    required this.ingredients,
    required this.duration,
  });

  Map<String, dynamic> toJson() {

    return {
      'id': id,
      'name': name,
      'ingredients': ingredients,
      'duration': duration,
    };
  }

  factory RecipeModel.fromJson(
      Map<String, dynamic> json,
      ) {

    return RecipeModel(
      id: json['id'],
      name: json['name'],
      ingredients:
      List<String>.from(
        json['ingredients'],
      ),
      duration: json['duration'],
    );
  }
}