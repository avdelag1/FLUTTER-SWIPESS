class EscrowDeposit {
  const EscrowDeposit({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
    this.contractId,
    this.clientId,
    this.ownerId,
    this.heldAt,
    this.releasedAt,
    this.disputedAt,
    this.notes,
  });

  final String id;
  final double amount;
  final String currency;
  final String status;
  final DateTime createdAt;
  final String? contractId;
  final String? clientId;
  final String? ownerId;
  final DateTime? heldAt;
  final DateTime? releasedAt;
  final DateTime? disputedAt;
  final String? notes;

  factory EscrowDeposit.fromJson(Map<String, dynamic> json) {
    return EscrowDeposit(
      id: json['id'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      contractId: json['contract_id'] as String?,
      clientId: json['client_id'] as String?,
      ownerId: json['owner_id'] as String?,
      heldAt: json['held_at'] != null
          ? DateTime.tryParse(json['held_at'] as String)
          : null,
      releasedAt: json['released_at'] != null
          ? DateTime.tryParse(json['released_at'] as String)
          : null,
      disputedAt: json['disputed_at'] != null
          ? DateTime.tryParse(json['disputed_at'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }

  String get amountLabel =>
      '\$${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)} $currency';
}
