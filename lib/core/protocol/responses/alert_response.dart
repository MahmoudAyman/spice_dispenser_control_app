class AlertResponse {
  final String code;
  final int slot;
  final bool blocking;

  AlertResponse({
    required this.code,
    required this.slot,
    this.blocking = false,
  });

  factory AlertResponse.fromJson(Map<String, dynamic> json) {
    return AlertResponse(
      code: json['code'] ?? '',
      slot: json['slot'] ?? 0,
      blocking: json['blocking'] ?? false,
    );
  }
}
