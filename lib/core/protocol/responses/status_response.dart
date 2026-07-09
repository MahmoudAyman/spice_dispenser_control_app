class StatusResponse {
  final String state;
  final String? activeRecipe;
  final int progress;
  final String? statusMsg;
  final String? detail;

  StatusResponse({
    required this.state,
    required this.progress,
    this.activeRecipe,
    this.statusMsg,
    this.detail,
  });

  factory StatusResponse.fromJson(Map<String, dynamic> json) {
    return StatusResponse(
      state: json['state'] ?? 'idle',
      progress: json['progress'] ?? 0,
      activeRecipe: json['active_recipe']?.toString(),
      statusMsg: json['status_msg']?.toString(),
      detail: json['detail']?.toString(),
    );
  }
}
