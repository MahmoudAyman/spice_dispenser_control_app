import 'package:permission_handler/permission_handler.dart';

class PermissionService {

  Future<bool> requestBluetoothPermissions() async {

    final scanStatus =
    await Permission.bluetoothScan.request();

    final connectStatus =
    await Permission.bluetoothConnect.request();

    final locationStatus =
    await Permission.location.request();

    return scanStatus.isGranted &&
        connectStatus.isGranted &&
        locationStatus.isGranted;
  }
}