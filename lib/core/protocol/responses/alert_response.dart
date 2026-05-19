class AlertResponse {

  final String code;

  final int slot;

  AlertResponse({
    required this.code,
    required this.slot,
  });

  factory AlertResponse.fromJson(
      Map<String, dynamic> json,
      ) {

    return AlertResponse(
      code:
      json['code'] ?? '',

      slot:
      json['slot'] ?? 0,
    );
  }
}