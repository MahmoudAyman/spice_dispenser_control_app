class ProtocolConstants {

  /// COMMAND TYPES
  static const String handshake =
      'handshake';

  static const String dispense =
      'dispense';

  static const String updateSlot =
      'update_slot';

  static const String refill =
      'refill';

  static const String abort =
      'abort';

  static const String sync =
      'sync';

  /// RESPONSE TYPES
  static const String ack =
      'ack';

  static const String status =
      'status';

  static const String levels =
      'levels';

  static const String alert =
      'alert';

  /// ACK STATUS
  static const String success =
      'success';

  static const String fail =
      'fail';

  /// BLE
  static const int timeoutSeconds =
  3;

  static const int mtuSize =
  20;
}