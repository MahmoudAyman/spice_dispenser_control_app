import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleDeviceModel {
  final String name;
  final String id;
  final int rssi;
  final BluetoothDevice device;

  BleDeviceModel({
    required this.name,
    required this.id,
    required this.rssi,
    required this.device,
  });
}