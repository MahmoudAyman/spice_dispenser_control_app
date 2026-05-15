class RefillCommand {

  final String type;

  final int slot;

  RefillCommand({
    required this.slot,
  }) : type = 'refill';

  Map<String, dynamic> toJson() {

    return {
      'type': type,
      'slot': slot,
    };
  }
}