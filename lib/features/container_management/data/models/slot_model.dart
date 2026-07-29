class SlotModel {
  final int slotNumber;
  final String spiceName;

  /// Unix epoch timestamp in seconds. Null or 0 means not set.
  final int? expiryEpoch;

  final int level;

  SlotModel({
    required this.slotNumber,
    required this.spiceName,
    this.expiryEpoch,
    required this.level,
  });

  /// Whether the spice has expired (epoch is set and in the past).
  bool get isExpired {
    if (expiryEpoch == null || expiryEpoch == 0) return false;
    final expiry = DateTime.fromMillisecondsSinceEpoch(expiryEpoch! * 1000);
    return DateTime.now().isAfter(expiry);
  }

  /// Whether the spice expires within the next 30 days.
  bool get isExpiringSoon {
    if (expiryEpoch == null || expiryEpoch == 0) return false;
    if (isExpired) return false;
    final expiry = DateTime.fromMillisecondsSinceEpoch(expiryEpoch! * 1000);
    return expiry.isBefore(DateTime.now().add(const Duration(days: 30)));
  }

  /// Human-readable expiry string for display.
  String get expiryDisplayString {
    if (expiryEpoch == null || expiryEpoch == 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(expiryEpoch! * 1000);
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Map<String, dynamic> toJson() {
    return {
      'slotNumber': slotNumber,
      'spiceName': spiceName,
      'expiryDate': expiryDisplayString, // kept for legacy storage compat
      'expiryEpoch': expiryEpoch ?? 0,
      'level': level,
    };
  }

  factory SlotModel.fromJson(Map<String, dynamic> json) {
    // Support legacy storage that stored a human-readable string in expiryDate
    // but no expiryEpoch. In that case epoch is 0/null.
    final epochVal = json['expiryEpoch'];
    int? epoch;
    if (epochVal != null) {
      epoch = epochVal is int ? epochVal : int.tryParse(epochVal.toString());
    }
    if (epoch == 0) epoch = null;

    return SlotModel(
      slotNumber: json['slotNumber'] ?? 0,
      spiceName: json['spiceName'] ?? '',
      expiryEpoch: epoch,
      level: json['level'] ?? 0,
    );
  }

  SlotModel copyWith({
    int? slotNumber,
    String? spiceName,
    int? expiryEpoch,
    int? level,
  }) {
    return SlotModel(
      slotNumber: slotNumber ?? this.slotNumber,
      spiceName: spiceName ?? this.spiceName,
      expiryEpoch: expiryEpoch ?? this.expiryEpoch,
      level: level ?? this.level,
    );
  }
}