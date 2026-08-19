import 'package:flutter/foundation.dart';
import '../../../features/container_management/data/models/slot_model.dart';
import '../../../features/sync/services/recipe_storage_service.dart';
import '../../../features/sync/services/recipe_sync_service.dart';
import '../protocol/commands/get_levels_command.dart';
import '../protocol/protocol_service.dart';
import '../protocol/responses/levels_response.dart';
import '../protocol/responses/manifest_response.dart';
import '../storage/storage_service.dart';
import 'ble_service.dart';

class SyncService {
  final BleService bleService;
  final ProtocolService protocol;

  SyncService({
    required this.bleService,
    required this.protocol,
  });

  /// START LISTENING
  void startListening() {
    protocol.levelsController.stream.listen(
      (levels) async {
        await handleLevels(levels);
      },
    );

    protocol.manifestController.stream.listen(
      (manifest) async {
        await handleManifest(manifest);
      },
    );
  }

  /// CHECK IF SYNC NEEDED
  Future<bool> needsSync({
    required int machineVersion,
  }) async {
    final appVersion = StorageService.getAppVersion();
    return machineVersion != appVersion;
  }

  /// REQUEST LEVELS
  Future<void> requestSync() async {
    final command = GetLevelsCommand();
    await bleService.writeCommand(
      command: command.toJson(),
    );
  }

  /// REQUEST MANIFEST (SLOTS MAPPING)
  Future<void> requestManifest() async {
    await bleService.writeCommand(
      command: {'type': 'get_manifest'},
    );
  }

  /// HANDLE LEVELS
  Future<void> handleLevels(
    LevelsResponse levels,
  ) async {
    final macAddress = StorageService.getLastMachine()?.deviceId;
    final prefix = macAddress != null ? '${macAddress}_' : '';

    for (var entry in levels.data.entries) {
      final key = '${prefix}${entry.key}';
      final val = StorageService.slotsBox.get(key);
      if (val != null) {
        final slot = Map<String, dynamic>.from(val);
        final spiceName = slot['spiceName'] ?? '';
        final isSkipped = spiceName.toString().trim().startsWith('Slot ');
        slot['level'] = isSkipped ? 0 : entry.value;

        await StorageService.slotsBox.put(
          key,
          slot,
        );
      }
    }

    await StorageService.saveAppVersion(
      protocol.machineVersion,
    );
  }

  /// HANDLE STREAMED MANIFEST
  Future<void> handleManifest(
    ManifestResponse item,
  ) async {
    if (item.type == 'manifest_start') {
      debugPrint('MANIFEST SYNC STARTED: Expected total: ${item.total}');
    } else if (item.type == 'manifest_item' && item.slot != null) {
      final expirySeconds = item.expiry;
      final epochVal = (expirySeconds != null && expirySeconds > 0) ? expirySeconds : null;
      final isSkipped = item.name != null && item.name!.trim().startsWith('Slot ');

      final slotModel = SlotModel(
        slotNumber: item.slot!,
        spiceName: item.name ?? '',
        expiryEpoch: epochVal,
        level: isSkipped ? 0 : (item.level ?? 0),
      );

      // Save synced slot individually in the Hive cache prefixed by MAC
      final macAddress = StorageService.getLastMachine()?.deviceId;
      final prefix = macAddress != null ? '${macAddress}_' : '';
      await StorageService.slotsBox.put('${prefix}${slotModel.slotNumber}', slotModel.toJson());
      debugPrint('MANIFEST SYNCED SLOT ${slotModel.slotNumber}: ${slotModel.spiceName} (${slotModel.level}%)');
    } else if (item.type == 'manifest_end') {
      debugPrint('MANIFEST SYNC COMPLETED SUCCESSFULLY!');
      _syncRecipesToMachine();
    }
  }

  /// AUTO-SYNC RECIPES TO MACHINE RAM FOR PHYSICAL LCD MENU
  Future<void> _syncRecipesToMachine() async {
    try {
      final macAddress = StorageService.getLastMachine()?.deviceId;
      if (macAddress == null) return;

      final storageService = RecipeStorageService(macAddress);
      final recipes = storageService.getRecipes();

      if (recipes.isEmpty) {
        debugPrint('No stored recipes found for MAC $macAddress. Skipping automatic BLE sync.');
        return;
      }

      debugPrint('Auto-syncing ${recipes.length} recipes to machine...');
      final syncService = RecipeSyncService();
      final result = await syncService.syncAllRecipes(
        bleService: bleService,
        recipes: recipes,
      );

      if (result.isSuccess) {
        debugPrint('Auto-sync of recipes completed successfully!');
      } else {
        debugPrint('Auto-sync of recipes failed: ${result.errorReason}');
      }
    } catch (e) {
      debugPrint('Error during auto-syncing recipes: $e');
    }
  }
}
