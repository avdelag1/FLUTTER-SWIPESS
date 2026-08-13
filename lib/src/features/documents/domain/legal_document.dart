class LegalDocument {
  const LegalDocument({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.documentType,
    required this.status,
    required this.createdAt,
    this.fileSize = 0,
    this.mimeType,
  });

  final String id;
  final String fileName;
  final String filePath;
  final String documentType;
  final String status;
  final DateTime? createdAt;
  final int fileSize;
  final String? mimeType;

  factory LegalDocument.fromJson(Map<String, dynamic> json) {
    return LegalDocument(
      id: json['id'] as String,
      fileName: json['file_name'] as String? ?? 'Document',
      filePath: json['file_path'] as String? ?? '',
      documentType: json['document_type'] as String? ?? 'other',
      status: json['status'] as String? ?? 'uploaded',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
      mimeType: json['mime_type'] as String?,
    );
  }

  bool get isImage {
    final mime = mimeType?.toLowerCase() ?? '';
    if (mime.startsWith('image/')) return true;
    return RegExp(
      r'\.(jpe?g|png|webp|gif|heic)$',
      caseSensitive: false,
    ).hasMatch(fileName);
  }

  String get category {
    switch (documentType) {
      case 'rental_agreement':
      case 'ownership_deed':
      case 'six_month_lease':
        return 'contracts';
      case 'government_id':
      case 'passport':
      case 'rfc':
      case 'drivers_license':
        return 'identity';
      case 'fideicomiso':
        return 'fideicomiso';
      default:
        return 'other';
    }
  }

  String get typeLabel {
    switch (documentType) {
      case 'rental_agreement':
        return 'Rental Agreement';
      case 'ownership_deed':
        return 'Ownership Deed';
      case 'fideicomiso':
        return 'Fideicomiso';
      case 'government_id':
        return 'Gov. ID';
      case 'passport':
        return 'Passport';
      case 'rfc':
        return 'RFC Document';
      case 'drivers_license':
        return 'License';
      case 'six_month_lease':
        return '6-Month Lease';
      case 'recommendation':
        return 'Recommendation';
      default:
        return 'Other';
    }
  }

  String get sizeLabel {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1048576) return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize / 1048576).toStringAsFixed(1)}MB';
  }
}

class DocTypeOption {
  const DocTypeOption(this.value, this.label, this.category);
  final String value;
  final String label;
  final String category;
}

const documentTypeOptions = [
  DocTypeOption('rental_agreement', 'Rental Agreement', 'contracts'),
  DocTypeOption('six_month_lease', '6-Month Lease', 'contracts'),
  DocTypeOption('ownership_deed', 'Ownership Deed', 'contracts'),
  DocTypeOption('fideicomiso', 'Fideicomiso', 'fideicomiso'),
  DocTypeOption('government_id', 'Gov. ID', 'identity'),
  DocTypeOption('passport', 'Passport', 'identity'),
  DocTypeOption('drivers_license', 'License', 'identity'),
  DocTypeOption('rfc', 'RFC Document', 'identity'),
  DocTypeOption('recommendation', 'Recommendation', 'other'),
  DocTypeOption('other', 'Other', 'other'),
];

/// Cap VAP vault slots shown on the PEARL card.
const vapVaultDocTypes = [
  ('passport', 'Passport'),
  ('government_id', 'Gov. ID'),
  ('drivers_license', 'License'),
  ('six_month_lease', '6-Month Lease'),
  ('recommendation', 'Recommendation'),
];

String detectDocType(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.contains('recommend') ||
      lower.contains('reference') ||
      lower.contains('carta')) {
    return 'recommendation';
  }
  if (lower.contains('6-month') ||
      lower.contains('six month') ||
      lower.contains('six_month')) {
    return 'six_month_lease';
  }
  if (lower.contains('rental') ||
      lower.contains('lease') ||
      lower.contains('contrato')) {
    return 'rental_agreement';
  }
  if (lower.contains('deed') || lower.contains('escritura')) {
    return 'ownership_deed';
  }
  if (lower.contains('fideicomiso') || lower.contains('trust')) {
    return 'fideicomiso';
  }
  if (lower.contains('passport') || lower.contains('pasaporte')) {
    return 'passport';
  }
  if (lower.contains('rfc')) return 'rfc';
  if (lower.contains('license') ||
      lower.contains('licencia') ||
      lower.contains('driver')) {
    return 'drivers_license';
  }
  if (lower.contains('ine') || lower.contains('id')) {
    return 'government_id';
  }
  return 'other';
}
