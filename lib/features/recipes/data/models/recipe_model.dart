import 'recipe_ingredient_model.dart';

class RecipeModel {

  final String id;

  final String name;

  final List<RecipeIngredientModel>
  ingredients;

  final int duration;

  final bool favorite;

  RecipeModel({
    required this.id,
    required this.name,
    required this.ingredients,
    required this.duration,
    this.favorite = false,
  });

  Map<String, dynamic> toJson() {

    return {

      'id': id,

      'name': name,

      'ingredients':
      ingredients
          .map(
            (e) => e.toJson(),
      )
          .toList(),

      'duration': duration,

      'favorite': favorite,
    };
  }

  factory RecipeModel.fromJson(
      Map<String, dynamic> json,
      ) {

    return RecipeModel(

      id: json['id'],

      name: json['name'],

      ingredients:

      List<
          RecipeIngredientModel>.from(

        (json['ingredients'] as List)

            .map(

              (item) =>

              RecipeIngredientModel
                  .fromJson(

                Map<String, dynamic>
                    .from(item),
              ),
        ),
      ),

      duration:
      json['duration'],

      favorite:
      json['favorite']
          ?? false,
    );
  }
}