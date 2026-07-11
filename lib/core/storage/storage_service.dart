import 'package:hive_flutter/hive_flutter.dart';

import '../../features/bluetooth/data/models/last_connected_machine_model.dart';
import '../../features/container_management/data/models/slot_model.dart';
import '../../features/recipes/data/models/recipe_model.dart';

import '../services/hash_service.dart';
import 'storage_keys.dart';

class StorageService {

  static Future<void> init() async {
    await Hive.initFlutter();

    await Hive.openBox(StorageKeys.userBox);
    await Hive.openBox(StorageKeys.recipesBox);
    await Hive.openBox(StorageKeys.slotsBox);
    await Hive.openBox(StorageKeys.machineBox);
  }

  /// BOXES

  static Box get userBox =>
      Hive.box(StorageKeys.userBox);

  static Box get recipesBox =>
      Hive.box(StorageKeys.recipesBox);

  static Box get slotsBox =>
      Hive.box(StorageKeys.slotsBox);

  static Box get machineBox =>
      Hive.box(StorageKeys.machineBox);

  /// UUID

  static Future<void> saveUuid(String uuid) async {
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
    final data = userBox.get(
      StorageKeys.lastMachine,
    );

    if (data == null) {
      return null;
    }

    return LastConnectedMachineModel.fromMap(
      Map<String, dynamic>.from(data),
    );
  }

  static Future<void> clearLastMachine() async {
    await userBox.delete(
      StorageKeys.lastMachine,
    );
  }

  /// MACHINE INITIALIZED

  static Future<void> setInitialized(
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

  static bool isMachineInitialized() {
    final initialized = machineBox.get(
      StorageKeys.initialized,
    );

    final slots = slotsBox.get('slots');

    return initialized == true &&
        slots != null;
  }

  static Future<void> resetInitialization() async {
    await machineBox.put(
      StorageKeys.initialized,
      false,
    );

    await slotsBox.clear();
  }

  /// MACHINE HASH

  static Future<void> saveMachineHash(
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

  static const String appVersionKey =
      'app_version';

  static Future<void> saveAppVersion(
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

  static Future<void> saveRecipesHash(
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

  static Future<void> saveSlotsHash(
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
      List<SlotModel> slots,
      ) async {
    final data = slots
        .map((slot) => slot.toJson())
        .toList();

    await slotsBox.put('slots', data);

    await saveSlotsHash(data);
  }

  /// GET SLOTS

  static List<SlotModel> getSlots() {
    final data = slotsBox.get('slots');

    if (data == null) {
      return [];
    }

    return (data as List)
        .map(
          (item) => SlotModel.fromJson(
        Map<String, dynamic>.from(item),
      ),
    )
        .toList();
  }

  /// UPDATE SINGLE SLOT

  static Future<void> updateSlot(
      SlotModel updatedSlot,
      ) async {
    final slots = getSlots();

    final index = slots.indexWhere(
          (slot) =>
      slot.slotNumber ==
          updatedSlot.slotNumber,
    );

    if (index == -1) return;

    slots[index] = updatedSlot;

    await saveSlots(slots);
  }

  /// REFILL SLOT

  static Future<void> refillSlot(
      int slotNumber,
      ) async {
    final slots = getSlots();

    final index = slots.indexWhere(
          (slot) =>
      slot.slotNumber == slotNumber,
    );

    if (index == -1) return;

    slots[index] = slots[index].copyWith(
      level: 100,
      lastRefillDate:
      DateTime.now().toString(),
    );

    await saveSlots(slots);
  }

  /// LOW LEVEL ALERT THRESHOLD

  static Future<void>
  saveLowLevelThreshold(
      int threshold,
      ) async {
    await machineBox.put(
      StorageKeys.lowLevelThreshold,
      threshold,
    );
  }

  static int getLowLevelThreshold() {
    return machineBox.get(
      StorageKeys.lowLevelThreshold,
      defaultValue: 20,
    );
  }

  /// SAVE RECIPES

  static Future<void> saveRecipes(
      List<RecipeModel> recipes,
      ) async {
    final data = recipes
        .map((recipe) => recipe.toJson())
        .toList();

    await recipesBox.put(
      'recipes',
      data,
    );

    await saveRecipesHash(data);
  }

  static List<RecipeModel> getRecipes() {
    final data =
    recipesBox.get('recipes');

    if (data == null) {
      return [];
    }

    return (data as List)
        .map(
          (item) => RecipeModel.fromJson(
        Map<String, dynamic>.from(item),
      ),
    )
        .toList();
  }

  static Future<void> addRecipe(
      RecipeModel recipe,
      ) async {
    final recipes = getRecipes();
    recipes.add(recipe);
    await saveRecipes(recipes);
  }

  static Future<void> deleteRecipe(
      String recipeId,
      ) async {
    final recipes = getRecipes();

    recipes.removeWhere(
          (recipe) =>
      recipe.id == recipeId,
    );

    await saveRecipes(recipes);
  }

  static Future<void> updateRecipe(
      RecipeModel updatedRecipe,
      ) async {
    final recipes = getRecipes();

    final index = recipes.indexWhere(
          (recipe) =>
      recipe.id ==
          updatedRecipe.id,
    );

    if (index == -1) return;

    recipes[index] = updatedRecipe;

    await saveRecipes(recipes);
  }

  static Future<void> clearRecipes() async {
    await recipesBox.clear();

    await machineBox.delete(
      'recipes_hash',
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