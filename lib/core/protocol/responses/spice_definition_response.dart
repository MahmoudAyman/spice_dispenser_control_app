import '../../../features/container_management/data/models/spice_definition_model.dart';
import '../protocol_constants.dart';

class SpiceDefinitionResponse {
  final String type;
  final int? total;
  final SpiceDefinition? item;

  SpiceDefinitionResponse({
    required this.type,
    this.total,
    this.item,
  });

  factory SpiceDefinitionResponse.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    int? total;
    SpiceDefinition? item;

    switch (type) {
      case ProtocolConstants.spiceDefinitionsStart:
        total = json['total'] as int;
        break;
      case ProtocolConstants.spiceDefinitionItem:
        item = SpiceDefinition.fromJson(json);
        break;
      case ProtocolConstants.spiceDefinitionsEnd:
        break;
      default:
        throw ArgumentError('Invalid spice definition response type: $type');
    }

    return SpiceDefinitionResponse(
      type: type,
      total: total,
      item: item,
    );
  }
}
