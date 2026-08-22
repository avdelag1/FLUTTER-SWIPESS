class LegalIntake {
  const LegalIntake({
    required this.id,
    required this.status,
    this.packageId,
    this.packageName,
    this.packageCategory,
    this.quotedPrice,
    this.situation,
    this.city,
    this.lawyerNotes,
    this.declineReason,
    this.consultAt,
    this.expiresAt,
    this.paidAt,
    this.createdAt,
  });

  final String id;
  final String status;
  final String? packageId;
  final String? packageName;
  final String? packageCategory;
  final double? quotedPrice;
  final String? situation;
  final String? city;
  final String? lawyerNotes;
  final String? declineReason;
  final DateTime? consultAt;
  final DateTime? expiresAt;
  final DateTime? paidAt;
  final DateTime? createdAt;

  bool get isWaiting => status == 'pending';
  bool get canPay => status == 'offered';
  bool get canCancel => status == 'pending' || status == 'offered';
  bool get canJoinCall =>
      (status == 'scheduled' || status == 'paid') && consultAt != null;

  String get headline {
    final name = packageName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final cat = packageCategory?.trim();
    if (cat != null && cat.isNotEmpty) return cat.replaceAll('_', ' ');
    return 'Legal request';
  }

  String get statusLabel => switch (status) {
    'pending' => 'Waiting for a lawyer',
    'offered' => 'Lawyer accepted — pay to continue',
    'paid' => 'Paid — waiting for a consult time',
    'scheduled' => 'Consult booked',
    'declined' => 'Declined',
    'cancelled' => 'Cancelled',
    'expired' => 'Expired',
    'completed' => 'Completed',
    _ => status,
  };

  factory LegalIntake.fromJson(Map<String, dynamic> json) {
    DateTime? ts(String key) {
      final raw = json[key];
      if (raw is! String || raw.isEmpty) return null;
      return DateTime.tryParse(raw)?.toLocal();
    }

    return LegalIntake(
      id: json['id'] as String,
      status: (json['status'] as String?) ?? 'pending',
      packageId: json['package_id'] as String?,
      packageName: json['package_name'] as String?,
      packageCategory: json['package_category'] as String?,
      quotedPrice: (json['quoted_price'] as num?)?.toDouble(),
      situation: json['situation'] as String?,
      city: json['city'] as String?,
      lawyerNotes: json['lawyer_notes'] as String?,
      declineReason: json['decline_reason'] as String?,
      consultAt: ts('consult_at'),
      expiresAt: ts('expires_at'),
      paidAt: ts('paid_at'),
      createdAt: ts('created_at'),
    );
  }
}
