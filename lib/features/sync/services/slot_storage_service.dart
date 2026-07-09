import '../../../../core/storage/storage_service.dart';
import '../../container_management/data/models/slot_model.dart';

class SlotStorageService {

  Future<void> saveSlots(
      List<SlotModel> slots,
      ) async {

    for (var slot in slots) {

      await StorageService
          .slotsBox
          .put(
        slot.slotNumber,
        slot.toJson(),
      );
    }
  }

  Future<void> updateSlot(
      SlotModel slot,
      ) async {

    await StorageService
        .slotsBox
        .put(
      slot.slotNumber,
      slot.toJson(),
    );
  }

  List<SlotModel> getSlots() {

    return StorageService
        .slotsBox
        .values
        .map((e) {

      return SlotModel.fromJson(
        Map<String, dynamic>.from(e),
      );

    }).toList();
  }
}