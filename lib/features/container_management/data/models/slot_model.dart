class SlotModel {

  final int slotNumber;

  final String spiceName;

  final String expiryDate;

  final int level;

  /// NEW

  final int capacity;

  final String lastRefillDate;

  SlotModel({

    required this.slotNumber,

    required this.spiceName,

    required this.expiryDate,

    required this.level,

    required this.capacity,

    required this.lastRefillDate,
  });

  /// INITIAL

  factory SlotModel.initial(
      int slotNumber,
      ) {

    return SlotModel(

      slotNumber: slotNumber,

      spiceName: 'Empty',

      expiryDate: '',

      level: 100,

      capacity: 200,

      lastRefillDate: '',
    );
  }

  /// COPY WITH

  SlotModel copyWith({

    int? slotNumber,

    String? spiceName,

    String? expiryDate,

    int? level,

    int? capacity,

    String? lastRefillDate,
  }) {

    return SlotModel(

      slotNumber:
      slotNumber ??
          this.slotNumber,

      spiceName:
      spiceName ??
          this.spiceName,

      expiryDate:
      expiryDate ??
          this.expiryDate,

      level:
      level ??
          this.level,

      capacity:
      capacity ??
          this.capacity,

      lastRefillDate:
      lastRefillDate ??
          this.lastRefillDate,
    );
  }

  /// JSON

  Map<String, dynamic> toJson() {

    return {

      'slotNumber':
      slotNumber,

      'spiceName':
      spiceName,

      'expiryDate':
      expiryDate,

      'level':
      level,

      'capacity':
      capacity,

      'lastRefillDate':
      lastRefillDate,
    };
  }

  factory SlotModel.fromJson(
      Map<String, dynamic> json,
      ) {

    return SlotModel(

      slotNumber:
      json['slotNumber'] ?? 0,

      spiceName:
      json['spiceName'] ?? '',

      expiryDate:
      json['expiryDate'] ?? '',

      level:
      json['level'] ?? 100,

      /// لو الداتا القديمة موجودة
      capacity:
      json['capacity'] ?? 200,

      /// لو الداتا القديمة موجودة
      lastRefillDate:
      json['lastRefillDate'] ?? '',
    );
  }
}