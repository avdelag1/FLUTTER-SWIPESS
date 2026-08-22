import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/needs/domain/marketplace_action_plan.dart';

class MarketplaceActionPlanner {
  MarketplaceActionPlanner(this._ai);

  final AiEdgeRepository _ai;

  Future<MarketplaceActionPlan> plan({
    required String prompt,
    String? city,
    double? latitude,
    double? longitude,
  }) async {
    final reply = await _ai.chatConcierge(
      messages: [
        const AiChatMessage(
          role: 'system',
          content: '''You are the Swipess marketplace action planner.
Return ONLY one valid JSON object, no markdown.
Allowed actions: search_marketplace, create_need, draft_listing.
Allowed categories: property, yacht, motorcycle, bicycle, worker, service.
Never send messages, spend tokens, accept matches, make payments, or create a paid Direct Request.
Mutating actions are only plans; the app will ask the user to confirm.
Use this schema:
{"action":"create_need","summary":"short human summary","category":"motorcycle","query":"optional search text","need":{"title":"...","description":"...","city":"...","budget_min":null,"budget_max":500,"currency":"USD","starts_at":null,"ends_at":null,"party_size":null,"urgency":"today"}}
Use urgency only: now, today, this_week, flexible. Use ISO-8601 dates only when the user actually supplied enough date/time information.''',
        ),
        AiChatMessage(
          role: 'user',
          content: [
            prompt.trim(),
            if (city != null && city.trim().isNotEmpty) 'Current city: ${city.trim()}',
            if (latitude != null && longitude != null)
              'Current discovery coordinates: $latitude,$longitude',
          ].join('\n'),
        ),
      ],
      character: 'marketplace_action_planner',
      preferredIntent: 'marketplace',
      stream: false,
    );
    final json = _jsonObject(reply);
    return MarketplaceActionPlan.fromJson(json);
  }

  static Map<String, dynamic> _jsonObject(String text) {
    final trimmed = text.trim();
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(trimmed);
    if (match != null) {
      try {
        final decoded = jsonDecode(match.group(0)!);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {
      'action': 'unknown',
      'summary': text.trim().isEmpty
          ? 'I could not turn that into a marketplace action.'
          : text.trim(),
    };
  }
}

final marketplaceActionPlannerProvider = Provider<MarketplaceActionPlanner>((ref) {
  return MarketplaceActionPlanner(ref.read(aiEdgeRepositoryProvider));
});
