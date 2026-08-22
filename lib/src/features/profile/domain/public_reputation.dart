class PublicReputation {
  const PublicReputation({
    required this.userId,
    required this.verified,
    required this.reviewCount,
    required this.connections,
    this.averageRating,
    this.responseRate,
    this.accountSince,
  });

  final String userId;
  final bool verified;
  final int reviewCount;
  final double? averageRating;
  final int connections;
  final double? responseRate;
  final DateTime? accountSince;

  factory PublicReputation.fromJson(Map<dynamic, dynamic> json) {
    double? number(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    return PublicReputation(
      userId: json['user_id']?.toString() ?? '',
      verified: json['verified'] == true,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      averageRating: number('average_rating'),
      connections: (json['connections'] as num?)?.toInt() ?? 0,
      responseRate: number('response_rate'),
      accountSince: DateTime.tryParse(json['account_since']?.toString() ?? ''),
    );
  }

  int? get memberSinceYear => accountSince?.year;
}
