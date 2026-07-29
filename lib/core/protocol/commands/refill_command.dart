class RefillCommand {
  final String type;
  final int slot;

  /// Fill level as a percentage (25, 50, 75, or 100).
  final int level;

  /// Optional updated expiry Unix epoch timestamp.
  final int? expiry;

  RefillCommand({
    required this.slot,
    required this.level,
    this.expiry,
  }) : type = 'refill';

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'type': type,
      'slot': slot,
      'level': level,
    };
    if (expiry != null && expiry! > 0) {
      map['expiry'] = expiry;
    }
    return map;
  }
}