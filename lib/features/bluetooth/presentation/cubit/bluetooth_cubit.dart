import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide BluetoothState;

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

  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  BluetoothCubit(
      this.bleService,
      ) : super(
    BluetoothInitial(),
  ) {

    syncService = SyncService(
      bleService: bleService,
      protocol:
      bleService.protocol,
    );
  }

  /// SCAN DEVICES

  Future<void> scanDevices()
  async {

    emit(
      BluetoothLoading(),
    );

    try {

      final currentAdapterState = await FlutterBluePlus.adapterState.first;
      if (currentAdapterState != BluetoothAdapterState.on) {
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
        BluetoothConnecting(message: 'Connecting to device...'),
      );

      /// CONNECT

      await bleService
          .connectToDevice(
        bleDevice.device,
      );

      _connectionStateSubscription?.cancel();
      _connectionStateSubscription = bleService.connectedDevice!.connectionState.listen((connectionState) {
        if (connectionState == BluetoothConnectionState.disconnected) {
          debugPrint('Cubit detected BLE disconnection!');
          emit(BluetoothInitial());
        }
      });

      emit(
        BluetoothConnecting(message: 'Authenticating with device...'),
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

      if (!StorageService.isAutoConnectEnabled()) {
        emit(
          BluetoothInitial(),
        );
        return;
      }

      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        emit(
          BluetoothInitial(),
        );
        return;
      }

      final favoriteId = StorageService.getFavoriteDeviceId();

      if (favoriteId == null) {
        emit(
          BluetoothInitial(),
        );
        return;
      }

      emit(
        BluetoothAutoConnecting(message: 'Scanning for favorite device...'),
      );

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

                return device.id == favoriteId;
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
        BluetoothAutoConnecting(message: 'Favorite device found!'),
      );
      await Future.delayed(const Duration(milliseconds: 600));

      emit(
        BluetoothConnecting(message: 'Connecting to favorite device...'),
      );

      /// CONNECT

      await bleService
          .connectToDevice(
        foundDevice.device,
      );

      _connectionStateSubscription?.cancel();
      _connectionStateSubscription = bleService.connectedDevice!.connectionState.listen((connectionState) {
        if (connectionState == BluetoothConnectionState.disconnected) {
          debugPrint('Cubit detected BLE disconnection during auto-reconnect!');
          emit(BluetoothInitial());
        }
      });

      emit(
        BluetoothConnecting(message: 'Authenticating with device...'),
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
            foundDevice
                .device
                .remoteId
                .str,

            deviceName:
            foundDevice.name,
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

  /// SET FAVORITE DEVICE

  void setFavoriteDevice(String deviceId) {
    final currentFavorite = StorageService.getFavoriteDeviceId();
    if (currentFavorite == deviceId) {
      StorageService.setFavoriteDeviceId(null);
    } else {
      StorageService.setFavoriteDeviceId(deviceId);
    }

    if (state is BluetoothLoaded) {
      emit(BluetoothLoaded(List.from((state as BluetoothLoaded).devices)));
    }
  }

  /// DISCONNECT

  Future<void> disconnect() async {
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    await bleService.disconnectDevice();
    emit(BluetoothInitial());
  }

  @override
  Future<void> close() {
    _connectionStateSubscription?.cancel();
    bleService.dispose();

    return super.close();
  }
}