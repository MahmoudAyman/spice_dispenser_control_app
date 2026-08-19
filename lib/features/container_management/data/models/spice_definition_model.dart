class SpiceDefinition {
  final String name;
  final double density;

  SpiceDefinition({
    required this.name,
    required this.density,
  });

  factory SpiceDefinition.fromJson(Map<String, dynamic> json) {
    return SpiceDefinition(
      name: json['n'] as String,
      density: (json['d'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'density': density,
    };
  }
}
