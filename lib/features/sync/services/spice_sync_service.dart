import 'dart:async';

import '../../../../core/protocol/commands/add_spice_definition_command.dart';
import '../../../../core/protocol/commands/get_spice_definitions_command.dart';
import '../../../../core/protocol/protocol_constants.dart';
import '../../../../core/protocol/responses/ack_response.dart';
import '../../../../core/services/ble_service.dart';
import '../../container_management/data/models/spice_definition_model.dart';

class SpiceSyncService {
  final BleService bleService;

  SpiceSyncService({required this.bleService});

  Future<List<SpiceDefinition>> fetchSpiceDefinitions() async {
    final completer = Completer<List<SpiceDefinition>>();
    final definitions = <SpiceDefinition>[];
    int? totalSpices;
    late StreamSubscription sub;

    sub = bleService.protocol.spiceDefinitionController.stream.listen((response) {
      if (completer.isCompleted) {
        sub.cancel();
        return;
      }

      if (response.type == ProtocolConstants.spiceDefinitionsStart) {
        totalSpices = response.total;
        if (totalSpices == 0) {
          completer.complete(definitions);
          sub.cancel();
        }
      } else if (response.type == ProtocolConstants.spiceDefinitionItem) {
        if (response.item != null) {
          definitions.add(response.item!);
        }
        if (totalSpices != null && definitions.length >= totalSpices!) {
          completer.complete(definitions);
          sub.cancel();
        }
      } else if (response.type == ProtocolConstants.spiceDefinitionsEnd) {
        if (!completer.isCompleted) {
          completer.complete(definitions);
        }
        sub.cancel();
      }
    });

    await bleService.writeCommand(
      command: GetSpiceDefinitionsCommand().toJson(),
    );

    // Let the timeout throw a TimeoutException, which is a proper way to handle it.
    // The cubit will catch it and can show a proper error.
    return completer.future.timeout(const Duration(seconds: 30));
  }

  Future<AckResponse> addNewSpiceDefinition(SpiceDefinition definition) {
    final command = AddSpiceDefinitionCommand(definition: definition);
    return bleService.sendCommand(command: command.toJson());
  }
}
