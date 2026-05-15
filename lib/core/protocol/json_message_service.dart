import 'dart:convert';

import 'models/base_packet.dart';

class JsonMessageService {

  static String createMessage(
      BasePacket packet,
      ) {

    return jsonEncode(
      packet.toJson(),
    );
  }
}