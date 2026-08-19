import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/protocol/responses/alert_response.dart';

import '../../../../core/protocol/responses/status_response.dart';

import '../../../../core/services/ble_service.dart';

part 'machine_state_state.dart';

class MachineStateCubit
    extends Cubit<MachineStateState> {

  final BleService bleService;

  StreamSubscription?
  statusSub;

  StreamSubscription?
  alertSub;

  MachineStateCubit(
      this.bleService,
      ) : super(
    MachineStateInitial(),
  ) {

    listenToMachine();
  }

  void listenToMachine() {

    /// STATUS STREAM

    statusSub =
        bleService
            .protocol
            .statusController
            .stream
            .listen(
              (status) {

            emit(
              MachineStatusUpdated(
                status:
                status,
              ),
            );
          },
        );

    /// ALERT STREAM

    alertSub =
        bleService
            .protocol
            .alertController
            .stream
            .listen(
              (alert) {

            emit(
              MachineAlertState(
                alert:
                alert,
              ),
            );
          },
        );
  }

  @override
  Future<void> close() {

    statusSub?.cancel();

    alertSub?.cancel();

    return super.close();
  }
}