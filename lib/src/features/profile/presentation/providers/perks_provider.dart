import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PerkOffer {
  const PerkOffer({
    required this.id,
    required this.businessName,
    required this.title,
    required this.percent,
    required this.code,
    required this.status,
    required this.createdAt,
    this.businessId,
    this.message,
    this.logoUrl,
    this.expiresAt,
    this.redeemedAt,
  });

  final String id;
  final String? businessId;
  final String businessName;
  final String title;
  final String? message;
  final int percent;
  final String code;
  final String status;
  final String? logoUrl;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? redeemedAt;

  bool get isRedeemed => redeemedAt != null || status.toLowerCase() == 'redeemed';

  bool get isExpired {
    final end = expiresAt;
    return end != null && end.isBefore(DateTime.now());
  }

  bool get isActive => !isRedeemed && !isExpired && status.toLowerCase() == 'active';
}

class PerkHistoryEntry {
  const PerkHistoryEntry({
    required this.id,
    required this.businessName,
    required this.total,
    required this.discountPercent,
    required this.saved,
    required this.createdAt,
    this.description,
    this.logoUrl,
  });

  final String id;
  final String businessName;
  final String? description;
  final String? logoUrl;
  final double total;
  final double discountPercent;
  final double saved;
  final DateTime createdAt;
}

class PerkPartner {
  const PerkPartner({
    required this.id,
    required this.name,
    this.logoUrl,
  });

  final String id;
  final String name;
  final String? logoUrl;
}

class PerksSnapshot {
  const PerksSnapshot({
    this.offers = const [],
    this.partners = const [],
    this.history = const [],
    this.saved = 0,
    this.scans = 0,
  });

  final List<PerkOffer> offers;
  final List<PerkPartner> partners;
  final List<PerkHistoryEntry> history;
  final double saved;
  final int scans;

  List<PerkOffer> get activeOffers =>
      offers.where((offer) => offer.isActive).toList(growable: false);
}

DateTime _date(dynamic value, {DateTime? fallback}) {
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '') ??
      fallback ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _nullableDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

List<Map<String, dynamic>> _maps(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}

/// Real resident perks only.
///
/// The server RPC reads only records belonging to the signed-in member:
/// partner scans, partner-issued promos and completed business transactions.
/// There is deliberately no demo fallback — an empty account stays empty until
/// a real partner interaction creates a real benefit.
final perksSnapshotProvider = FutureProvider<PerksSnapshot>((ref) async {
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return const PerksSnapshot();

  final raw = await client.rpc('rpc_my_resident_perks');
  if (raw is! Map) return const PerksSnapshot();
  final data = Map<String, dynamic>.from(raw);

  final offers = <PerkOffer>[];
  for (final row in _maps(data['offers'])) {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    offers.add(
      PerkOffer(
        id: id,
        businessId: row['business_id']?.toString(),
        businessName: row['business_name']?.toString().trim().isNotEmpty == true
            ? row['business_name'].toString().trim()
            : 'Partner',
        title: row['title']?.toString().trim().isNotEmpty == true
            ? row['title'].toString().trim()
            : 'Partner benefit',
        message: row['message']?.toString(),
        percent: _number(row['discount_percent']).round().clamp(0, 100),
        code: row['code']?.toString() ?? '',
        status: row['status']?.toString() ?? 'active',
        logoUrl: row['logo_url']?.toString(),
        createdAt: _date(row['created_at']),
        expiresAt: _nullableDate(row['expires_at']),
        redeemedAt: _nullableDate(row['redeemed_at']),
      ),
    );
  }

  final history = <PerkHistoryEntry>[];
  for (final row in _maps(data['history'])) {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    history.add(
      PerkHistoryEntry(
        id: id,
        businessName: row['business_name']?.toString().trim().isNotEmpty == true
            ? row['business_name'].toString().trim()
            : 'Partner',
        description: row['order_description']?.toString(),
        logoUrl: row['logo_url']?.toString(),
        total: _number(row['total_amount']),
        discountPercent: _number(row['discount_percentage']),
        saved: _number(row['discount_amount']),
        createdAt: _date(row['created_at']),
      ),
    );
  }

  final partners = <PerkPartner>[];
  for (final row in _maps(data['partners'])) {
    final id = row['business_id']?.toString() ?? '';
    if (id.isEmpty) continue;
    partners.add(
      PerkPartner(
        id: id,
        name: row['business_name']?.toString().trim().isNotEmpty == true
            ? row['business_name'].toString().trim()
            : 'Partner',
        logoUrl: row['logo_url']?.toString(),
      ),
    );
  }

  return PerksSnapshot(
    offers: offers,
    partners: partners,
    history: history,
    saved: _number(data['saved']),
    scans: _number(data['scans']).round(),
  );
});
