class LevelsResponse {

  final String type;

  final List<dynamic> data;

  LevelsResponse({
    required this.type,
    required this.data,
  });

  factory LevelsResponse.fromJson(
      Map<String, dynamic> json,
      ) {

    return LevelsResponse(
      type: json['type'],
      data: json['data'],
    );
  }
}