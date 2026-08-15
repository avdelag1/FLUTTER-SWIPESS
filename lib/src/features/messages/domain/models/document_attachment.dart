/// Cap `messageDocuments.ts` — document/contract attachments carried on a
/// `conversation_messages` row via the `attachments` jsonb column.
library;

const _documentMessageTypes = {'document', 'contract', 'lease'};

bool isDocumentMessage(String? messageType) =>
    messageType != null && _documentMessageTypes.contains(messageType);

class DocumentAttachment {
  const DocumentAttachment({
    required this.type,
    required this.id,
    required this.title,
    this.status = 'draft',
    this.templateType,
    this.fileName,
  });

  /// `digital_contract` | `vault_file`
  final String type;
  final String id;
  final String title;

  /// draft | sent | signed | uploaded
  final String status;
  final String? templateType;
  final String? fileName;

  bool get isContract => type == 'digital_contract';
  bool get isSigned => status == 'signed';

  factory DocumentAttachment.fromJson(Map<String, dynamic> json) {
    return DocumentAttachment(
      type: json['type'] as String? ?? 'vault_file',
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Document',
      status: json['status'] as String? ?? 'draft',
      templateType: json['template_type'] as String?,
      fileName: json['file_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'title': title,
    'status': status,
    if (templateType != null) 'template_type': templateType,
    if (fileName != null) 'file_name': fileName,
  };
}

/// Cap `parseDocumentAttachments` — tolerant of malformed/legacy rows.
List<DocumentAttachment> parseDocumentAttachments(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .where((item) {
        final type = item['type'];
        final id = item['id'];
        return (type == 'digital_contract' || type == 'vault_file') &&
            id is String &&
            item['title'] is String;
      })
      .map(DocumentAttachment.fromJson)
      .toList();
}

/// Cap `buildDocumentShareContent`.
String buildDocumentShareContent(String title, String status) {
  if (status == 'signed') return 'Fully signed: "$title"';
  if (status == 'sent') return 'Lease sent for signature: "$title"';
  return 'Shared document: "$title"';
}

/// Cap `contractStatusLabel`.
String contractStatusLabel(String status) {
  switch (status) {
    case 'signed':
      return 'Fully signed';
    case 'sent':
      return 'Awaiting signature';
    case 'draft':
      return 'Draft / template';
    case 'uploaded':
      return 'Vault file';
    default:
      return 'Document';
  }
}
