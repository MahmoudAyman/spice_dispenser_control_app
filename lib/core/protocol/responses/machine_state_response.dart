import '../../../features/recipes/data/models/recipe_model.dart';
import '../../../features/container_management/data/models/slot_model.dart';

class MachineStateResponse {

  final List<SlotModel> slots;

  final List<RecipeModel> recipes;

  final int version;

  final bool initialized;

  MachineStateResponse({
    required this.slots,
    required this.recipes,
    required this.version,
    required this.initialized,
  });

  factory MachineStateResponse
      .fromJson(
      Map<String, dynamic> json,
      ) {

    return MachineStateResponse(

      slots:
      (json['slots'] as List)
          .map(
            (slot) =>
            SlotModel.fromJson(slot),
      ).toList(),

      recipes:
      (json['recipes'] as List)
          .map(
            (recipe) =>
            RecipeModel.fromJson(
              recipe,
            ),
      ).toList(),

      version:
      json['version'] ?? 1,

      initialized:
      json['initialized']
          ?? false,
    );
  }
}