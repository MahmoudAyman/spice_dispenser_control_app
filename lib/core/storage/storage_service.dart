import 'package:hive_flutter/hive_flutter.dart';

import '../../features/bluetooth/data/models/last_connected_machine_model.dart';
import '../services/hash_service.dart';
import 'storage_keys.dart';

class StorageService {

  static Future<void> init() async {

    await Hive.initFlutter();

    await Hive.openBox(
      StorageKeys.userBox,
    );

    await Hive.openBox(
      StorageKeys.recipesBox,
    );

    await Hive.openBox(
      StorageKeys.slotsBox,
    );

    await Hive.openBox(
      StorageKeys.machineBox,
    );
  }

  /// BOXES

  static Box get userBox =>
      Hive.box(
        StorageKeys.userBox,
      );

  static Box get recipesBox =>
      Hive.box(
        StorageKeys.recipesBox,
      );

  static Box get slotsBox =>
      Hive.box(
        StorageKeys.slotsBox,
      );

  static Box get machineBox =>
      Hive.box(
        StorageKeys.machineBox,
      );

  /// UUID

  static Future<void> saveUuid(
      String uuid,
      ) async {

    await userBox.put(
      StorageKeys.userUuid,
      uuid,
    );
  }

  static String? getUuid() {

    return userBox.get(
      StorageKeys.userUuid,
    );
  }

  /// LAST CONNECTED MACHINE

  static Future<void> saveLastMachine(
      LastConnectedMachineModel machine,
      ) async {

    await userBox.put(
      StorageKeys.lastMachine,
      machine.toMap(),
    );
  }

  static LastConnectedMachineModel?
  getLastMachine() {

    final data =
    userBox.get(
      StorageKeys.lastMachine,
    );

    if (data == null) {
      return null;
    }

    return LastConnectedMachineModel
        .fromMap(data);
  }

  /// MACHINE INITIALIZED

  static Future<void>
  setInitialized(
      bool value,
      ) async {

    await machineBox.put(
      StorageKeys.initialized,
      value,
    );
  }

  static bool isInitialized() {

    return machineBox.get(
      StorageKeys.initialized,
    ) ??
        false;
  }

  /// MACHINE HASH

  static Future<void>
  saveMachineHash(
      String hash,
      ) async {

    await machineBox.put(
      StorageKeys.machineHash,
      hash,
    );
  }

  static String? getMachineHash() {

    return machineBox.get(
      StorageKeys.machineHash,
    );
  }

  /// APP VERSION

  static const String
  appVersionKey =
      'app_version';

  static Future<void>
  saveAppVersion(
      int version,
      ) async {

    await machineBox.put(
      appVersionKey,
      version,
    );
  }

  static int getAppVersion() {

    return machineBox.get(
      appVersionKey,
      defaultValue: 1,
    );
  }

  /// RECIPES HASH

  static Future<void>
  saveRecipesHash(
      List recipes,
      ) async {

    final hash =
    HashService.generateHash(
      recipes.toString(),
    );

    await machineBox.put(
      'recipes_hash',
      hash,
    );
  }

  static String? getRecipesHash() {

    return machineBox.get(
      'recipes_hash',
    );
  }

  /// SLOTS HASH

  static Future<void>
  saveSlotsHash(
      List slots,
      ) async {

    final hash =
    HashService.generateHash(
      slots.toString(),
    );

    await machineBox.put(
      'slots_hash',
      hash,
    );
  }

  static String? getSlotsHash() {

    return machineBox.get(
      'slots_hash',
    );
  }

  /// CLEAR STORAGE

  static Future<void>
  clearStorage() async {

    await userBox.clear();

    await recipesBox.clear();

    await slotsBox.clear();

    await machineBox.clear();
  }
}