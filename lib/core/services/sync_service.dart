import '../protocol/commands/get_levels_command.dart';

import '../protocol/protocol_service.dart';

import '../protocol/responses/levels_response.dart';

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
        .levelsController
        .stream
        .listen(
          (levels) async {

        await handleLevels(
          levels,
        );
      },
    );
  }

  /// CHECK IF SYNC NEEDED

  Future<bool> needsSync({
    required int machineVersion,
  }) async {

    final appVersion =
    StorageService
        .getAppVersion();

    return machineVersion !=
        appVersion;
  }

  /// REQUEST LEVELS

  Future<void> requestSync()
  async {

    final command =
    GetLevelsCommand();

    await bleService.sendCommand(
      command:
      command.toJson(),
    );
  }

  /// HANDLE LEVELS

  Future<void> handleLevels(
      LevelsResponse levels,
      ) async {

    for (var entry
    in levels.data.entries) {

      final slot =
      StorageService
          .slotsBox
          .get(entry.key);

      if (slot != null) {

        slot['level'] =
            entry.value;

        await StorageService
            .slotsBox
            .put(
          entry.key,
          slot,
        );
      }
    }

    await StorageService
        .saveAppVersion(
      protocolService
          .machineVersion,
    );
  }
}