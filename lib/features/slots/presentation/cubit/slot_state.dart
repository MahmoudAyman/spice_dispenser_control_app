import '../../../container_management/data/models/slot_model.dart';

abstract class SlotState {}

class SlotInitial extends SlotState {}

class SlotLoading extends SlotState {}

class SlotLoaded extends SlotState {

  final List<SlotModel> slots;

  SlotLoaded(this.slots);
}

class SlotUpdating extends SlotState {}

class SlotUpdated extends SlotState {}

class SlotRefilling extends SlotState {}

class SlotRefilled extends SlotState {}

class SlotError extends SlotState {

  final String message;

  SlotError(this.message);
}