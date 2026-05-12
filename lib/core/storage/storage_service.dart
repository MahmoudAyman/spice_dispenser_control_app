import 'package:hive_flutter/hive_flutter.dart';

import '../../features/bluetooth/data/models/last_connected_machine_model.dart';
import 'storage_keys.dart';

class StorageService {

  static Future<void> init() async {

    await Hive.initFlutter();

    await Hive.openBox(
      StorageKeys.userBox,
    );
  }

  static Box get _box =>
      Hive.box(StorageKeys.userBox);

  /// UUID

  static Future<void> saveUuid(
      String uuid,
      ) async {

    await _box.put(
      StorageKeys.userUuid,
      uuid,
    );
  }

  static String? getUuid() {

    return _box.get(
      StorageKeys.userUuid,
    );
  }

  /// LAST CONNECTED MACHINE

  static Future<void> saveLastMachine(
      LastConnectedMachineModel machine,
      ) async {

    await _box.put(
      StorageKeys.lastMachine,
      machine.toMap(),
    );
  }

  static LastConnectedMachineModel?
  getLastMachine() {

    final data = _box.get(
      StorageKeys.lastMachine,
    );

    if (data == null) {
      return null;
    }

    return LastConnectedMachineModel
        .fromMap(data);
  }

  static Future<void> clearStorage()
  async {

    await _box.clear();
  }
}