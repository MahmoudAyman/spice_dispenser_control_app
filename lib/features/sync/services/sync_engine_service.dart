import '../../../core/services/ble_service.dart';
import '../../../core/storage/storage_service.dart';
import '../../container_management/data/models/slot_model.dart';

class SyncEngineService {
  final BleService bleService;

  SyncEngineService(this.bleService);

  Future<void> syncLevels() async {
    final success =
    await bleService.getLevels();

    if (!success) {
      throw Exception(
        'Failed to request levels',
      );
    }
  }

  Future<void> updateLevelsFromMachine(
      Map<String, dynamic> levels,
      ) async {
    final slots =
    StorageService.getSlots();

    final updatedSlots =
    slots.map((slot) {
      final newLevel =
          levels[
          slot.slotNumber
              .toString()] ??
              slot.level;

      return slot.copyWith(
        level: newLevel,
      );
    }).toList();

    await StorageService.saveSlots(
      updatedSlots,
    );
  }
}