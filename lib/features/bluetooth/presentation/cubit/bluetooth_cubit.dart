import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/services/ble_service.dart';
import '../../data/models/ble_device_model.dart';
import 'bluetooth_state.dart';
import '../../../../../core/storage/storage_service.dart';
import '../../data/models/last_connected_machine_model.dart';

class BluetoothCubit extends Cubit<BluetoothState> {
  final BleService bleService;

  BluetoothCubit(this.bleService)
      : super(BluetoothInitial());

  Future<void> scanDevices() async {
    emit(BluetoothLoading());

    try {
      final results = await bleService.scanDevices();

      final devices = results.map((result) {
        return BleDeviceModel(
          name: result.device.platformName,
          id: result.device.remoteId.str,
          rssi: result.rssi,
          device: result.device,
        );
      }).toList();

      emit(BluetoothLoaded(devices));
    } catch (e) {
      emit(BluetoothError(e.toString()));
    }
  }

  Future<void> connectToDevice(
      BleDeviceModel bleDevice,
      ) async {
    try {
      emit(BluetoothConnecting());

      await bleService.connectToDevice(
        bleDevice.device,
      );

      emit(BluetoothConnected());

      final success = await bleService
          .sendHandshake(
        bleDevice.device,
      );

      if (success) {

        await StorageService
            .saveLastMachine(
          LastConnectedMachineModel(
            deviceId:
            bleDevice.device.remoteId.str,

            deviceName:
            bleDevice.name,
          ),
        );

        emit(BluetoothHandshakeSuccess());
      } else {
        emit(BluetoothHandshakeFailed());
      }
    } catch (e) {
      emit(BluetoothError(e.toString()));
    }
  }
}