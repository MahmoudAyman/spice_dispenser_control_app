class DispenseItemModel {

  final int slot;

  final double grams;

  final String spiceName;

  DispenseItemModel({
    required this.slot,
    required this.grams,
    required this.spiceName,
  });

  Map<String, dynamic> toJson() {

    return {
      'slot': slot,
      'grams': grams,
    };
  }
}