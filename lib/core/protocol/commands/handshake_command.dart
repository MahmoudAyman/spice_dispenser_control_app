class HandshakeCommand {

  final String type;

  final String uuid;

  final int version;

  HandshakeCommand({
    required this.uuid,
    required this.version,
  }) : type = 'handshake';

  Map<String, dynamic> toJson() {

    return {
      'type': type,
      'uuid': uuid,
      'version': version,
    };
  }
}