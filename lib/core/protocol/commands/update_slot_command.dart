class UpdateSlotCommand {

  final String type;

  final int slot;

  final String name;

  final String expiry;

  UpdateSlotCommand({
    required this.slot,
    required this.name,
    required this.expiry,
  }) : type = 'update_slot';

  Map<String, dynamic> toJson() {

    return {
      'type': type,
      'slot': slot,
      'name': name,
      'expiry': expiry,
    };
  }
}