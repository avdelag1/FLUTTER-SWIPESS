class AppMarketContext {
  AppMarketContext({required this.raw});

  factory AppMarketContext.fromJson(Map<String, dynamic> json) {
    return AppMarketContext(raw: Map<String, dynamic>.from(json));
  }

  final Map<String, dynamic> raw;

  bool get configured => raw['configured'] == true;
  bool get effectiveOpen => raw['effective_open'] != false;
  String? get city => _string(raw['city']);
  String? get country => _string(raw['country_name']);
  String? get slug => _string(raw['slug']);
  String? get currency => _string(raw['currency']);

  Map<String, dynamic> get features => _map(raw['features']);

  bool featureEnabled(String key) => features[key] != false;

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const {};
  }

  static String? _string(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
