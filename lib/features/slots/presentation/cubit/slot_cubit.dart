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

  /// slot currently updating
  int? updatingSlot;

  /// slot currently refilling
  int? refillingSlot;

  void loadSlots() {
    slots = storageService.getSlots();

    if (slots.isEmpty) {
      slots = List.generate(
        6,
            (index) => SlotModel.initial(index + 1),
      );
    }

    emit(SlotLoaded(List.from(slots)));
  }

  Future<void> updateSlot(
      SlotModel slot,
      ) async {
    updatingSlot = slot.slotNumber;

    emit(SlotLoaded(List.from(slots)));

    try {
      await syncService.syncSlotToMachine(slot);

      loadSlots();

      updatingSlot = null;

      emit(SlotUpdated());
      emit(SlotLoaded(List.from(slots)));
    } catch (e) {
      updatingSlot = null;

      emit(
        SlotError(
          e.toString(),
        ),
      );

      emit(SlotLoaded(List.from(slots)));
    }
  }

  Future<void> refillSlot(
      int slotNumber,
      ) async {
    refillingSlot = slotNumber;

    emit(SlotLoaded(List.from(slots)));

    try {
      await syncService.refillSlot(
        slotNumber,
      );

      loadSlots();

      refillingSlot = null;

      emit(SlotRefilled());
      emit(SlotLoaded(List.from(slots)));
    } catch (e) {
      refillingSlot = null;

      emit(
        SlotError(
          e.toString(),
        ),
      );

      emit(SlotLoaded(List.from(slots)));
    }
  }

  Future<void> syncLevels() async {
    try {
      await syncService.requestLevels();

      loadSlots();
    } catch (_) {}
  }

  bool isUpdating(int slotNumber) =>
      updatingSlot == slotNumber;

  bool isRefilling(int slotNumber) =>
      refillingSlot == slotNumber;
}