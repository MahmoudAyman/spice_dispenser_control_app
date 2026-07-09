import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/services/ble_service.dart';
import '../../../../../core/services/sync_service.dart';

import '../../../../../core/storage/storage_service.dart';

import '../../../../../core/services/uuid_service.dart';

import '../../data/models/ble_device_model.dart';
import '../../data/models/last_connected_machine_model.dart';

import 'bluetooth_state.dart';

class BluetoothCubit
    extends Cubit<BluetoothState> {

  final BleService bleService;

  late final SyncService
  syncService;

  BluetoothCubit(
      this.bleService,
      ) : super(
    BluetoothInitial(),
  ) {

    syncService = SyncService(
      bleService: bleService,
      protocolService:
      bleService.protocolService,
    );
  }

  /// SCAN DEVICES

  Future<void> scanDevices()
  async {

    emit(
      BluetoothLoading(),
    );

    try {

      final results =
      await bleService
          .scanDevices();

      final devices =
      results.map((result) {

        return BleDeviceModel(
          name:
          result.device
              .platformName,

          id:
          result.device
              .remoteId.str,

          rssi:
          result.rssi,

          device:
          result.device,
        );
      }).toList();

      emit(
        BluetoothLoaded(
          devices,
        ),
      );

    } catch (e) {

      emit(
        BluetoothError(
          e.toString(),
        ),
      );
    }
  }

  /// CONNECT DEVICE

  Future<void> connectToDevice(
      BleDeviceModel bleDevice,
      ) async {

    try {

      emit(
        BluetoothConnecting(),
      );

      /// CONNECT

      await bleService
          .connectToDevice(
        bleDevice.device,
      );

      emit(
        BluetoothConnected(),
      );

      /// UUID

      final uuid =
      await UuidService
          .getUuid();

      /// HANDSHAKE

      final success =
      await bleService
          .sendHandshake(
        uuid: uuid,
      );

      if (success) {

        /// SAVE MACHINE

        await StorageService
            .saveLastMachine(
          LastConnectedMachineModel(
            deviceId:
            bleDevice
                .device
                .remoteId
                .str,

            deviceName:
            bleDevice.name,
          ),
        );

        /// START SYNC LISTENERS

        syncService.startListening();

        /// CHECK MACHINE VERSION

        final machineVersion =
            bleService
                .protocolService
                .machineVersion;

        final needsSync =
        await syncService
            .needsSync(
          machineVersion:
          machineVersion,
        );

        /// REQUEST FULL SYNC

        if (needsSync) {

          await syncService
              .requestSync();
        }

        emit(
          BluetoothHandshakeSuccess(),
        );

      } else {

        emit(
          BluetoothHandshakeFailed(),
        );
      }

    } catch (e) {

      emit(
        BluetoothError(
          e.toString(),
        ),
      );
    }
  }

  /// AUTO RECONNECT

  Future<void>
  tryAutoReconnect() async {

    try {

      emit(
        BluetoothAutoConnecting(),
      );

      final lastMachine =
      StorageService
          .getLastMachine();

      if (lastMachine == null) {

        emit(
          BluetoothInitial(),
        );

        return;
      }

      final results =
      await bleService
          .scanDevices();

      final devices =
      results.map((result) {

        return BleDeviceModel(
          name:
          result.device
              .platformName,

          id:
          result.device
              .remoteId
              .str,

          rssi:
          result.rssi,

          device:
          result.device,
        );
      }).toList();

      BleDeviceModel?
      foundDevice;

      try {

        foundDevice =
            devices.firstWhere(
                  (device) {

                return device.id ==
                    lastMachine
                        .deviceId;
              },
            );

      } catch (_) {

        foundDevice = null;
      }

      if (foundDevice == null) {

        emit(
          BluetoothInitial(),
        );

        return;
      }

      emit(
        BluetoothConnecting(),
      );

      /// CONNECT

      await bleService
          .connectToDevice(
        foundDevice.device,
      );

      /// UUID

      final uuid =
      await UuidService
          .getUuid();

      /// HANDSHAKE

      final success =
      await bleService
          .sendHandshake(
        uuid: uuid,
      );

      if (success) {

        /// START SYNC LISTENERS

        syncService.startListening();

        /// CHECK MACHINE VERSION

        final machineVersion =
            bleService
                .protocolService
                .machineVersion;

        final needsSync =
        await syncService
            .needsSync(
          machineVersion:
          machineVersion,
        );

        /// REQUEST FULL SYNC

        if (needsSync) {

          await syncService
              .requestSync();
        }

        emit(
          BluetoothHandshakeSuccess(),
        );

      } else {

        emit(
          BluetoothHandshakeFailed(),
        );
      }

    } catch (e) {

      emit(
        BluetoothError(
          e.toString(),
        ),
      );
    }
  }

  @override
  Future<void> close() {

    bleService.dispose();

    return super.close();
  }
}