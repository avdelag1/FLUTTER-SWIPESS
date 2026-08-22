import 'package:flutter_swipes/src/features/needs/domain/marketplace_need.dart';

enum MarketplaceActionType { searchMarketplace, createNeed, draftListing, unknown }

class MarketplaceActionPlan {
  const MarketplaceActionPlan({
    required this.type,
    required this.summary,
    this.category,
    this.query,
    this.need,
    this.payload = const {},
  });

  final MarketplaceActionType type;
  final String summary;
  final String? category;
  final String? query;
  final MarketplaceNeedDraft? need;
  final Map<String, dynamic> payload;

  bool get requiresConfirmation =>
      type == MarketplaceActionType.createNeed ||
      type == MarketplaceActionType.draftListing;

  factory MarketplaceActionPlan.fromJson(Map<String, dynamic> json) {
    final rawAction = '${json['action'] ?? ''}'.trim().toLowerCase();
    final type = switch (rawAction) {
      'search_marketplace' => MarketplaceActionType.searchMarketplace,
      'create_need' => MarketplaceActionType.createNeed,
      'draft_listing' => MarketplaceActionType.draftListing,
      _ => MarketplaceActionType.unknown,
    };
    final category = _safeCategory(json['category']?.toString());
    final needJson = json['need'];
    final need = type == MarketplaceActionType.createNeed && category != null
        ? _needFromJson(
            category,
            needJson is Map
                ? Map<String, dynamic>.from(needJson)
                : Map<String, dynamic>.from(json),
          )
        : null;
    return MarketplaceActionPlan(
      type: type,
      summary: '${json['summary'] ?? 'I can help with that.'}'.trim(),
      category: category,
      query: json['query']?.toString().trim(),
      need: need,
      payload: Map<String, dynamic>.from(json),
    );
  }

  static MarketplaceNeedDraft _needFromJson(
    String category,
    Map<String, dynamic> json,
  ) {
    double? number(String key) => double.tryParse('${json[key] ?? ''}');
    int? integer(String key) => int.tryParse('${json[key] ?? ''}');
    DateTime? date(String key) => DateTime.tryParse('${json[key] ?? ''}');
    final urgency = switch ('${json['urgency'] ?? ''}'.toLowerCase()) {
      'now' => 'now',
      'today' => 'today',
      'this_week' => 'this_week',
      _ => 'flexible',
    };
    return MarketplaceNeedDraft(
      category: category,
      title: '${json['title'] ?? json['query'] ?? 'I need something'}'.trim(),
      description: '${json['description'] ?? ''}'.trim(),
      city: _emptyToNull(json['city']?.toString()),
      neighborhood: _emptyToNull(json['neighborhood']?.toString()),
      budgetMin: number('budget_min'),
      budgetMax: number('budget_max'),
      currency: '${json['currency'] ?? 'USD'}'.toUpperCase(),
      startsAt: date('starts_at'),
      endsAt: date('ends_at'),
      partySize: integer('party_size'),
      urgency: urgency,
      metadata: {'source': 'ai_plan'},
    );
  }

  static String? _safeCategory(String? raw) {
    final value = raw?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    const allowed = {
      'property',
      'yacht',
      'motorcycle',
      'bicycle',
      'worker',
      'service',
    };
    if (allowed.contains(value)) return value;
    return switch (value) {
      'properties' => 'property',
      'yachts' => 'yacht',
      'moto' || 'motos' || 'motorcycles' => 'motorcycle',
      'bike' || 'bikes' || 'bicycles' => 'bicycle',
      'workers' || 'professional' || 'professionals' => 'worker',
      'services' => 'service',
      _ => null,
    };
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
