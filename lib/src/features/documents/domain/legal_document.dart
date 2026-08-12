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

  String get category {
    switch (documentType) {
      case 'rental_agreement':
      case 'ownership_deed':
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
        return 'Government ID';
      case 'passport':
        return 'Passport';
      case 'rfc':
        return 'RFC Document';
      case 'drivers_license':
        return 'License';
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
  DocTypeOption('ownership_deed', 'Ownership Deed', 'contracts'),
  DocTypeOption('fideicomiso', 'Fideicomiso', 'fideicomiso'),
  DocTypeOption('government_id', 'Government ID', 'identity'),
  DocTypeOption('passport', 'Passport', 'identity'),
  DocTypeOption('rfc', 'RFC Document', 'identity'),
  DocTypeOption('other', 'Other', 'other'),
];

String detectDocType(String fileName) {
  final lower = fileName.toLowerCase();
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
  if (lower.contains('ine') ||
      lower.contains('license') ||
      lower.contains('id')) {
    return 'government_id';
  }
  return 'other';
}
