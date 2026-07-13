class SetupReadyForSlotResponse {
  final int slot;
  final int rVal;
  final int gVal;
  final int bVal;

  SetupReadyForSlotResponse({
    required this.slot,
    required this.rVal,
    required this.gVal,
    required this.bVal,
  });

  factory SetupReadyForSlotResponse.fromJson(Map<String, dynamic> json) {
    return SetupReadyForSlotResponse(
      slot: json['slot'] ?? 0,
      rVal: json['r_val'] ?? 0,
      gVal: json['g_val'] ?? 0,
      bVal: json['b_val'] ?? 0,
    );
  }
}
