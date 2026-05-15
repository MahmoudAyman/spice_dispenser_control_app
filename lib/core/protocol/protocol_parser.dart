import 'responses/message_type.dart';

class ProtocolParser {

  static MessageType parseType(
      String type,
      ) {

    switch (type) {

      case 'ack':
        return MessageType.ack;

      case 'status':
        return MessageType.status;

      case 'levels':
        return MessageType.levels;

      case 'alert':
        return MessageType.alert;

      case 'machine_state':
        return MessageType.machineState;

      default:
        return MessageType.unknown;
    }
  }
}