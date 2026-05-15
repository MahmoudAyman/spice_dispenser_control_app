
import '../../container_management/data/models/slot_model.dart';

class SlotSyncService {

  Future<void> syncSlotToMachine(
      SlotModel slot,
      ) async {

    /// send slot packet

    /// wait ack

    /// update hive
  }

  Future<void> refillSlot(
      int slotNumber,
      ) async {

    /// send refill command

    /// wait ack
  }
}