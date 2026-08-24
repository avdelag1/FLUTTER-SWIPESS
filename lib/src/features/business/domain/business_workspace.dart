class BusinessWorkspace {
  BusinessWorkspace({required this.raw});

  factory BusinessWorkspace.fromJson(Map<String, dynamic> json) {
    return BusinessWorkspace(raw: Map<String, dynamic>.from(json));
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> get business => _map(raw['business']);
  Map<String, dynamic> get summary => _map(raw['summary']);

  String get name => _string(business['business_name']) ?? 'SWIPESS Partner';
  String? get type => _string(business['business_type']);
  String? get address => _string(business['address']);
  String? get logoUrl => _string(business['logo_url']);
  double get commissionRate => _number(business['commission_rate']);

  int get scansToday => _integer(summary['scans_today']);
  int get scans30d => _integer(summary['scans_30d']);
  int get scansTotal => _integer(summary['scans_total']);
  int get customersTotal => _integer(summary['customers_total']);
  int get transactions30d => _integer(summary['transactions_30d']);
  int get activePromos => _integer(summary['active_promos']);
  double get grossSales30d => _number(summary['gross_sales_30d']);
  double get discounts30d => _number(summary['discounts_30d']);
  double get commission30d => _number(summary['commission_30d']);

  List<Map<String, dynamic>> get recentScans => _list(raw['recent_scans']);
  List<Map<String, dynamic>> get recentTransactions =>
      _list(raw['recent_transactions']);
  List<Map<String, dynamic>> get customerPromos => _list(raw['customer_promos']);
  List<Map<String, dynamic>> get commissionSubmissions =>
      _list(raw['commission_submissions']);

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const {};
  }

  static List<Map<String, dynamic>> _list(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map) _map(item),
    ];
  }

  static int _integer(Object? value) => (value as num?)?.toInt() ?? 0;
  static double _number(Object? value) => (value as num?)?.toDouble() ?? 0;

  static String? _string(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
