class MarketplaceNeed {
  const MarketplaceNeed({
    required this.id,
    required this.userId,
    required this.category,
    required this.title,
    required this.status,
    required this.urgency,
    required this.currency,
    required this.createdAt,
    required this.expiresAt,
    this.description = '',
    this.city,
    this.neighborhood,
    this.latitude,
    this.longitude,
    this.budgetMin,
    this.budgetMax,
    this.startsAt,
    this.endsAt,
    this.partySize,
    this.metadata = const {},
  });

  final String id;
  final String userId;
  final String category;
  final String title;
  final String description;
  final String status;
  final String urgency;
  final String currency;
  final String? city;
  final String? neighborhood;
  final double? latitude;
  final double? longitude;
  final double? budgetMin;
  final double? budgetMax;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int? partySize;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// Reads the existing canonical Seeker/request row in `listings`.
  factory MarketplaceNeed.fromJson(Map data) {
    final context = data['request_context'] is Map
        ? Map<String, dynamic>.from(data['request_context'] as Map)
        : const <String, dynamic>{};
    double? number(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse('${value ?? ''}');
    int? integer(dynamic value) => value is num
        ? value.toInt()
        : int.tryParse('${value ?? ''}');
    final created = _date(data['created_at']) ?? DateTime.now();
    final active = data['is_active'] != false;
    final rawStatus = '${data['status'] ?? ''}'.trim().toLowerCase();
    final urgency = '${context['urgency'] ?? (active ? rawStatus : 'flexible')}'.trim();
    return MarketplaceNeed(
      id: '${data['id'] ?? ''}',
      userId: '${data['owner_id'] ?? data['user_id'] ?? ''}',
      category: '${data['category'] ?? 'service'}',
      title: '${data['title'] ?? ''}',
      description: '${data['description'] ?? ''}',
      status: active ? 'open' : (rawStatus.isEmpty ? 'closed' : rawStatus),
      urgency: const {'now', 'today', 'this_week', 'flexible'}.contains(urgency)
          ? urgency
          : 'flexible',
      currency: '${context['currency'] ?? 'USD'}',
      city: data['city']?.toString(),
      neighborhood: context['neighborhood']?.toString(),
      latitude: number(data['latitude']),
      longitude: number(data['longitude']),
      budgetMin: number(context['budget_min']),
      budgetMax: number(context['budget_max'] ?? data['price']),
      startsAt: _date(context['starts_at']),
      endsAt: _date(context['ends_at']),
      partySize: integer(context['party_size']),
      metadata: context['metadata'] is Map
          ? Map<String, dynamic>.from(context['metadata'] as Map)
          : const {},
      createdAt: created,
      expiresAt: _date(context['expires_at']) ?? created.add(const Duration(days: 30)),
    );
  }

  bool get isOpen => status == 'open' && expiresAt.isAfter(DateTime.now());

  String get budgetLabel {
    if (budgetMin == null && budgetMax == null) return 'Any budget';
    if (budgetMin != null && budgetMax != null) {
      return '$currency ${_money(budgetMin!)}–${_money(budgetMax!)}';
    }
    if (budgetMax != null) return 'Up to $currency ${_money(budgetMax!)}';
    return 'From $currency ${_money(budgetMin!)}';
  }

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());

  static String _money(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}

class MarketplaceNeedDraft {
  const MarketplaceNeedDraft({
    required this.category,
    required this.title,
    this.description = '',
    this.city,
    this.neighborhood,
    this.latitude,
    this.longitude,
    this.budgetMin,
    this.budgetMax,
    this.currency = 'USD',
    this.startsAt,
    this.endsAt,
    this.partySize,
    this.urgency = 'flexible',
    this.metadata = const {},
  });

  final String category;
  final String title;
  final String description;
  final String? city;
  final String? neighborhood;
  final double? latitude;
  final double? longitude;
  final double? budgetMin;
  final double? budgetMax;
  final String currency;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int? partySize;
  final String urgency;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toRpcParams() => {
        'p_category': category,
        'p_title': title,
        'p_description': description,
        'p_city': city,
        'p_neighborhood': neighborhood,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_budget_min': budgetMin,
        'p_budget_max': budgetMax,
        'p_currency': currency,
        'p_starts_at': startsAt?.toUtc().toIso8601String(),
        'p_ends_at': endsAt?.toUtc().toIso8601String(),
        'p_party_size': partySize,
        'p_urgency': urgency,
        'p_metadata': metadata,
      };
}
