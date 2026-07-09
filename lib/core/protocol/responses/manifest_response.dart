class ManifestResponse {
  final String type; // 'manifest_start', 'manifest_item', 'manifest_end'
  final int? total;
  final int? slot;
  final String? name;
  final int? level;
  final int? expiry;

  ManifestResponse({
    required this.type,
    this.total,
    this.slot,
    this.name,
    this.level,
    this.expiry,
  });

  factory ManifestResponse.fromJson(Map<String, dynamic> json) {
    return ManifestResponse(
      type: json['type'] ?? '',
      total: json['total'],
      slot: json['s'] ?? json['slot'],
      name: json['n'] ?? json['name'],
      level: json['l'] ?? json['level'],
      expiry: json['e'] ?? json['expiry'],
    );
  }
}
