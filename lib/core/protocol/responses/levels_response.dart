class LevelsResponse {
  final Map<int, int> data;

  LevelsResponse({
    required this.data,
  });

  factory LevelsResponse.fromJson(
      Map<String, dynamic> json,
      ) {
    Map<int, int> parsed = {};

    if (json['data'] != null) {
      final Map<String, dynamic> rawData =
      Map<String, dynamic>.from(
        json['data'],
      );

      rawData.forEach((key, value) {
        parsed[int.parse(key)] =
        value as int;
      });
    }

    return LevelsResponse(
      data: parsed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data.map(
            (key, value) => MapEntry(
          key.toString(),
          value,
        ),
      ),
    };
  }
}