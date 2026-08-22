class DigitalContract {
  const DigitalContract({
    required this.id,
    required this.title,
    required this.status,
    this.content,
    this.templateType,
    this.ownerId,
    this.clientId,
    this.createdBy,
    this.metadata = const {},
    this.ownerSignature,
    this.clientSignature,
    this.ownerSignedAt,
    this.clientSignedAt,
    this.sentAt,
    this.completedAt,
    this.cancelledAt,
    this.counterpartyLabel,
    this.documentHash,
    this.version = 1,
    this.updatedAt,
    this.createdAt,
  });

  final String id;
  final String title;
  final String status;
  final String? content;
  final String? templateType;
  final String? ownerId;
  final String? clientId;
  final String? createdBy;
  final Map<String, dynamic> metadata;
  final String? ownerSignature;
  final String? clientSignature;
  final DateTime? ownerSignedAt;
  final DateTime? clientSignedAt;
  final DateTime? sentAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? counterpartyLabel;
  final String? documentHash;
  final int version;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  factory DigitalContract.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    return DigitalContract(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Contract',
      status: json['status'] as String? ?? 'draft',
      content:
          json['content'] as String? ?? json['terms_and_conditions'] as String?,
      templateType:
          json['template_type'] as String? ?? json['contract_type'] as String?,
      ownerId: json['owner_id'] as String?,
      clientId: json['client_id'] as String?,
      createdBy: json['created_by'] as String?,
      metadata: rawMetadata is Map
          ? Map<String, dynamic>.from(rawMetadata)
          : const <String, dynamic>{},
      ownerSignature: json['owner_signature'] as String?,
      clientSignature: json['client_signature'] as String?,
      ownerSignedAt: _date(json['owner_signed_at']),
      clientSignedAt: _date(json['client_signed_at']),
      sentAt: _date(json['sent_at']),
      completedAt: _date(json['completed_at']),
      cancelledAt: _date(json['cancelled_at']),
      counterpartyLabel: json['counterparty_label'] as String?,
      documentHash: json['document_hash'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 1,
      updatedAt: _date(json['updated_at']),
      createdAt: _date(json['created_at']),
    );
  }

  static DateTime? _date(dynamic value) {
    if (value is String) return DateTime.tryParse(value);
    if (value is DateTime) return value;
    return null;
  }

  bool get isDraft => status == 'draft' || status == 'pending';
  bool get isSent => status == 'sent';
  bool get isCompleted =>
      status == 'completed' || status == 'signed' || status == 'fully_signed';
  bool get isCancelled => status == 'cancelled';
  bool get isDisputed => status == 'disputed';
  bool get isLocked => !isDraft;
  bool get hasOwnerSignature => ownerSignedAt != null || ownerSignature != null;
  bool get hasClientSignature => clientSignedAt != null || clientSignature != null;
  bool get hasCounterparty => clientId != null && clientId != ownerId;

  String get statusLabel {
    switch (status) {
      case 'draft':
      case 'pending':
        return 'DRAFT';
      case 'sent':
        return 'WAITING FOR SIGNATURES';
      case 'signed_by_owner':
        return 'OWNER SIGNED';
      case 'signed_by_client':
        return 'CLIENT SIGNED';
      case 'completed':
      case 'signed':
      case 'fully_signed':
        return 'FULLY SIGNED';
      case 'cancelled':
        return 'CANCELLED';
      case 'disputed':
        return 'DISPUTED';
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  String get compactStatusLabel {
    if (isCompleted) return 'SIGNED';
    if (isDraft) return 'DRAFT';
    if (status == 'signed_by_owner' || status == 'signed_by_client') {
      return '1 SIGNATURE';
    }
    return statusLabel;
  }

  bool isOwner(String userId) => ownerId == userId || createdBy == userId;
  bool isClient(String userId) => clientId == userId && clientId != ownerId;

  bool needsSignature(String userId) {
    if (isCompleted || isCancelled || isDisputed) return false;
    if (isOwner(userId) && !hasOwnerSignature) return true;
    if (isClient(userId) && !hasClientSignature) return true;
    return false;
  }

  bool canEdit(String userId) => isDraft && isOwner(userId);
  bool canSend(String userId) =>
      isOwner(userId) && !isCompleted && !isCancelled && !hasClientSignature;
}

class ContractPartyMatch {
  const ContractPartyMatch({
    required this.userId,
    required this.displayName,
    this.username,
  });

  final String userId;
  final String displayName;
  final String? username;

  factory ContractPartyMatch.fromJson(Map<String, dynamic> json) {
    return ContractPartyMatch(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String? ?? 'Swipess user',
      username: json['username'] as String?,
    );
  }
}

class ContractEvent {
  const ContractEvent({
    required this.id,
    required this.contractId,
    required this.eventType,
    required this.createdAt,
    this.actorId,
    this.metadata = const {},
  });

  final String id;
  final String contractId;
  final String eventType;
  final DateTime createdAt;
  final String? actorId;
  final Map<String, dynamic> metadata;

  factory ContractEvent.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    return ContractEvent(
      id: json['id'] as String,
      contractId: json['contract_id'] as String,
      eventType: json['event_type'] as String? ?? 'updated',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      actorId: json['actor_id'] as String?,
      metadata: rawMetadata is Map
          ? Map<String, dynamic>.from(rawMetadata)
          : const <String, dynamic>{},
    );
  }

  String get label {
    switch (eventType) {
      case 'created':
        return 'Document created';
      case 'updated':
        return 'Draft updated';
      case 'sent':
        return 'Sent for signature';
      case 'signed':
        return 'Signature recorded';
      case 'cancelled':
        return 'Document cancelled';
      default:
        return eventType.replaceAll('_', ' ');
    }
  }
}
