class SlotModel {

  final int slotNumber;

  final String spiceName;

  final String expiryDate;

  final int level;

  SlotModel({
    required this.slotNumber,
    required this.spiceName,
    required this.expiryDate,
    required this.level,
  });

  Map<String, dynamic> toJson() {

    return {
      'slotNumber': slotNumber,
      'spiceName': spiceName,
      'expiryDate': expiryDate,
      'level': level,
    };
  }

  factory SlotModel.fromJson(
      Map<String, dynamic> json,
      ) {

    return SlotModel(
      slotNumber: json['slotNumber'],
      spiceName: json['spiceName'],
      expiryDate: json['expiryDate'],
      level: json['level'],
    );
  }
}