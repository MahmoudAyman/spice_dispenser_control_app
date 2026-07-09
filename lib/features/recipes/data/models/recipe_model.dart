class RecipeIngredient {
  final String name;
  final double grams;

  RecipeIngredient({
    required this.name,
    required this.grams,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'grams': grams,
    };
  }

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      name: json['name'] ?? json['n'] ?? '',
      grams: (json['grams'] ?? json['g'] ?? 0.0).toDouble(),
    );
  }
}

class RecipeModel {
  final String id;
  final String name;
  final List<RecipeIngredient> ingredients;
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
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'duration': duration,
    };
  }

  factory RecipeModel.fromJson(Map<String, dynamic> json) {
    var rawIngredients = json['ingredients'] ?? json['i'] ?? [];
    List<RecipeIngredient> parsedIngredients = [];
    if (rawIngredients is List) {
      for (var item in rawIngredients) {
        if (item is String) {
          // Backward compatibility for old simple string lists
          parsedIngredients.add(RecipeIngredient(name: item, grams: 1.0));
        } else if (item is Map) {
          parsedIngredients.add(
            RecipeIngredient.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return RecipeModel(
      id: json['id'] ?? '',
      name: json['name'] ?? json['n'] ?? '',
      ingredients: parsedIngredients,
      duration: json['duration'] ?? 5,
    );
  }

  RecipeModel copyWith({
    String? id,
    String? name,
    List<RecipeIngredient>? ingredients,
    int? duration,
  }) {
    return RecipeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ingredients: ingredients ?? this.ingredients,
      duration: duration ?? this.duration,
    );
  }
}
