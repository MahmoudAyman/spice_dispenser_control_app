part of 'machine_state_cubit.dart';

abstract class MachineStateState {}

class MachineStateInitial
    extends MachineStateState {}

class MachineStatusUpdated
    extends MachineStateState {

  final StatusResponse status;

  MachineStatusUpdated({
    required this.status,
  });
}

class MachineAlertState
    extends MachineStateState {

  final AlertResponse alert;

  MachineAlertState({
    required this.alert,
  });
}