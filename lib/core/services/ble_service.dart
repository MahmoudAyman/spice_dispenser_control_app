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
  statusCharacteristic;

  BluetoothCharacteristic?
  syncCharacteristic;

  BluetoothDevice?
  connectedDevice;

  /// SCAN DEVICES

  Future<List<ScanResult>>
  scanDevices() async {

    final Map<String, ScanResult>
    uniqueDevices = {};

    print(
      'STARTING BLE SCAN...',
    );

    await FlutterBluePlus
        .startScan(
      timeout:
      const Duration(seconds: 4),
    );

    FlutterBluePlus
        .scanResults
        .listen(
          (results) {

        for (var result
        in results) {

          final name =
          result.device
              .platformName
              .toLowerCase();

          print(
            'FOUND DEVICE: $name',
          );

          if (name.contains(
            BleConstants.deviceName,
          )) {

            uniqueDevices[
            result.device
                .remoteId
                .str] =
                result;
          }
        }
      },
    );

    await Future.delayed(
      const Duration(seconds: 4),
    );

    await FlutterBluePlus
        .stopScan();

    print(
      'SCAN FINISHED',
    );

    return uniqueDevices
        .values
        .toList();
  }

  /// CONNECT DEVICE

  Future<void> connectToDevice(
      BluetoothDevice device,
      ) async {

    connectedDevice =
        device;

    print(
      'CONNECTING TO DEVICE...',
    );

    await connectedDevice!
        .connect();

    print(
      'DEVICE CONNECTED',
    );

    connectedDevice!
        .connectionState
        .listen(
          (state) {

        print(
          'CONNECTION STATE: $state',
        );

        if (state ==
            BluetoothConnectionState
                .disconnected) {

          print(
            'DEVICE DISCONNECTED',
          );
        }
      },
    );

    final services =
    await connectedDevice!
        .discoverServices();

    print(
      'DISCOVERED SERVICES: ${services.length}',
    );

    for (var service
    in services) {

      print(
        'SERVICE UUID: ${service.uuid}',
      );

      if (service.uuid
          .toString() ==
          BleConstants
              .serviceUuid) {

        for (var characteristic
        in service.characteristics) {

          print(
            'CHAR UUID: ${characteristic.uuid}',
          );

          /// WRITE

          if (characteristic.uuid
              .toString() ==
              BleConstants
                  .writeCharacteristicUuid) {

            writeCharacteristic =
                characteristic;

            print(
              'WRITE CHARACTERISTIC FOUND',
            );
          }

          /// STATUS

          if (characteristic.uuid
              .toString() ==
              BleConstants
                  .statusCharacteristicUuid) {

            statusCharacteristic =
                characteristic;

            print(
              'STATUS CHARACTERISTIC FOUND',
            );
          }

          /// SYNC

          if (characteristic.uuid
              .toString() ==
              BleConstants
                  .syncCharacteristicUuid) {

            syncCharacteristic =
                characteristic;

            print(
              'SYNC CHARACTERISTIC FOUND',
            );
          }
        }
      }
    }

    /// START STATUS LISTENER

    if (statusCharacteristic
        != null) {

      print(
        'STARTING STATUS LISTENER',
      );

      await protocolService
          .startStatusListening(
        statusCharacteristic!,
      );
    }

    /// START SYNC LISTENER

    if (syncCharacteristic
        != null) {

      print(
        'STARTING SYNC LISTENER',
      );

      await protocolService
          .startSyncListening(
        syncCharacteristic!,
      );
    }
  }

  /// HANDSHAKE

  Future<AckResponse?> sendHandshake({
    required String uuid,
  }) async {

    if (writeCharacteristic
        == null) {

      print(
        'WRITE CHARACTERISTIC IS NULL',
      );

      return null;
    }

    final command =
    HandshakeCommand(
      uuid: uuid,
      version: 1,
    );

    try {

      print(
        'SENDING HANDSHAKE...',
      );

      print(
        command.toJson(),
      );

      final AckResponse ack =
      await protocolService
          .sendCommand(
        writeCharacteristic:
        writeCharacteristic!,

        command:
        command.toJson(),
      );

      print(
        'ACK SUCCESS: ${ack.isSuccess}',
      );

      print(
        'ACK STATUS: ${ack.status}',
      );

      return ack;

    } catch (e) {

      print(
        'Handshake Error: $e',
      );

      return null;
    }
  }

  /// SEND RAW COMMAND

  Future<AckResponse>
  sendCommand({

    required Map<String, dynamic>
    command,

    Duration timeout = const Duration(seconds: 3),
  }) async {

    if (writeCharacteristic
        == null) {

      throw Exception(
        'Write characteristic is null',
      );
    }

    return await protocolService
        .sendCommand(
      writeCharacteristic:
      writeCharacteristic!,

      command: command,

      timeout: timeout,
    );
  }

  /// WRITE RAW COMMAND (NO ACK EXPECTED)

  Future<void>
  writeCommand({
    required Map<String, dynamic>
    command,
  }) async {

    if (writeCharacteristic
        == null) {

      throw Exception(
        'Write characteristic is null',
      );
    }

    await protocolService
        .writeCommand(
      writeCharacteristic:
      writeCharacteristic!,

      command: command,
    );
  }

  /// DISCONNECT

  Future<void>
  disconnectDevice()
  async {

    if (connectedDevice
        != null) {

      await connectedDevice!
          .disconnect();
    }
  }

  /// DISPOSE

  void dispose() {

    protocolService.dispose();
  }
}