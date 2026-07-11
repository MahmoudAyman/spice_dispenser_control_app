import '../../../../core/storage/storage_service.dart';
import '../../container_management/data/models/slot_model.dart';

class SlotStorageService {
  Future<void> saveSlots(
      List<SlotModel> slots,
      ) async {
    await StorageService.saveSlots(slots);
  }

  Future<void> updateSlot(
      SlotModel slot,
      ) async {
    await StorageService.updateSlot(slot);
  }

  List<SlotModel> getSlots() {
    return StorageService.getSlots();
  }

  Future<void> refillSlot(
      int slotNumber,
      ) async {
    await StorageService.refillSlot(
      slotNumber,
    );
  }
}