import 'dart:async';

import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'packet_manager.dart';

import 'protocol_parser.dart';

import 'responses/ack_response.dart';

import 'responses/status_response.dart';

import 'responses/alert_response.dart';

import 'responses/levels_response.dart';

import 'responses/manifest_response.dart';

class ProtocolService {

  /// ACK STREAM

  final StreamController<AckResponse>
  ackController =
  StreamController.broadcast();

  /// MANIFEST STREAM

  final StreamController<ManifestResponse>
  manifestController =
  StreamController.broadcast();

  /// STATUS STREAM

  final StreamController<StatusResponse>
  statusController =
  StreamController.broadcast();

  /// ALERT STREAM

  final StreamController<AlertResponse>
  alertController =
  StreamController.broadcast();

  /// LEVELS STREAM

  final StreamController<LevelsResponse>
  levelsController =
  StreamController.broadcast();

  /// MACHINE VERSION

  int machineVersion = 1;

  /// MACHINE INITIALIZED

  bool machineInitialized = false;

  /// STATUS LISTENER

  Future<void> startStatusListening(
      BluetoothCharacteristic
      characteristic,
      ) async {

    await characteristic
        .setNotifyValue(true);

    characteristic.lastValueStream
        .listen(
          (value) {

        if (value.isEmpty) {
          return;
        }

        try {

          final jsonString =
          PacketManager.mergePackets(
            value,
          );

          print(
            'RAW STATUS RESPONSE: $jsonString',
          );

          final data =
          jsonDecode(
            jsonString,
          );

          print(
            'PARSED STATUS RESPONSE: $data',
          );

          final parsed =
          ProtocolParser.parse(
            data,
          );

          /// ACK

          if (parsed
          is AckResponse) {

            ackController.add(
              parsed,
            );
          }

          /// STATUS

          else if (parsed
          is StatusResponse) {

            machineVersion =
                data['version'] ?? 1;

            machineInitialized =
                data['initialized']
                    ?? false;

            statusController.add(
              parsed,
            );
          }

          /// ALERT

          else if (parsed
          is AlertResponse) {

            alertController.add(
              parsed,
            );
          }

        } catch (e) {

          print(
            'STATUS PARSE ERROR: $e',
          );
        }
      },
    );
  }

  /// SYNC LISTENER

  Future<void> startSyncListening(
      BluetoothCharacteristic
      characteristic,
      ) async {

    await characteristic
        .setNotifyValue(true);

    characteristic.lastValueStream
        .listen(
          (value) {

        if (value.isEmpty) {
          return;
        }

        try {

          final jsonString =
          PacketManager.mergePackets(
            value,
          );

          print(
            'RAW SYNC RESPONSE: $jsonString',
          );

          final data =
          jsonDecode(
            jsonString,
          );

          print(
            'PARSED SYNC RESPONSE: $data',
          );

          final parsed =
          ProtocolParser.parse(
            data,
          );

          if (parsed
          is LevelsResponse) {

            levelsController.add(
              parsed,
            );
          }

          else if (parsed
          is ManifestResponse) {

            manifestController.add(
              parsed,
            );
          }

        } catch (e) {

          print(
            'SYNC PARSE ERROR: $e',
          );
        }
      },
    );
  }

  /// SEND COMMAND

  Future<AckResponse> sendCommand({

    required BluetoothCharacteristic
    writeCharacteristic,

    required Map<String, dynamic>
    command,
  }) async {

    final jsonString =
    jsonEncode(command);

    print(
      'SENDING COMMAND: $jsonString',
    );

    final packets =
    PacketManager.splitPacket(
      jsonString,
    );

    final completer =
    Completer<AckResponse>();

    late StreamSubscription sub;

    sub = ackController.stream.listen(
          (ack) {

        print(
          'ACK RECEIVED: ${ack.status}',
        );

        if (!completer
            .isCompleted) {

          completer.complete(
            ack,
          );
        }

        sub.cancel();
      },
    );

    for (List<int> packet
    in packets) {

      print(
        'SENDING PACKET: $packet',
      );

      await writeCharacteristic
          .write(
        packet,

        withoutResponse: false,
      );
    }

    return completer.future.timeout(
      const Duration(seconds: 3),

      onTimeout: () {

        throw Exception(
          'ACK Timeout',
        );
      },
    );
  }

  /// DISPOSE

  void dispose() {

    ackController.close();

    statusController.close();

    alertController.close();

    levelsController.close();

    manifestController.close();
  }
}