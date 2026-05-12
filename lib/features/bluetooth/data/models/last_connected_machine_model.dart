class LastConnectedMachineModel {

  final String deviceId;
  final String deviceName;

  LastConnectedMachineModel({
    required this.deviceId,
    required this.deviceName,
  });

  Map<String, dynamic> toMap() {

    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
    };
  }

  factory LastConnectedMachineModel
      .fromMap(
      Map<dynamic, dynamic> map,
      ) {

    return LastConnectedMachineModel(
      deviceId: map['deviceId'],
      deviceName: map['deviceName'],
    );
  }
}