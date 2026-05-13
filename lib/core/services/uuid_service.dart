import 'package:uuid/uuid.dart';

import '../storage/storage_service.dart';

class UuidService {

  static Future<String> getUuid()
  async {

    final savedUuid =
    StorageService.getUuid();

    if (savedUuid != null) {
      return savedUuid;
    }

    final uuid =
    const Uuid().v4();

    await StorageService.saveUuid(
      uuid,
    );

    return uuid;
  }
}