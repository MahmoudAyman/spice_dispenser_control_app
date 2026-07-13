class AckResponse {
  final String command;
  final String status;
  final bool? newDevice;
  final String? reason;
  final String? detail;
  final int? slot;
  final String? name;
  final double? maxFill;

  AckResponse({
    required this.command,
    required this.status,
    this.newDevice,
    this.reason,
    this.detail,
    this.slot,
    this.name,
    this.maxFill,
  });

  bool get isSuccess {
    final s = status.toLowerCase();
    return s == 'success' || s == 'ready' || s == 'unconfigured';
  }

  factory AckResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return AckResponse(
      command: json['command'] ?? '',
      status: json['status'] ?? 'failed',
      newDevice: json['new_device'],
      reason: json['reason'],
      detail: json['detail'],
      slot: json['slot'],
      name: json['name'],
      maxFill: json['max_fill'] != null ? (json['max_fill'] as num).toDouble() : null,
    );
  }
}
