import '../../../../core/storage/storage_service.dart';
import '../../recipes/data/models/recipe_model.dart';

class RecipeStorageService {
  final String? _macAddress;

  RecipeStorageService([String? macAddress])
      : _macAddress = macAddress ?? StorageService.getLastMachine()?.deviceId;

  String get _prefix => _macAddress != null ? '${_macAddress}_' : '';

  Future<void> addRecipe(
    RecipeModel recipe,
  ) async {
    final key = '$_prefix${recipe.id}';
    await StorageService.recipesBox.put(
      key,
      recipe.toJson(),
    );
  }

  Future<void> updateRecipe(
    RecipeModel recipe,
  ) async {
    final key = '$_prefix${recipe.id}';
    await StorageService.recipesBox.put(
      key,
      recipe.toJson(),
    );
  }

  Future<void> deleteRecipe(
    String id,
  ) async {
    final key = '$_prefix$id';
    await StorageService.recipesBox.delete(key);
  }

  List<RecipeModel> getRecipes() {
    final list = <RecipeModel>[];
    final prefix = _prefix;

    for (var key in StorageService.recipesBox.keys) {
      if (key is String && key.startsWith(prefix)) {
        final val = StorageService.recipesBox.get(key);
        if (val != null) {
          list.add(
            RecipeModel.fromJson(
              Map<String, dynamic>.from(val),
            ),
          );
        }
      }
    }
    return list;
  }
}
