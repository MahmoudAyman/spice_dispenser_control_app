class UpdateSlotCommand {
  final String type;
  final int slot;
  final String name;

  /// Optional Unix epoch expiry timestamp. Omitted from JSON if null/0.
  final int? expiry;

  UpdateSlotCommand({
    required this.slot,
    required this.name,
    this.expiry,
  }) : type = 'update_slot';

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'type': type,
      'slot': slot,
      'name': name,
    };
    if (expiry != null && expiry! > 0) {
      map['expiry'] = expiry;
    }
    return map;
  }
}