class BusinessVisit {
  BusinessVisit({required this.raw});

  factory BusinessVisit.fromJson(Map<String, dynamic> json) {
    return BusinessVisit(raw: Map<String, dynamic>.from(json));
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> get member => _map(raw['member']);
  Map<String, dynamic> get subscription => _map(raw['subscription']);
  Map<String, dynamic> get stats => _map(raw['stats']);

  String get scanId => raw['scan_id']?.toString() ?? '';
  String get userId => member['user_id']?.toString() ?? '';
  String get name => _string(member['name']) ?? 'SWIPESS member';
  String? get avatarUrl => _string(member['avatar_url']);
  String? get city => _string(member['city']);
  String? get country => _string(member['country']);
  String? get nationality => _string(member['nationality']);
  String? get occupation => _string(member['occupation']);
  int? get yearsInCity => (member['years_in_city'] as num?)?.toInt();
  bool get verified => member['verified'] == true;

  bool get premiumActive => subscription['active'] == true;
  String? get premiumName => _string(subscription['name']);
  String? get premiumTier => _string(subscription['tier']);

  int get visitsTotal => (stats['visits_total'] as num?)?.toInt() ?? 0;
  int get directRequestsRemaining =>
      (stats['direct_requests_remaining'] as num?)?.toInt() ?? 0;
  double get grossSpendTotal =>
      (stats['gross_spend_total'] as num?)?.toDouble() ?? 0;
  double get discountSavedTotal =>
      (stats['discount_saved_total'] as num?)?.toDouble() ?? 0;
  double get commissionRate =>
      (raw['commission_rate'] as num?)?.toDouble() ?? 0;

  List<double> get discountTiers {
    final rawTiers = raw['discount_tiers'];
    if (rawTiers is! List) return const [0];
    final tiers = <double>[0];
    for (final item in rawTiers) {
      final value = (item as num?)?.toDouble();
      if (value != null && value >= 0 && value <= 100 && !tiers.contains(value)) {
        tiers.add(value);
      }
    }
    tiers.sort();
    return tiers;
  }

  List<Map<String, dynamic>> get recentTransactions =>
      _list(raw['recent_transactions']);

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const {};
  }

  static List<Map<String, dynamic>> _list(Object? value) {
    if (value is! List) return const [];
    return [for (final item in value) if (item is Map) _map(item)];
  }

  static String? _string(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class BusinessTransactionResult {
  BusinessTransactionResult({required this.raw});

  factory BusinessTransactionResult.fromJson(Map<String, dynamic> json) {
    return BusinessTransactionResult(raw: Map<String, dynamic>.from(json));
  }

  final Map<String, dynamic> raw;

  double get grossAmount => (raw['gross_amount'] as num?)?.toDouble() ?? 0;
  double get discountPercentage =>
      (raw['discount_percentage'] as num?)?.toDouble() ?? 0;
  double get discountAmount =>
      (raw['discount_amount'] as num?)?.toDouble() ?? 0;
  double get customerPays => (raw['customer_pays'] as num?)?.toDouble() ?? 0;
  double get commissionAmount =>
      (raw['commission_amount'] as num?)?.toDouble() ?? 0;
}
