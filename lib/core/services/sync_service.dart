import '../../features/container_management/data/models/slot_model.dart';
import '../../features/recipes/data/models/recipe_model.dart';
import '../../features/container_management/data/models/slot_model.dart';
import '../../features/recipes/data/models/recipe_model.dart';


import '../protocol/commands/sync_command.dart';
import '../protocol/protocol_service.dart';
import '../protocol/responses/machine_state_response.dart';

import '../storage/storage_service.dart';

import 'ble_service.dart';

class SyncService {

  final BleService bleService;

  final ProtocolService
  protocolService;

  SyncService({
    required this.bleService,
    required this.protocolService,
  });

  /// START LISTENING

  void startListening() {

    protocolService
        .machineStateController
        .stream
        .listen(
          (state) async {

        await handleMachineState(
          state,
        );
      },
    );
  }

  /// CHECK SYNC

  Future<bool> needsSync({
    required int machineVersion,
  }) async {

    final appVersion =
    StorageService
        .getAppVersion();

    return machineVersion >
        appVersion;
  }

  /// REQUEST SYNC

  Future<void> requestSync()
  async {

    final command =
    SyncCommand();

    await bleService.sendCommand(
      command:
      command.toJson(),
    );
  }

  /// HANDLE MACHINE STATE

  Future<void> handleMachineState(
      MachineStateResponse
      state,
      ) async {

    /// SAVE SLOTS

    for (SlotModel slot
    in state.slots) {

      await StorageService
          .slotsBox
          .put(
        slot.slotNumber,
        slot.toJson(),
      );
    }

    /// SAVE RECIPES

    for (RecipeModel recipe
    in state.recipes) {

      await StorageService
          .recipesBox
          .put(
        recipe.id,
        recipe.toJson(),
      );
    }

    /// UPDATE VERSION

    await StorageService
        .saveAppVersion(
      state.version,
    );

    /// INITIALIZED

    await StorageService
        .setInitialized(
      state.initialized,
    );

    /// SAVE HASHES

    await StorageService
        .saveSlotsHash(
      state.slots,
    );

    await StorageService
        .saveRecipesHash(
      state.recipes,
    );
  }
}