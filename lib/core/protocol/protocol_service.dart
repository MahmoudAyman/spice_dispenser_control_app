import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:spice_dispenser_app/core/protocol/responses/status_response.dart';

import 'packet_manager.dart';
import 'protocol_parser.dart';

import 'responses/ack_response.dart';
import 'responses/alert_response.dart';
import 'responses/levels_response.dart';
import 'responses/machine_state_response.dart';
import 'responses/message_type.dart';

class ProtocolService {

  StreamSubscription<List<int>>?
  _notificationSubscription;

  Completer<AckResponse>?
  _ackCompleter;

  /// STREAM CONTROLLERS

  final StreamController<
      StatusResponse>
  statusController =
  StreamController.broadcast();

  final StreamController<
      LevelsResponse>
  levelsController =
  StreamController.broadcast();

  final StreamController<
      AlertResponse>
  alertController =
  StreamController.broadcast();

  final StreamController<
      MachineStateResponse>
  machineStateController =
  StreamController.broadcast();

  /// START LISTENING

  Future<void> startListening(
      BluetoothCharacteristic
      notifyCharacteristic,
      ) async {

    await notifyCharacteristic
        .setNotifyValue(true);

    _notificationSubscription =
        notifyCharacteristic
            .onValueReceived
            .listen(
              (value) {

            try {

              final jsonString =
              PacketManager
                  .mergePackets(
                value,
              );

              final jsonData =
              jsonDecode(
                jsonString,
              );

              final type =
              ProtocolParser
                  .parseType(
                jsonData['type'],
              );

              switch (type) {

              /// ACK
                case MessageType.ack:

                  final ack =
                  AckResponse
                      .fromJson(
                    jsonData,
                  );

                  _ackCompleter
                      ?.complete(
                    ack,
                  );

                  break;

              /// STATUS
                case MessageType.status:

                  final status =
                  StatusResponse
                      .fromJson(
                    jsonData,
                  );

                  statusController
                      .add(
                    status,
                  );

                  break;

              /// LEVELS
                case MessageType.levels:

                  final levels =
                  LevelsResponse
                      .fromJson(
                    jsonData,
                  );

                  levelsController
                      .add(
                    levels,
                  );

                  break;

              /// ALERT
                case MessageType.alert:

                  final alert =
                  AlertResponse
                      .fromJson(
                    jsonData,
                  );

                  alertController
                      .add(
                    alert,
                  );

                  break;

              /// MACHINE STATE
                case MessageType.machineState:

                  final state =
                  MachineStateResponse
                      .fromJson(
                    jsonData,
                  );

                  machineStateController
                      .add(
                    state,
                  );

                  break;

                default:
                  break;
              }

            } catch (e) {

              print(
                'Protocol Parse Error: $e',
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

    final packets =
    PacketManager
        .splitPacket(
      jsonString,
    );

    _ackCompleter =
        Completer<AckResponse>();

    for (final packet in packets) {

      await writeCharacteristic
          .write(
        packet,
        withoutResponse: false,
      );
    }

    return _ackCompleter!
        .future
        .timeout(
      const Duration(
        seconds: 3,
      ),
    );
  }

  /// DISPOSE

  void dispose() {

    _notificationSubscription
        ?.cancel();

    statusController.close();

    levelsController.close();

    alertController.close();

    machineStateController
        .close();
  }
}