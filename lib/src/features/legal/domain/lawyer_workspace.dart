class LawyerWorkspace {
  LawyerWorkspace({required this.raw});

  factory LawyerWorkspace.fromJson(Map<String, dynamic> json) {
    return LawyerWorkspace(raw: Map<String, dynamic>.from(json));
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> get lawyer => _map(raw['lawyer']);
  Map<String, dynamic> get summary => _map(raw['summary']);

  String get name => _string(lawyer['full_name']) ?? 'SWIPESS Lawyer';
  String? get barNumber => _string(lawyer['bar_number']);
  String? get specialization => _string(lawyer['specialization']);
  bool get isAvailable => lawyer['is_available'] == true;
  double get commissionRate => _number(lawyer['commission_rate']);

  int get pendingRequests => _integer(summary['pending_requests']);
  int get activeClients => _integer(summary['active_clients']);
  int get openCases => _integer(summary['open_cases']);
  int get upcomingAppointments => _integer(summary['upcoming_appointments']);
  int get templatesAvailable => _integer(summary['templates_available']);
  int get servicePackagesAvailable => _integer(summary['service_packages_available']);
  double get grossEarned30d => _number(summary['gross_earned_30d']);
  double get commission30d => _number(summary['commission_30d']);

  List<Map<String, dynamic>> get requests => _list(raw['requests']);
  List<Map<String, dynamic>> get cases => _list(raw['cases']);
  List<Map<String, dynamic>> get appointments => _list(raw['appointments']);
  List<Map<String, dynamic>> get recentTransactions => _list(raw['recent_transactions']);

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

  static int _integer(Object? value) => (value as num?)?.toInt() ?? 0;
  static double _number(Object? value) => (value as num?)?.toDouble() ?? 0;

  static String? _string(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
