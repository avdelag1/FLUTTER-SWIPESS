class PricePoint {
  const PricePoint({
    required this.neighborhood,
    required this.month,
    required this.year,
    required this.avgPrice,
    required this.listingCount,
  });

  final String neighborhood;
  final int month;
  final int year;
  final double avgPrice;
  final int listingCount;

  factory PricePoint.fromJson(Map<String, dynamic> json) {
    return PricePoint(
      neighborhood: (json['neighborhood'] as String?) ?? 'Unknown',
      month: (json['month'] as num?)?.toInt() ?? 1,
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      avgPrice: (json['avg_price'] as num?)?.toDouble() ?? 0,
      listingCount: (json['listing_count'] as num?)?.toInt() ?? 0,
    );
  }
}
