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

      for (var item in json['data']) {

        parsed[item['slot']] =
        item['level'];
      }
    }

    return LevelsResponse(
      data: parsed,
    );
  }
}