import 'package:hive_flutter/hive_flutter.dart';

import '../../features/bluetooth/data/models/last_connected_machine_model.dart';
import '../../features/container_management/data/models/slot_model.dart';
import '../../features/container_management/data/models/spice_definition_model.dart';

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
        .fromMap(
      Map<String, dynamic>.from(data),
    );
  }

  /// AUTO CONNECT SETTING

  static Future<void> setAutoConnect(
      bool enabled,
      ) async {

    await userBox.put(
      StorageKeys.autoConnect,
      enabled,
    );
  }

  static bool isAutoConnectEnabled() {

    return userBox.get(
      StorageKeys.autoConnect,
      defaultValue: true,
    ) as bool;
  }

  /// FAVORITE DEVICE ID SETTING

  static Future<void> setFavoriteDeviceId(
      String? deviceId,
      ) async {

    if (deviceId == null) {

      await userBox.delete(
        StorageKeys.favoriteDeviceId,
      );

    } else {

      await userBox.put(
        StorageKeys.favoriteDeviceId,
        deviceId,
      );
    }
  }

  static String? getFavoriteDeviceId() {

    return userBox.get(
      StorageKeys.favoriteDeviceId,
    ) as String?;
  }

  /// MAX FILL GRAMS SETTING

  static Future<void> setMaxFillGrams(
      double grams,
      ) async {

    await userBox.put(
      StorageKeys.maxFillGrams,
      grams,
    );
  }

  static double getMaxFillGrams() {

    return userBox.get(
      StorageKeys.maxFillGrams,
      defaultValue: 200.0,
    ) as double;
  }

  /// LOW LEVEL THRESHOLD SETTING

  static Future<void> setLowLevelThreshold(
      int percent,
      ) async {

    await userBox.put(
      StorageKeys.lowLevelThreshold,
      percent,
    );
  }

  static int getLowLevelThreshold() {

    return userBox.get(
      StorageKeys.lowLevelThreshold,
      defaultValue: 20,
    ) as int;
  }

  /// SPICE DEFINITIONS CACHED LIST

  static Future<void> saveSpiceDefinitions(List<SpiceDefinition> definitions) async {
    final list = definitions.map((d) => d.toJson()).toList();
    await userBox.put(StorageKeys.spiceDefinitions, list);
  }

  static List<SpiceDefinition> getSpiceDefinitions() {
    final list = userBox.get(StorageKeys.spiceDefinitions) as List<dynamic>?;
    if (list == null) return [];
    return list.map((json) {
      final map = Map<String, dynamic>.from(json as Map);
      return SpiceDefinition.fromJson(map);
    }).toList();
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

  /// SAVE SLOTS

  static Future<void> saveSlots(
    List<SlotModel> slots, {
    String? macAddress,
  }) async {
    final mac = macAddress ?? getLastMachine()?.deviceId;
    final prefix = mac != null ? '${mac}_' : '';

    final data = slots.map((slot) => slot.toJson()).toList();

    await slotsBox.put(
      '${prefix}slots',
      data,
    );

    for (var slot in slots) {
      await slotsBox.put(
        '${prefix}${slot.slotNumber}',
        slot.toJson(),
      );
    }
  }

  /// GET SLOTS

  static List<SlotModel> getSlots({String? macAddress}) {
    final mac = macAddress ?? getLastMachine()?.deviceId;
    final prefix = mac != null ? '${mac}_' : '';

    final slots = <SlotModel>[];
    for (var key in slotsBox.keys) {
      if (key is String && key.startsWith(prefix)) {
        final suffix = key.substring(prefix.length);
        final slotNumber = int.tryParse(suffix);
        if (slotNumber != null) {
          final val = slotsBox.get(key);
          if (val != null) {
            slots.add(
              SlotModel.fromJson(
                Map<String, dynamic>.from(val),
              ),
            );
          }
        }
      }
    }

    if (slots.isNotEmpty) {
      slots.sort((a, b) => a.slotNumber.compareTo(b.slotNumber));
      return slots;
    }

    final data = slotsBox.get('${prefix}slots');

    if (data == null) {
      return [];
    }

    final parsed = List<SlotModel>.from(
      (data as List).map(
        (item) => SlotModel.fromJson(
          Map<String, dynamic>.from(item),
        ),
      ),
    );
    parsed.sort((a, b) => a.slotNumber.compareTo(b.slotNumber));
    return parsed;
  }

  /// CLEAR SLOTS FOR A SPECIFIC MACHINE MAC
  static Future<void> clearSlotsForMachine(String macAddress) async {
    final prefix = '${macAddress}_';
    final keysToDelete = <dynamic>[];
    for (var key in slotsBox.keys) {
      if (key is String && key.startsWith(prefix)) {
        keysToDelete.add(key);
      }
    }
    for (var key in keysToDelete) {
      await slotsBox.delete(key);
    }
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