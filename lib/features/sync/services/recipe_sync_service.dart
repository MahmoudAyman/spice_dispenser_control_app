import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/services/ble_service.dart';
import '../../recipes/data/models/recipe_model.dart';

class RecipeSyncResult {
  final bool isSuccess;
  final String? errorReason;
  final int? failedRecipeIndex;
  final String? failedRecipeName;
  final String? missingIngredient;

  RecipeSyncResult({
    required this.isSuccess,
    this.errorReason,
    this.failedRecipeIndex,
    this.failedRecipeName,
    this.missingIngredient,
  });
}

class RecipeSyncService {
  /// Syncs all recipes to the machine sequentially.
  Future<RecipeSyncResult> syncAllRecipes({
    required BleService bleService,
    required List<RecipeModel> recipes,
  }) async {
    if (bleService.writeCharacteristic == null) {
      return RecipeSyncResult(
        isSuccess: false,
        errorReason: 'No active Bluetooth connection to the machine',
      );
    }

    try {
      debugPrint('STARTING RECIPE SYNC: Total recipes: ${recipes.length}');

      // 1. Send sync_recipes_start
      final startAck = await bleService.sendCommand(
        command: {
          'type': 'sync_recipes_start',
          'total': recipes.length,
        },
        timeout: const Duration(seconds: 4),
      );

      if (!startAck.isSuccess) {
        return RecipeSyncResult(
          isSuccess: false,
          errorReason: 'Machine rejected sync start: ${startAck.status}',
        );
      }

      // 2. Stream each recipe item
      for (int i = 0; i < recipes.length; i++) {
        final recipe = recipes[i];
        final Map<String, dynamic> itemCommand = {
          'type': 'sync_recipe_item',
          'index': i,
          'id': recipe.id,
          'n': recipe.name,
          'i': recipe.ingredients
              .map((ing) => {
                    'n': ing.name,
                    'g': ing.grams,
                  })
              .toList(),
        };

        debugPrint('STREAMING RECIPE ITEM $i: ${recipe.name}');
        final itemAck = await bleService.sendCommand(
          command: itemCommand,
          timeout: const Duration(seconds: 5),
        );

        if (itemAck.status == 'fail') {
          // Check if it's an invalid ingredient error
          if (itemAck.reason == 'invalid_ingredient') {
            final missingIngredient = itemAck.detail ?? 'unknown';
            return RecipeSyncResult(
              isSuccess: false,
              errorReason: 'Recipe "${recipe.name}" uses "$missingIngredient" which is not loaded on this machine.',
              failedRecipeIndex: i,
              failedRecipeName: recipe.name,
              missingIngredient: missingIngredient,
            );
          } else {
            return RecipeSyncResult(
              isSuccess: false,
              errorReason: 'Failed to sync recipe "${recipe.name}": ${itemAck.reason ?? itemAck.status}',
              failedRecipeIndex: i,
              failedRecipeName: recipe.name,
            );
          }
        }
      }

      // 3. Send sync_recipes_end
      final endAck = await bleService.sendCommand(
        command: {
          'type': 'sync_recipes_end',
        },
        timeout: const Duration(seconds: 4),
      );

      if (!endAck.isSuccess) {
        return RecipeSyncResult(
          isSuccess: false,
          errorReason: 'Machine failed to save recipe cache: ${endAck.status}',
        );
      }

      debugPrint('RECIPE SYNC COMPLETED SUCCESSFULLY!');
      return RecipeSyncResult(isSuccess: true);
    } catch (e) {
      debugPrint('Recipe Sync Error: $e');
      return RecipeSyncResult(
        isSuccess: false,
        errorReason: 'Sync error: $e',
      );
    }
  }
}
