import 'package:flutter/foundation.dart';

import '../../../../core/protocol/commands/refill_command.dart';
import '../../../../core/protocol/commands/update_slot_command.dart';
import '../../../../core/services/ble_service.dart';
import '../../../../core/storage/storage_service.dart';
import '../../container_management/data/models/slot_model.dart';

class SlotSyncService {
  final BleService bleService;

  SlotSyncService({required this.bleService});

  /// Send update_slot command and wait for ACK.
  Future<void> syncSlotToMachine(SlotModel slot) async {
    try {
      final command = UpdateSlotCommand(
        slot: slot.slotNumber,
        name: slot.spiceName,
        expiry: slot.expiryEpoch,
      );

      debugPrint('Sending update_slot for slot ${slot.slotNumber}...');

      final ack = await bleService.sendCommand(
        command: command.toJson(),
      );

      if (ack.isSuccess) {
        debugPrint('update_slot ACK success for slot ${slot.slotNumber}');
      } else {
        debugPrint('update_slot ACK failed for slot ${slot.slotNumber}: ${ack.status}');
      }
    } catch (e) {
      debugPrint('Error sending update_slot for slot ${slot.slotNumber}: $e');
      rethrow;
    }
  }

  /// Send refill command with a chosen fill percentage and wait for ACK.
  Future<void> refillSlot(
    int slotNumber, {
    required int level,
    int? expiryEpoch,
  }) async {
    try {
      final command = RefillCommand(
        slot: slotNumber,
        level: level,
        expiry: expiryEpoch,
      );

      debugPrint('Sending refill for slot $slotNumber at $level%...');

      final ack = await bleService.sendCommand(
        command: command.toJson(),
        timeout: const Duration(seconds: 5),
      );

      if (ack.isSuccess) {
        debugPrint('Refill ACK success for slot $slotNumber');
        // Update locally-cached fill level
        final macAddress = StorageService.getLastMachine()?.deviceId;
        final prefix = macAddress != null ? '${macAddress}_' : '';
        final key = '$prefix$slotNumber';
        final val = StorageService.slotsBox.get(key);
        if (val != null) {
          final slot = Map<String, dynamic>.from(val);
          slot['level'] = level;
          await StorageService.slotsBox.put(key, slot);
        }
      } else {
        debugPrint('Refill ACK failed for slot $slotNumber: ${ack.status}');
      }
    } catch (e) {
      debugPrint('Error sending refill for slot $slotNumber: $e');
      rethrow;
    }
  }
}