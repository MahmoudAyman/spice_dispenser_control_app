class BleConstants {

  static const String deviceName =
      'spice dispenser';

  /// MAIN BLE SERVICE

  static const String serviceUuid =
      '4fafc201-1fb5-459e-8fcc-c5c9c331914b';

  /// COMMAND WRITE CHARACTERISTIC

  static const String
  writeCharacteristicUuid =
      'beb5483e-36e1-4688-b7f5-ea07361b26a8';

  /// STATUS + ACK CHARACTERISTIC

  static const String
  statusCharacteristicUuid =
      'd670f5e7-3f36-4c9c-b1cc-1365532587f1';

  /// SYNC + LEVELS CHARACTERISTIC

  static const String
  syncCharacteristicUuid =
      '672a952d-8889-4824-9118-2e0e09252c84';
}