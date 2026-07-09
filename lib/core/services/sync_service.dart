import 'package:flutter/foundation.dart';
import '../../../features/container_management/data/models/slot_model.dart';
import '../protocol/commands/get_levels_command.dart';
import '../protocol/protocol_service.dart';
import '../protocol/responses/levels_response.dart';
import '../protocol/responses/manifest_response.dart';
import '../storage/storage_service.dart';
import 'ble_service.dart';

class SyncService {
  final BleService bleService;
  final ProtocolService protocolService;

  SyncService({
    required this.bleService,
    required this.protocolService,
  });

  /// START LISTENING
  void startListening() {
    protocolService.levelsController.stream.listen(
      (levels) async {
        await handleLevels(levels);
      },
    );

    protocolService.manifestController.stream.listen(
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
    await bleService.sendCommand(
      command: command.toJson(),
    );
  }

  /// REQUEST MANIFEST (SLOTS MAPPING)
  Future<void> requestManifest() async {
    await bleService.sendCommand(
      command: {'type': 'get_manifest'},
    );
  }

  /// HANDLE LEVELS
  Future<void> handleLevels(
    LevelsResponse levels,
  ) async {
    for (var entry in levels.data.entries) {
      final val = StorageService.slotsBox.get(entry.key);
      if (val != null) {
        final slot = Map<String, dynamic>.from(val);
        slot['level'] = entry.value;

        await StorageService.slotsBox.put(
          entry.key,
          slot,
        );
      }
    }

    await StorageService.saveAppVersion(
      protocolService.machineVersion,
    );
  }

  /// HANDLE STREAMED MANIFEST
  Future<void> handleManifest(
    ManifestResponse item,
  ) async {
    if (item.type == 'manifest_start') {
      debugPrint('MANIFEST SYNC STARTED: Expected total: ${item.total}');
    } else if (item.type == 'manifest_item' && item.slot != null) {
      // Decode optional unix epoch timestamp to visual date string for the client
      String expiryStr = '';
      final expirySeconds = item.expiry;
      if (expirySeconds != null && expirySeconds > 0) {
        final date = DateTime.fromMillisecondsSinceEpoch(expirySeconds * 1000);
        expiryStr = '${date.day}/${date.month}/${date.year}';
      }

      final slotModel = SlotModel(
        slotNumber: item.slot!,
        spiceName: item.name ?? '',
        expiryDate: expiryStr,
        level: item.level ?? 0,
      );

      // Save synced slot individually in the Hive cache
      await StorageService.slotsBox.put(slotModel.slotNumber, slotModel.toJson());
      debugPrint('MANIFEST SYNCED SLOT ${slotModel.slotNumber}: ${slotModel.spiceName} (${slotModel.level}%)');
    } else if (item.type == 'manifest_end') {
      debugPrint('MANIFEST SYNC COMPLETED SUCCESSFULLY!');
    }
  }
}
