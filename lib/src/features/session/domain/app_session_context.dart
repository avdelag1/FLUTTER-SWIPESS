class AppSessionContext {
  AppSessionContext({required this.raw});

  factory AppSessionContext.fromJson(Map<String, dynamic> json) {
    return AppSessionContext(raw: Map<String, dynamic>.from(json));
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> get profile => _map(raw['profile']);
  Map<String, dynamic> get roles => _map(raw['roles']);
  Map<String, dynamic> get territory => _map(raw['territory']);
  Map<String, dynamic> get platform => _map(raw['platform']);
  Map<String, dynamic> get features => _map(territory['features']);

  Map<String, dynamic> role(String key) => _map(roles[key]);

  bool get accountActive =>
      profile['is_active'] != false &&
      profile['is_banned'] != true &&
      profile['is_suspended'] != true &&
      profile['is_blocked'] != true;

  bool get territoryConfigured => territory['configured'] == true;
  bool get territoryOpen => territory['effective_open'] != false;
  String? get territoryCity => _string(territory['city']);
  String? get territoryCountry => _string(territory['country_name']);
  String? get territorySlug => _string(territory['slug']);

  bool featureEnabled(String key) {
    // The backend deliberately defaults unknown/unconfigured markets to ON so
    // a temporary config outage never removes existing app functionality.
    return features[key] != false;
  }

  bool get adminActive => role('admin')['active'] == true;
  String? get adminRole => _string(role('admin')['role']);
  bool get canUseAdminPortal =>
      adminActive && (adminRole == 'admin' || adminRole == 'super_admin');
  bool get canUseLegalAdmin =>
      adminActive &&
      (adminRole == 'admin' ||
          adminRole == 'super_admin' ||
          adminRole == 'legal');

  bool get businessActive => role('business')['active'] == true;
  String? get businessName => _string(role('business')['business_name']);
  String? get businessId => _string(role('business')['business_id']);

  bool get lawyerActive => role('lawyer')['active'] == true;
  String? get lawyerName => _string(role('lawyer')['full_name']);
  String? get lawyerId => _string(role('lawyer')['lawyer_id']);

  bool get territoryStaffActive => role('territory')['active'] == true;
  String? get territoryStaffRole => _string(role('territory')['role']);

  bool get maintenanceMode => platform['maintenanceMode'] == true;
  bool get registrationEnabled => platform['userRegistration'] != false;

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const <String, dynamic>{};
  }

  static String? _string(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
