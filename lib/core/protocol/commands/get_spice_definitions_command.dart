import '../../../../core/protocol/protocol_constants.dart';

class GetSpiceDefinitionsCommand {
  Map<String, dynamic> toJson() {
    return {
      'type': ProtocolConstants.getSpiceDefinitions,
    };
  }
}
