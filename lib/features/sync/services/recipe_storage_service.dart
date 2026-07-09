import '../../../../core/storage/storage_service.dart';
import '../../recipes/data/models/recipe_model.dart';

class RecipeStorageService {

  Future<void> addRecipe(
      RecipeModel recipe,
      ) async {

    await StorageService
        .recipesBox
        .put(
      recipe.id,
      recipe.toJson(),
    );
  }

  Future<void> updateRecipe(
      RecipeModel recipe,
      ) async {

    await StorageService
        .recipesBox
        .put(
      recipe.id,
      recipe.toJson(),
    );
  }

  Future<void> deleteRecipe(
      String id,
      ) async {

    await StorageService
        .recipesBox
        .delete(id);
  }

  List<RecipeModel> getRecipes() {

    return StorageService
        .recipesBox
        .values
        .map((e) {

      return RecipeModel.fromJson(
        Map<String, dynamic>.from(e),
      );

    }).toList();
  }
}