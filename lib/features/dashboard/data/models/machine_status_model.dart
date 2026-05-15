class MachineStatusModel {

  final bool initialized;

  final bool connected;

  final bool dispensing;

  final int battery;

  MachineStatusModel({
    required this.initialized,
    required this.connected,
    required this.dispensing,
    required this.battery,
  });

  Map<String, dynamic> toJson() {

    return {
      'initialized': initialized,
      'connected': connected,
      'dispensing': dispensing,
      'battery': battery,
    };
  }

  factory MachineStatusModel.fromJson(
      Map<String, dynamic> json,
      ) {

    return MachineStatusModel(
      initialized: json['initialized'],
      connected: json['connected'],
      dispensing: json['dispensing'],
      battery: json['battery'],
    );
  }
}