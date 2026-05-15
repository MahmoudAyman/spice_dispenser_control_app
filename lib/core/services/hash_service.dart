import 'dart:convert';

class HashService {

  static String generateHash(
      dynamic data,
      ) {

    return base64Encode(
      utf8.encode(
        jsonEncode(data),
      ),
    );
  }
}