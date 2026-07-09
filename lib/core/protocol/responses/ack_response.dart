class AckResponse {

  final String command;

  final String status;

  AckResponse({
    required this.command,
    required this.status,
  });

  bool get isSuccess {

    return status.toLowerCase() == 'success';
  }

  factory AckResponse.fromJson(
      Map<String, dynamic> json,
      ) {

    return AckResponse(
      command:
      json['command'] ?? '',

      status:
      json['status'] ?? 'failed',
    );
  }
}