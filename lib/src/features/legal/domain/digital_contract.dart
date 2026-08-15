class DigitalContract {
  const DigitalContract({
    required this.id,
    required this.title,
    required this.status,
    this.content,
    this.templateType,
    this.ownerId,
    this.clientId,
    this.ownerSignedAt,
    this.clientSignedAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String status;
  final String? content;
  final String? templateType;
  final String? ownerId;
  final String? clientId;
  final DateTime? ownerSignedAt;
  final DateTime? clientSignedAt;
  final DateTime? updatedAt;

  factory DigitalContract.fromJson(Map<String, dynamic> json) {
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
      ownerSignedAt: _date(json['owner_signed_at']),
      clientSignedAt: _date(json['client_signed_at']),
      updatedAt: _date(json['updated_at']),
    );
  }

  static DateTime? _date(dynamic value) {
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String get statusLabel => status.replaceAll('_', ' ').toUpperCase();

  bool needsSignature(String userId) {
    if (status == 'signed' || status == 'completed' || status == 'cancelled') {
      return false;
    }
    if (ownerId == userId && ownerSignedAt == null) return true;
    if (clientId == userId && clientSignedAt == null) return true;
    return status == 'draft' || status == 'sent' || status == 'pending';
  }
}

class ContractTemplate {
  const ContractTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.content,
  });

  final String id;
  final String name;
  final String description;
  final String content;
}

const contractTemplates = [
  ContractTemplate(
    id: 'long-term-rental-3months',
    name: 'Long-Term Rental Agreement',
    description: 'Standard 3+ month lease for a property',
    content:
        'LONG-TERM RENTAL AGREEMENT\n\nThis Rental Agreement is entered into as of the Effective Date between Landlord and Tenant.\n\n1. PROPERTY\nThe Landlord rents the property described in this document to the Tenant.\n\n2. TERM\nMinimum term of 3 months, then month-to-month unless either party gives 30 days notice.\n\n3. RENT\nMonthly rent is due on the agreed date. Late fees may apply.\n\n4. DEPOSIT\nA security deposit will be held and returned within 30 days minus damages beyond normal wear.\n\n5. RULES\nNo illegal activity. Pets and smoking only if agreed in writing.\n\nSign below to execute this agreement.',
  ),
  ContractTemplate(
    id: 'short-term-rental',
    name: 'Short-Term Rental',
    description: 'Vacation / short stay agreement',
    content:
        'SHORT-TERM RENTAL AGREEMENT\n\nGuest agrees to occupy the property only for the reserved dates, leave it in the same condition, and follow house rules.\n\nPayment is due before check-in. A damage deposit may be held.\n\nSign to confirm the stay.',
  ),
  ContractTemplate(
    id: 'service-agreement',
    name: 'Service / Worker Agreement',
    description: 'Hire a worker or professional',
    content:
        'SERVICE AGREEMENT\n\nThe Client hires the Service Provider for the described work at the agreed rate.\n\nThe Provider will perform the work professionally, bring required tools, and invoice as agreed.\n\nEither party may cancel with reasonable notice.\n\nSign to accept these terms.',
  ),
  ContractTemplate(
    id: 'vehicle-sale',
    name: 'Vehicle Sale Bill of Sale',
    description: 'Motorcycle, bicycle, or yacht sale',
    content:
        'BILL OF SALE\n\nSeller transfers ownership of the described vehicle to Buyer for the agreed price, as-is unless otherwise written.\n\nBuyer inspects the vehicle before signing. Title/registration transfer is the Buyer\'s responsibility where required.\n\nSign to complete the sale.',
  ),
];
