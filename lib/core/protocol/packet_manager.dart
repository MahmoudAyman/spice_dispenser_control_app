import 'dart:convert';

class PacketManager {

  static const int mtuSize =
  180;

  /// SPLIT LARGE JSON

  static List<List<int>>
  splitPacket(
      String jsonString,
      ) {

    final bytes =
    utf8.encode(
      jsonString,
    );

    List<List<int>> packets =
    [];

    for (
    int i = 0;
    i < bytes.length;
    i += mtuSize
    ) {

      final end =
      (i + mtuSize <
          bytes.length)
          ? i + mtuSize
          : bytes.length;

      packets.add(
        bytes.sublist(i, end),
      );
    }

    return packets;
  }

  /// MERGE RECEIVED PACKETS

  static String mergePackets(
      List<int> data,
      ) {

    return utf8.decode(data);
  }
}