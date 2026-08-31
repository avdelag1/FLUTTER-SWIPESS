class PricePoint {
  const PricePoint({
    required this.neighborhood,
    required this.month,
    required this.year,
    required this.avgPrice,
    required this.listingCount,
    this.currency = 'USD',
  });

  final String neighborhood;
  final int month;
  final int year;
  final double avgPrice;
  final int listingCount;
  final String currency;

  factory PricePoint.fromJson(Map<String, dynamic> json) {
    return PricePoint(
      neighborhood: (json['neighborhood'] as String?) ?? 'Unknown',
      month: (json['month'] as num?)?.toInt() ?? DateTime.now().month,
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      avgPrice: (json['avg_price'] as num?)?.toDouble() ?? 0,
      listingCount: (json['listing_count'] as num?)?.toInt() ?? 0,
      currency: (json['currency'] as String?)?.trim().isNotEmpty == true
          ? (json['currency'] as String).trim().toUpperCase()
          : 'USD',
    );
  }
}
