class SpiceDefinition {
  final String name;
  final double density;

  SpiceDefinition({
    required this.name,
    required this.density,
  });

  factory SpiceDefinition.fromJson(Map<String, dynamic> json) {
    return SpiceDefinition(
      name: (json['n'] ?? json['name'] ?? '') as String,
      density: ((json['d'] ?? json['density'] ?? 0.0) as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'n': name,
      'd': density,
    };
  }
}
