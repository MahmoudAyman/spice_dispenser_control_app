class AckResponse {

  final bool success;

  final String message;

  AckResponse({
    required this.success,
    required this.message,
  });

  bool get isSuccess =>
      success;

  factory AckResponse.fromJson(
      Map<String, dynamic> json,
      ) {

    return AckResponse(
      success:
      json['success'],

      message:
      json['message'],
    );
  }
}