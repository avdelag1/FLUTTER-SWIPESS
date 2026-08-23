import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/documents/domain/legal_document.dart';
import 'package:flutter_swipes/src/features/documents/presentation/widgets/document_preview_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminIdentityDocumentsPanel extends StatefulWidget {
  const AdminIdentityDocumentsPanel({super.key});

  @override
  State<AdminIdentityDocumentsPanel> createState() =>
      _AdminIdentityDocumentsPanelState();
}

class _AdminIdentityDocumentsPanelState
    extends State<AdminIdentityDocumentsPanel> {
  late Future<List<_AdminDocumentRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_AdminDocumentRecord>> _load() async {
    final client = Supabase.instance.client;
    final raw = await client
        .from('user_identity_documents')
        .select(
          'id,user_id,file_name,file_path,document_type,status,created_at,file_size,mime_type',
        )
        .order('created_at', ascending: false)
        .limit(100);

    final rows = (raw as List)
        .cast<Map<String, dynamic>>();
    if (rows.isEmpty) return const [];

    final userIds = rows
        .map((row) => row['user_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList(growable: false);

    final names = <String, String>{};
    if (userIds.isNotEmpty) {
      try {
        final profileRows = await client
            .from('client_profiles')
            .select('user_id,name')
            .inFilter('user_id', userIds);
        for (final row in (profileRows as List).cast<Map<String, dynamic>>()) {
          final id = row['user_id'] as String?;
          final name = row['name'] as String?;
          if (id != null && name != null && name.trim().isNotEmpty) {
            names[id] = name.trim();
          }
        }
      } catch (_) {
        // Admin can still inspect documents by user id if a profile row is
        // missing or profile visibility is temporarily restricted.
      }
    }

    return rows.map((row) {
      final userId = row['user_id'] as String? ?? 'unknown';
      return _AdminDocumentRecord(
        userId: userId,
        userName: names[userId],
        document: LegalDocument.fromJson(row),
      );
    }).toList(growable: false);
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final foreground = isLight ? const Color(0xFF111318) : Colors.white;
    final secondary = isLight
        ? const Color(0xFF68717D)
        : Colors.white.withAlpha(158);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withAlpha(220)
            : AppTheme.dashGlassStrong.withAlpha(214),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isLight
              ? Colors.black.withAlpha(22)
              : Colors.white.withAlpha(38),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: AppTheme.dashboardFilterPill(isLight: isLight),
                alignment: Alignment.center,
                child: Icon(
                  Icons.folder_shared_outlined,
                  color: foreground,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IDENTITY DOCUMENTS',
                      style: GoogleFonts.plusJakartaSans(
                        color: foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Launch mode: uploads are automatically approved. Tap a file to inspect it.',
                      style: GoogleFonts.plusJakartaSans(
                        color: secondary,
                        fontSize: 10.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh documents',
                onPressed: _refresh,
                icon: Icon(Icons.refresh_rounded, color: foreground),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<_AdminDocumentRecord>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Could not load identity documents.',
                          style: TextStyle(color: secondary),
                        ),
                      ),
                      TextButton(onPressed: _refresh, child: const Text('Retry')),
                    ],
                  ),
                );
              }

              final records = snapshot.data ?? const <_AdminDocumentRecord>[];
              if (records.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'No user documents uploaded yet.',
                    style: GoogleFonts.plusJakartaSans(
                      color: secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }

              final grouped = <String, List<_AdminDocumentRecord>>{};
              for (final record in records) {
                grouped.putIfAbsent(record.userId, () => []).add(record);
              }

              return Column(
                children: [
                  for (final entry in grouped.entries) ...[
                    _UserDocumentGroup(
                      records: entry.value,
                      isLight: isLight,
                    ),
                    if (entry.key != grouped.keys.last)
                      const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UserDocumentGroup extends StatelessWidget {
  const _UserDocumentGroup({required this.records, required this.isLight});

  final List<_AdminDocumentRecord> records;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final first = records.first;
    final foreground = isLight ? const Color(0xFF111318) : Colors.white;
    final secondary = isLight
        ? const Color(0xFF68717D)
        : Colors.white.withAlpha(150);
    final userLabel = first.userName ?? 'User ${_shortId(first.userId)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLight ? Colors.black.withAlpha(6) : Colors.white.withAlpha(9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLight
              ? Colors.black.withAlpha(16)
              : Colors.white.withAlpha(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline_rounded, color: foreground, size: 17),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  userLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${records.length} file${records.length == 1 ? '' : 's'}',
                style: TextStyle(color: secondary, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 9),
          for (final record in records)
            _AdminDocumentTile(record: record, isLight: isLight),
        ],
      ),
    );
  }

  static String _shortId(String id) {
    if (id.length <= 8) return id;
    return id.substring(0, 8);
  }
}

class _AdminDocumentTile extends StatelessWidget {
  const _AdminDocumentTile({required this.record, required this.isLight});

  final _AdminDocumentRecord record;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final doc = record.document;
    final foreground = isLight ? const Color(0xFF111318) : Colors.white;
    final secondary = isLight
        ? const Color(0xFF68717D)
        : Colors.white.withAlpha(145);
    final approved = doc.status.toLowerCase() == 'approved';

    return Padding(
      padding: const EdgeInsets.only(top: 5, bottom: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => showDocumentPreviewDialog(context, doc),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            child: Row(
              children: [
                Icon(
                  doc.isImage
                      ? Icons.image_outlined
                      : Icons.picture_as_pdf_outlined,
                  color: foreground,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: foreground,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${doc.typeLabel} · ${doc.sizeLabel}',
                        style: TextStyle(color: secondary, fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: approved
                        ? const Color(0xFF36D17C).withAlpha(28)
                        : foreground.withAlpha(14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    doc.status.toUpperCase(),
                    style: TextStyle(
                      color: approved ? const Color(0xFF36D17C) : secondary,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Icon(Icons.visibility_outlined, color: secondary, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminDocumentRecord {
  const _AdminDocumentRecord({
    required this.userId,
    required this.userName,
    required this.document,
  });

  final String userId;
  final String? userName;
  final LegalDocument document;
}
