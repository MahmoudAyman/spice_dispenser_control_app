import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../constants/ble_constants.dart';
import 'uuid_service.dart';

class BleService {

  Future<List<ScanResult>> scanDevices() async {

    final Map<String, ScanResult>
    uniqueDevices = {};

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 4),
    );

    FlutterBluePlus.scanResults.listen((results) {

      for (var result in results) {

        final name = result.device.platformName
            .toLowerCase();

        if (name.contains(
          BleConstants.deviceName,
        )) {

          uniqueDevices[
          result.device.remoteId.str] =
              result;
        }
      }
    });

    await Future.delayed(
      const Duration(seconds: 4),
    );

    await FlutterBluePlus.stopScan();

    return uniqueDevices.values.toList();
  }

  Future<void> connectToDevice(
      BluetoothDevice device,
      ) async {

    await device.connect();

    device.connectionState.listen((state) {

      if (state ==
          BluetoothConnectionState
              .disconnected) {

        print('Device disconnected');
      }
    });
  }

  Future<bool> sendHandshake(
      BluetoothDevice device,
      ) async {

    final services =
    await device.discoverServices();

    BluetoothCharacteristic? writeChar;

    BluetoothCharacteristic? notifyChar;

    for (var service in services) {

      if (service.uuid.toString() ==
          BleConstants.serviceUuid) {

        for (var characteristic
        in service.characteristics) {

          if (characteristic.uuid.toString() ==
              BleConstants
                  .writeCharacteristicUuid) {

            writeChar = characteristic;
          }

          if (characteristic.uuid.toString() ==
              BleConstants
                  .notifyCharacteristicUuid) {

            notifyChar = characteristic;
          }
        }
      }
    }

    if (writeChar == null ||
        notifyChar == null) {

      return false;
    }

    await notifyChar.setNotifyValue(true);

    final uuid =
    await UuidService.getUuid();

    final handshake = {
      'type': 'handshake',
      'uuid': uuid,
      'version': 1,
    };

    final completer = Completer<bool>();

    notifyChar.onValueReceived.listen((value) {

      final decoded = jsonDecode(
        utf8.decode(value),
      );

      if (decoded['type'] == 'ack' &&
          decoded['status'] == 'success') {

        completer.complete(true);
      }
    });

    await writeChar.write(
      utf8.encode(
        jsonEncode(handshake),
      ),
    );

    return completer.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () => false,
    );
  }

  Future<void> disconnectDevice(
      BluetoothDevice device,
      ) async {

    await device.disconnect();
  }
}