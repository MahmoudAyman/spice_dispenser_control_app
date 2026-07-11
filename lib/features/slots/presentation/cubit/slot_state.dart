import '../../../container_management/data/models/slot_model.dart';

abstract class SlotState {}

class SlotInitial extends SlotState {}

/// أول تحميل للشاشة فقط
class SlotLoading extends SlotState {}

class SlotLoaded extends SlotState {
  final List<SlotModel> slots;

  SlotLoaded(this.slots);
}

/// أثناء حفظ Slot معين
class SlotUpdating extends SlotState {
  final int slotNumber;

  SlotUpdating(this.slotNumber);
}

class SlotUpdated extends SlotState {}

/// أثناء Refill لـ Slot معين
class SlotRefilling extends SlotState {
  final int slotNumber;

  SlotRefilling(this.slotNumber);
}

class SlotRefilled extends SlotState {}

class SlotError extends SlotState {
  final String message;

  SlotError(this.message);
}