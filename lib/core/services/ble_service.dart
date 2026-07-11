import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../constants/ble_constants.dart';
import '../protocol/commands/handshake_command.dart';
import '../protocol/protocol_service.dart';
import '../protocol/responses/ack_response.dart';

class BleService {
  static final BleService _instance =
  BleService._internal();

  factory BleService() => _instance;

  BleService._internal();

  final ProtocolService protocolService =
  ProtocolService();

  BluetoothCharacteristic?
  writeCharacteristic;

  BluetoothCharacteristic?
  statusCharacteristic;

  BluetoothCharacteristic?
  syncCharacteristic;

  BluetoothDevice?
  connectedDevice;

  /// CONNECTION STATUS

  bool get isConnected {
    return connectedDevice != null;
  }

  /// SCAN DEVICES

  Future<List<ScanResult>>
  scanDevices() async {
    final Map<String, ScanResult>
    uniqueDevices = {};

    print('STARTING BLE SCAN...');

    await FlutterBluePlus.startScan(
      timeout: const Duration(
        seconds: 4,
      ),
    );

    FlutterBluePlus.scanResults
        .listen((results) {
      for (var result in results) {
        final name = result
            .device.platformName
            .toLowerCase();

        print('FOUND DEVICE: $name');

        if (name.contains(
          BleConstants.deviceName,
        )) {
          uniqueDevices[result
              .device.remoteId.str] =
              result;
        }
      }
    });

    await Future.delayed(
      const Duration(seconds: 4),
    );

    await FlutterBluePlus.stopScan();

    print('SCAN FINISHED');

    return uniqueDevices.values.toList();
  }

  /// CONNECT DEVICE

  Future<void> connectToDevice(
      BluetoothDevice device,
      ) async {
    if (connectedDevice != null) {
      print('ALREADY CONNECTED');
      return;
    }

    connectedDevice = device;

    print('CONNECTING TO DEVICE...');

    await connectedDevice!.connect();

    print('DEVICE CONNECTED');

    connectedDevice!
        .connectionState
        .listen((state) {
      print(
        'CONNECTION STATE: $state',
      );

      if (state ==
          BluetoothConnectionState
              .disconnected) {
        print(
          'DEVICE DISCONNECTED',
        );

        connectedDevice = null;
        writeCharacteristic = null;
        statusCharacteristic = null;
        syncCharacteristic = null;
      }
    });

    final services =
    await connectedDevice!
        .discoverServices();

    print(
      'DISCOVERED SERVICES: ${services.length}',
    );

    for (var service in services) {
      print(
        'SERVICE UUID: ${service.uuid}',
      );

      if (service.uuid.toString() ==
          BleConstants.serviceUuid) {
        for (var characteristic
        in service
            .characteristics) {
          print(
            'CHAR UUID: ${characteristic.uuid}',
          );

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

    if (statusCharacteristic != null) {
      print(
        'STARTING STATUS LISTENER',
      );

      await protocolService
          .startStatusListening(
        statusCharacteristic!,
      );
    }

    if (syncCharacteristic != null) {
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

  Future<bool> sendHandshake({
    required String uuid,
  }) async {
    if (writeCharacteristic ==
        null) {
      print(
        'WRITE CHARACTERISTIC IS NULL',
      );
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

  /// UPDATE SLOT

  Future<bool> updateSlot({
    required int slot,
    required String name,
  }) async {
    try {
      final ack =
      await sendCommand(
        command: {
          "type": "update_slot",
          "slot": slot,
          "name": name,
        },
      );

      return ack.isSuccess;
    } catch (e) {
      print(
        'UPDATE SLOT ERROR: $e',
      );
      return false;
    }
  }

  /// REFILL SLOT

  Future<bool> refillSlot(
      int slot,
      ) async {
    try {
      final ack =
      await sendCommand(
        command: {
          "type": "refill",
          "slot": slot,
        },
      );

      return ack.isSuccess;
    } catch (e) {
      print(
        'REFILL SLOT ERROR: $e',
      );
      return false;
    }
  }

  /// GET LEVELS

  Future<bool> getLevels() async {
    try {
      final ack =
      await sendCommand(
        command: {
          "type": "get_levels",
        },
      );

      return ack.isSuccess;
    } catch (e) {
      print(
        'GET LEVELS ERROR: $e',
      );
      return false;
    }
  }

  /// REQUEST LEVELS

  Future<void> requestLevels() async {
    final success =
    await getLevels();

    if (!success) {
      throw Exception(
        'Request levels failed',
      );
    }
  }

  /// SEND RAW COMMAND

  Future<AckResponse>
  sendCommand({
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

  Future<void>
  disconnectDevice() async {
    try {
      if (connectedDevice != null) {
        await connectedDevice!
            .disconnect();
      }
    } catch (e) {
      print(
        'DISCONNECT ERROR: $e',
      );
    }

    connectedDevice = null;
    writeCharacteristic = null;
    statusCharacteristic = null;
    syncCharacteristic = null;
  }

  /// DISPOSE

  void dispose() {
    protocolService.dispose();
  }
}