import '../../data/models/ble_device_model.dart';

abstract class BluetoothState {}

class BluetoothInitial extends BluetoothState {}

class BluetoothLoading extends BluetoothState {}

class BluetoothLoaded extends BluetoothState {
  final List<BleDeviceModel> devices;

  BluetoothLoaded(this.devices);
}

class BluetoothConnecting extends BluetoothState {}

class BluetoothConnected extends BluetoothState {}

class BluetoothHandshakeSuccess extends BluetoothState {}

class BluetoothHandshakeFailed extends BluetoothState {}

class BluetoothError extends BluetoothState {
  final String message;

  BluetoothError(this.message);
}