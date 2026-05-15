import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../constants/ble_constants.dart';
import '../protocol/commands/handshake_command.dart';
import '../protocol/protocol_service.dart';
import '../protocol/responses/ack_response.dart';

class BleService {

  final ProtocolService
  protocolService =
  ProtocolService();

  BluetoothCharacteristic?
  writeCharacteristic;

  BluetoothCharacteristic?
  notifyCharacteristic;

  BluetoothDevice?
  connectedDevice;

  /// SCAN DEVICES
  Future<List<ScanResult>>
  scanDevices() async {

    final Map<String, ScanResult>
    uniqueDevices = {};

    await FlutterBluePlus.startScan(
      timeout:
      const Duration(seconds: 4),
    );

    FlutterBluePlus.scanResults.listen(
          (results) {

        for (var result in results) {

          final name =
          result.device.platformName
              .toLowerCase();

          if (name.contains(
            BleConstants.deviceName,
          )) {

            uniqueDevices[
            result.device.remoteId.str] =
                result;
          }
        }
      },
    );

    await Future.delayed(
      const Duration(seconds: 4),
    );

    await FlutterBluePlus.stopScan();

    return uniqueDevices.values
        .toList();
  }

  /// CONNECT DEVICE
  Future<void> connectToDevice(
      BluetoothDevice device,
      ) async {

    connectedDevice = device;

    await device.connect();

    device.connectionState.listen(
          (state) {

        if (state ==
            BluetoothConnectionState
                .disconnected) {

          print(
            'Device disconnected',
          );
        }
      },
    );

    final services =
    await device.discoverServices();

    for (var service in services) {

      if (service.uuid.toString() ==
          BleConstants.serviceUuid) {

        for (var characteristic
        in service.characteristics) {

          /// WRITE
          if (characteristic.uuid
              .toString() ==
              BleConstants
                  .writeCharacteristicUuid) {

            writeCharacteristic =
                characteristic;
          }

          /// NOTIFY
          if (characteristic.uuid
              .toString() ==
              BleConstants
                  .notifyCharacteristicUuid) {

            notifyCharacteristic =
                characteristic;
          }
        }
      }
    }

    /// START NOTIFICATIONS
    if (notifyCharacteristic != null) {

      await protocolService
          .startListening(
        notifyCharacteristic!,
      );
    }
  }

  /// HANDSHAKE
  Future<bool> sendHandshake({
    required String uuid,
  }) async {

    if (writeCharacteristic ==
        null) {

      return false;
    }

    final command =
    HandshakeCommand(
      uuid: uuid,
      version: 1,
    );

    try {

      final AckResponse ack =
      await protocolService
          .sendCommand(
        writeCharacteristic:
        writeCharacteristic!,

        command:
        command.toJson(),
      );

      return ack.isSuccess;

    } catch (e) {

      print(
        'Handshake Error: $e',
      );

      return false;
    }
  }

  /// SEND RAW COMMAND
  Future<AckResponse> sendCommand({
    required Map<String, dynamic>
    command,
  }) async {

    if (writeCharacteristic ==
        null) {

      throw Exception(
        'Write characteristic is null',
      );
    }

    return await protocolService
        .sendCommand(
      writeCharacteristic:
      writeCharacteristic!,

      command: command,
    );
  }

  /// DISCONNECT
  Future<void> disconnectDevice()
  async {

    if (connectedDevice != null) {

      await connectedDevice!
          .disconnect();
    }
  }

  /// DISPOSE
  void dispose() {

    protocolService.dispose();
  }
}