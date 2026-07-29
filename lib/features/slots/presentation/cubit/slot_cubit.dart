import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../container_management/data/models/slot_model.dart';
import '../../../sync/services/slot_storage_service.dart';
import '../../../sync/services/slot_sync_service.dart';
import 'slot_state.dart';

class SlotCubit extends Cubit<SlotState> {
  final SlotStorageService storageService;
  final SlotSyncService syncService;

  SlotCubit(
    this.storageService,
    this.syncService,
  ) : super(SlotInitial());

  List<SlotModel> slots = [];

  void loadSlots() {
    emit(SlotLoading());

    slots = storageService.getSlots();

    if (slots.isEmpty) {
      // Generate placeholder entries for all 20 slots when no data exists yet.
      slots = List.generate(
        20,
        (index) => SlotModel(
          slotNumber: index + 1,
          spiceName: '',
          expiryEpoch: null,
          level: 0,
        ),
      );
    }

    emit(SlotLoaded(slots));
  }

  Future<void> updateSlot(SlotModel slot) async {
    emit(SlotUpdating());

    try {
      await syncService.syncSlotToMachine(slot);
      await storageService.updateSlot(slot);
      // Refresh the list from storage so the UI reflects the persisted state.
      slots = storageService.getSlots();
      emit(SlotLoaded(slots));
      emit(SlotUpdated());
    } catch (e) {
      emit(SlotError('Failed to update slot: $e'));
    }
  }

  Future<void> refillSlot(
    int slotNumber, {
    required int level,
    int? expiryEpoch,
  }) async {
    emit(SlotRefilling());

    try {
      await syncService.refillSlot(
        slotNumber,
        level: level,
        expiryEpoch: expiryEpoch,
      );

      // Update local model with the new level (and optional expiry).
      final idx = slots.indexWhere((s) => s.slotNumber == slotNumber);
      if (idx != -1) {
        slots[idx] = slots[idx].copyWith(
          level: level,
          expiryEpoch: expiryEpoch ?? slots[idx].expiryEpoch,
        );
        await storageService.updateSlot(slots[idx]);
      }

      emit(SlotLoaded(slots));
      emit(SlotRefilled());
    } catch (e) {
      emit(SlotError('Failed to refill slot: $e'));
    }
  }
}