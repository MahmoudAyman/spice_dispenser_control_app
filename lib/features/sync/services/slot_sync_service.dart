import '../../../core/services/ble_service.dart';
import '../../../core/storage/storage_service.dart';
import '../../container_management/data/models/slot_model.dart';

class SlotSyncService {
  final BleService bleService =
  BleService();

  Future<void> syncSlotToMachine(
      SlotModel slot,
      ) async {
    final success =
    await bleService.updateSlot(
      slot: slot.slotNumber,
      name: slot.spiceName,
    );

    print("BLE SUCCESS = $success");

    if (!success) {
      throw Exception(
        'Update slot failed',
      );
    }

    final slots =
    StorageService.getSlots();

    final updated = slots.map((s) {
      if (s.slotNumber ==
          slot.slotNumber) {
        return slot;
      }

      return s;
    }).toList();

    await StorageService.saveSlots(
      updated,
    );

    print("LOCAL STORAGE SAVED");

    for (final s in StorageService.getSlots()) {
      print("${s.slotNumber} - ${s.spiceName} - ${s.expiryDate}");
    }
  }

  Future<void> refillSlot(
      int slotNumber,
      ) async {
    final success =
    await bleService.refillSlot(
      slotNumber,
    );

    if (!success) {
      throw Exception(
        'Refill failed',
      );
    }

    final slots =
    StorageService.getSlots();

    final updated = slots.map((slot) {
      if (slot.slotNumber ==
          slotNumber) {
        return slot.copyWith(
          level: 100,
          lastRefillDate:
          DateTime.now()
              .toString(),
        );
      }

      return slot;
    }).toList();

    await StorageService.saveSlots(
      updated,
    );
  }

  Future<void> requestLevels() async {
    final success =
    await bleService.getLevels();

    if (!success) {
      throw Exception(
        'Get levels failed',
      );
    }

    final levelsResponse =
    await bleService
        .protocolService
        .levelsController
        .stream
        .first;

    final levels =
        levelsResponse.data;

    final slots =
    StorageService.getSlots();

    final updated = slots.map((slot) {
      final level =
          levels[
          slot.slotNumber
              .toString()] ??
              slot.level;

      return slot.copyWith(
        level: level,
      );
    }).toList();

    await StorageService.saveSlots(
      updated,
    );
  }
}