import '../../../features/container_management/data/models/spice_definition_model.dart';
import '../protocol_constants.dart';

class AddSpiceDefinitionCommand {
  final SpiceDefinition definition;

  AddSpiceDefinitionCommand({required this.definition});

  Map<String, dynamic> toJson() {
    return {
      'type': ProtocolConstants.addSpiceDefinition,
      'payload': {
        'name': definition.name,
        'density': definition.density,
      },
    };
  }
}
