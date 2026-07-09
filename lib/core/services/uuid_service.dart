import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class UuidService {

  static const String key = 'app_uuid';

  static Future<String> getUuid() async {

    final prefs =
    await SharedPreferences.getInstance();

    String? uuid = prefs.getString(key);

    if (uuid != null) {
      return uuid;
    }

    uuid = const Uuid().v4();

    await prefs.setString(key, uuid);

    return uuid;
  }
}