class BasePacket {

  final String type;

  final dynamic payload;

  final String uuid;

  final int timestamp;

  BasePacket({
    required this.type,
    required this.payload,
    required this.uuid,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {

    return {
      'type': type,
      'payload': payload,
      'uuid': uuid,
      'timestamp': timestamp,
    };
  }
}