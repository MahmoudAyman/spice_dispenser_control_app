import '../../../../core/storage/storage_service.dart';
import '../../container_management/data/models/slot_model.dart';

class SlotStorageService {
  final String? _macAddress;

  SlotStorageService([String? macAddress])
      : _macAddress = macAddress ?? StorageService.getLastMachine()?.deviceId;

  String get _prefix => _macAddress != null ? '${_macAddress}_' : '';

  Future<void> saveSlots(
    List<SlotModel> slots,
  ) async {
    for (var slot in slots) {
      await StorageService.slotsBox.put(
        '$_prefix${slot.slotNumber}',
        slot.toJson(),
      );
    }
  }

  Future<void> updateSlot(
    SlotModel slot,
  ) async {
    await StorageService.slotsBox.put(
      '$_prefix${slot.slotNumber}',
      slot.toJson(),
    );
  }

  List<SlotModel> getSlots() {
    return StorageService.getSlots(macAddress: _macAddress);
  }
}
