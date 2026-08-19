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

  static const String getSpiceDefinitions = 'get_spice_definitions';
  static const String addSpiceDefinition = 'add_spice_definition';

  /// RESPONSE TYPES
  static const String ack =
      'ack';

  static const String status =
      'status';

  static const String levels =
      'levels';

  static const String alert =
      'alert';

  static const String spiceDefinitionsStart = 'spice_definitions_start';
  static const String spiceDefinitionItem = 'spice_definition_item';
  static const String spiceDefinitionsEnd = 'spice_definitions_end';

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