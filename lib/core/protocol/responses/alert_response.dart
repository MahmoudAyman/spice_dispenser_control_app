class AlertResponse {

  final String type;

  final String code;

  final int slot;

  AlertResponse({
    required this.type,
    required this.code,
    required this.slot,
  });

  factory AlertResponse.fromJson(
      Map<String, dynamic> json,
      ) {

    return AlertResponse(
      type: json['type'],
      code: json['code'],
      slot: json['slot'],
    );
  }
}