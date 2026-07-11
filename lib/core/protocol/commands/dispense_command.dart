import '../../../features/dispensing/data/models/dispense_item_model.dart';

class DispenseCommand {

  final List<DispenseItemModel> items;

  DispenseCommand({
    required this.items,
  });

  Map<String, dynamic> toJson() {

    return {

      'type': 'dispense',

      'items': items
          .map(
            (e) => e.toJson(),
      )
          .toList(),
    };
  }
}