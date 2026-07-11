import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/storage/storage_service.dart';

import '../../../dashboard/presentation/controllers/machine_controller.dart';

import '../../../dispensing/data/models/dispense_item_model.dart';

import '../../data/models/recipe_ingredient_model.dart';
import '../../data/models/recipe_model.dart';

class RecipesController
    extends ChangeNotifier {

  final List<RecipeModel>
  recipes = [];

  /// LOAD RECIPES

  void loadRecipes() {

    recipes.clear();

    recipes.addAll(
      StorageService
          .getRecipes(),
    );

    notifyListeners();
  }

  /// ADD RECIPE

  Future<void> addRecipe({

    required String name,

    required List<
        RecipeIngredientModel>
    ingredients,

  }) async {

    final recipe =
    RecipeModel(

      id:
      const Uuid().v4(),

      name:
      name,

      ingredients:
      ingredients,

      duration:
      10,
    );

    recipes.add(
      recipe,
    );

    await StorageService
        .saveRecipes(
      recipes,
    );

    notifyListeners();
  }

  /// DELETE RECIPE

  Future<void>
  deleteRecipe(
      String recipeId,
      ) async {

    recipes.removeWhere(

          (recipe) =>
      recipe.id ==
          recipeId,
    );

    await StorageService
        .saveRecipes(
      recipes,
    );

    notifyListeners();
  }

  /// DISPENSE RECIPE

  Future<void>
  dispenseRecipe({

    required RecipeModel
    recipe,

    required MachineController
    machineController,

  }) async {

    final List<
        DispenseItemModel>
    items =

    recipe.ingredients.map(

          (ingredient) {

        return DispenseItemModel(

          slot:
          ingredient.slot,

          grams:
          ingredient.grams,

          spiceName:
          ingredient.spiceName,
        );
      },
    ).toList();

    await machineController
        .startDispensing(

      items:
      items,

      recipeName:
      recipe.name,
    );
  }

  /// SYNC RECIPES

  Future<void>
  syncRecipes()
  async {

    final recipesJson =

    recipes.map((recipe) {

      return {

        "id":
        recipe.id,

        "name":
        recipe.name,

        "ingredients":

        recipe.ingredients.map(

              (ingredient) {

            return {

              "slot":
              ingredient.slot,

              "grams":
              ingredient.grams,
            };
          },
        ).toList(),
      };

    }).toList();

    debugPrint(
      recipesJson.toString(),
    );

    /// TODO:
    /// SEND SYNC_RECIPES
    /// COMMAND TO MACHINE
  }
}