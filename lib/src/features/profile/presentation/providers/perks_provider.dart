import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PerkOffer {
  const PerkOffer({
    required this.name,
    required this.detail,
    required this.percent,
  });

  final String name;
  final String detail;
  final int percent;
}

class PerksSnapshot {
  const PerksSnapshot({
    this.offers = const [],
    this.partners = const [],
    this.saved = 0,
  });

  final List<PerkOffer> offers;
  final List<String> partners;
  final double saved;
}

final perksSnapshotProvider = FutureProvider<PerksSnapshot>((ref) async {
  final client = Supabase.instance.client;
  try {
    final offersRaw = await client
        .from('discount_offers')
        .select('*, business_partners(name, logo_url)')
        .eq('is_active', true);
    final partnersRaw = await client
        .from('business_partners')
        .select('name')
        .eq('is_active', true);
    final userId = client.auth.currentUser?.id;
    var saved = 0.0;
    if (userId != null) {
      final redemptions = await client
          .from('discount_redemptions')
          .select('amount_saved')
          .eq('user_id', userId);
      for (final row in redemptions as List) {
        saved += ((row as Map)['amount_saved'] as num?)?.toDouble() ?? 0;
      }
    }
    final offers = <PerkOffer>[];
    for (final row in offersRaw as List) {
      final map = row as Map<String, dynamic>;
      final partner = map['business_partners'];
      final partnerName = partner is Map
          ? partner['name']?.toString() ?? 'Partner'
          : 'Partner';
      offers.add(
        PerkOffer(
          name: partnerName,
          detail: map['title']?.toString() ?? map['description']?.toString() ?? '',
          percent: (map['percent_off'] as num?)?.toInt() ??
              (map['discount_percent'] as num?)?.toInt() ??
              10,
        ),
      );
    }
    return PerksSnapshot(
      offers: offers,
      partners: [
        for (final row in partnersRaw as List)
          (row as Map)['name']?.toString() ?? 'Partner',
      ],
      saved: saved,
    );
  } catch (_) {
    return const PerksSnapshot();
  }
});
