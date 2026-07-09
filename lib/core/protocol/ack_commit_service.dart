import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class AckCommitService {

  Future<bool> sendWithAck({
    required BluetoothCharacteristic
    characteristic,

    required List<List<int>> chunks,
  }) async {

    try {

      for (var chunk in chunks) {

        await characteristic.write(
          chunk,
          withoutResponse: false,
        );
      }

      /// wait for ack later

      await Future.delayed(
        const Duration(seconds: 1),
      );

      return true;

    } catch (e) {

      return false;
    }
  }
}