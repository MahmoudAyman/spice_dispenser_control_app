import 'package:flutter/foundation.dart';
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

      final ack =
      await bleService
          .sendHandshake(
        uuid: uuid,
      );

      if (ack != null && ack.isSuccess) {

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

        /// REQUEST PHYSICAL MANIFEST ONLY IF CONFIGURED (READY)

        final isConfigured = ack.status.toLowerCase() == 'ready' || ack.newDevice == false;

        if (isConfigured) {
          debugPrint('MACHINE IS CONFIGURED. Triggering manifest sync and level poller asynchronously...');
          // Trigger manifest sync and immediately after, request spice levels
          syncService.requestManifest().then((_) {
            syncService.requestSync(); // Immediate levels request to clear any old cached dashboard values!
          }).catchError((e) {
            debugPrint('Failed to request manifest/levels in background: $e');
          });
        } else {
          debugPrint('MACHINE IS UNCONFIGURED. Clearing old slots cache and routing to Onboarding Setup.');
          await StorageService.clearSlotsForMachine(bleDevice.device.remoteId.str);
        }

        emit(
          BluetoothHandshakeSuccess(isConfigured: isConfigured),
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

      final ack =
      await bleService
          .sendHandshake(
        uuid: uuid,
      );

      if (ack != null && ack.isSuccess) {

        /// START SYNC LISTENERS

        syncService.startListening();

        /// REQUEST PHYSICAL MANIFEST ONLY IF CONFIGURED (READY)

        final isConfigured = ack.status.toLowerCase() == 'ready' || ack.newDevice == false;

        if (isConfigured) {
          debugPrint('MACHINE IS CONFIGURED. Triggering manifest sync and level poller asynchronously...');
          // Trigger manifest sync and immediately after, request spice levels
          syncService.requestManifest().then((_) {
            syncService.requestSync(); // Immediate levels request to clear any old cached dashboard values!
          }).catchError((e) {
            debugPrint('Failed to request manifest/levels in background: $e');
          });
        } else {
          debugPrint('MACHINE IS UNCONFIGURED. Clearing old slots cache and routing to Onboarding Setup.');
          await StorageService.clearSlotsForMachine(foundDevice.device.remoteId.str);
        }

        emit(
          BluetoothHandshakeSuccess(isConfigured: isConfigured),
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