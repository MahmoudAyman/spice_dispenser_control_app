class StatusResponse {

  final String state;

  final int? activeRecipe;

  final int progress;

  StatusResponse({
    required this.state,
    required this.progress,
    this.activeRecipe,
  });

  factory StatusResponse.fromJson(
      Map<String, dynamic> json,
      ) {

    return StatusResponse(
      state:
      json['state'] ?? 'idle',

      progress:
      json['progress'] ?? 0,

      activeRecipe:
      json['active_recipe'],
    );
  }
}