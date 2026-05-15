import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../container_management/data/models/slot_model.dart';
import '../../../sync/services/slot_storage_service.dart';
import '../../../sync/services/slot_sync_service.dart';
import 'slot_state.dart';

class SlotCubit extends Cubit<SlotState> {

  final SlotStorageService
  storageService;

  final SlotSyncService
  syncService;

  SlotCubit(
      this.storageService,
      this.syncService,
      ) : super(SlotInitial());

  List<SlotModel> slots = [];

  void loadSlots() {

    emit(SlotLoading());

    slots =
        storageService.getSlots();

    if (slots.isEmpty) {

      slots = List.generate(
        6,
            (index) => SlotModel(
          slotNumber: index + 1,
          spiceName: '',
          expiryDate: '',
          level: 100,
        ),
      );
    }

    emit(SlotLoaded(slots));
  }

  Future<void> updateSlot(
      SlotModel slot,
      ) async {

    emit(SlotUpdating());

    await syncService
        .syncSlotToMachine(slot);

    await storageService
        .updateSlot(slot);

    loadSlots();

    emit(SlotUpdated());
  }

  Future<void> refillSlot(
      int slotNumber,
      ) async {

    emit(SlotRefilling());

    await syncService
        .refillSlot(slotNumber);

    loadSlots();

    emit(SlotRefilled());
  }
}