import '../../data/models/ble_device_model.dart';

abstract class BluetoothState {}

class BluetoothInitial extends BluetoothState {}

class BluetoothLoading extends BluetoothState {}

class BluetoothLoaded extends BluetoothState {
  final List<BleDeviceModel> devices;

  BluetoothLoaded(this.devices);
}

class BluetoothConnecting extends BluetoothState {
  final String message;

  BluetoothConnecting({this.message = 'Connecting...'});
}

class BluetoothConnected extends BluetoothState {}

class BluetoothHandshakeSuccess extends BluetoothState {
  final bool isConfigured;

  BluetoothHandshakeSuccess({required this.isConfigured});
}

class BluetoothHandshakeFailed extends BluetoothState {}

class BluetoothAutoConnecting extends BluetoothState {
  final String message;

  BluetoothAutoConnecting({this.message = 'Scanning for favorite...'});
}

class BluetoothError extends BluetoothState {
  final String message;

  BluetoothError(this.message);
}
