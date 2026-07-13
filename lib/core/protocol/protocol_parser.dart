import 'responses/ack_response.dart';

import 'responses/alert_response.dart';

import 'responses/levels_response.dart';

import 'responses/status_response.dart';

import 'responses/manifest_response.dart';

import 'responses/setup_ready_for_slot_response.dart';

class ProtocolParser {

  static dynamic parse(
      Map<String, dynamic> json,
      ) {

    final type =
    json['type'];

    switch (type) {

      case 'setup_ready_for_slot':

        return SetupReadyForSlotResponse.fromJson(
          json,
        );

      case 'ack':

        return AckResponse.fromJson(
          json,
        );

      case 'status':

        return StatusResponse.fromJson(
          json,
        );

      case 'levels':

        return LevelsResponse.fromJson(
          json,
        );

      case 'alert':

        return AlertResponse.fromJson(
          json,
        );

      case 'manifest_start':
      case 'manifest_item':
      case 'manifest_end':

        return ManifestResponse.fromJson(
          json,
        );

      default:

        return null;
    }
  }
}