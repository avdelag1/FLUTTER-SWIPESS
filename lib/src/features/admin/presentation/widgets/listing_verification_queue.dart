import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Admin-only queue for private owner / professional verification evidence.
///
/// Documents are stored in the private `legal-documents` bucket. Admins get a
/// short-lived signed URL only when they explicitly open a file. Approving the
/// pending documents triggers the database verification sync, which is what
/// turns on the public blue verified badge for the listing.
class ListingVerificationQueue extends StatefulWidget {
  const ListingVerificationQueue({super.key});

  @override
  State<ListingVerificationQueue> createState() =>
      _ListingVerificationQueueState();
}

class _ListingVerificationQueueState extends State<ListingVerificationQueue> {
  final SupabaseClient _client = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _pending;
  String? _busyListingId;

  @override
  void initState() {
    super.initState();
    _pending = _loadPending();
  }

  Future<List<Map<String, dynamic>>> _loadPending() async {
    try {
      final rows = await _client
          .from('listing_legal_documents')
          .select(
            'id, listing_id, owner_id, file_name, file_path, mime_type, file_size, document_type, status, created_at, listings(id, title, category, city)',
          )
          .eq('status', 'pending')
          .order('created_at', ascending: true)
          .limit(100);
      return [
        for (final row in rows)
          Map<String, dynamic>.from(row),
      ];
    } catch (_) {
      // Keep the queue usable if PostgREST relation metadata is temporarily
      // unavailable after a schema refresh. The document itself is sufficient
      // for review; listing metadata simply falls back to generic labels.
      final rows = await _client
          .from('listing_legal_documents')
          .select(
            'id, listing_id, owner_id, file_name, file_path, mime_type, file_size, document_type, status, created_at',
          )
          .eq('status', 'pending')
          .order('created_at', ascending: true)
          .limit(100);
      return [
        for (final row in rows)
          Map<String, dynamic>.from(row),
      ];
    }
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _pending = _loadPending());
  }

  Future<void> _openDocument(Map<String, dynamic> row) async {
    final path = row['file_path']?.toString();
    if (path == null || path.isEmpty) return;
    try {
      final signedUrl = await _client.storage
          .from('legal-documents')
          .createSignedUrl(path, 300);
      final uri = Uri.parse(signedUrl);
      final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!opened) throw StateError('Could not open the verification file.');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open private proof: $error')),
      );
    }
  }

  Future<void> _setListingStatus(
    String listingId,
    List<Map<String, dynamic>> documents,
    String status,
  ) async {
    if (_busyListingId != null || documents.isEmpty) return;
    final user = _client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin session expired. Sign in again.')),
      );
      return;
    }

    setState(() => _busyListingId = listingId);
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final approved = status == 'approved';
      await _client
          .from('listing_legal_documents')
          .update({
            'status': status,
            'reviewed_by': user.id,
            'reviewed_at': now,
            'updated_at': now,
            'review_notes': approved
                ? 'Ownership/professional proof approved by Swipess admin.'
                : 'Ownership/professional proof rejected by Swipess admin.',
          })
          .eq('listing_id', listingId)
          .eq('status', 'pending');

      final ownerId = documents.first['owner_id']?.toString();
      final listing = _listingMeta(documents.first);
      final title = listing['title']?.toString().trim();
      if (ownerId != null && ownerId.isNotEmpty) {
        try {
          await _client.rpc(
            'create_notification_for_user',
            params: {
              'p_user_id': ownerId,
              'p_notification_type': 'system_announcement',
              'p_title': approved
                  ? 'Listing verified ✓'
                  : 'Verification needs attention',
              'p_message': approved
                  ? '${title == null || title.isEmpty ? 'Your listing' : '“$title”'} was verified. The blue badge is now visible to clients.'
                  : '${title == null || title.isEmpty ? 'Your listing' : '“$title”'} could not be verified from the submitted proof. Update the listing and submit valid ownership or professional evidence.',
            },
          );
        } catch (_) {
          // Review itself is authoritative; a notification outage must not undo
          // an admin moderation decision.
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? 'Listing approved — blue verified badge enabled.'
                : 'Verification rejected.',
          ),
        ),
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update verification: $error')),
      );
    } finally {
      if (mounted) setState(() => _busyListingId = null);
    }
  }

  Map<String, dynamic> _listingMeta(Map<String, dynamic> row) {
    final raw = row['listings'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const <String, dynamic>{};
  }

  Map<String, List<Map<String, dynamic>>> _groupByListing(
    List<Map<String, dynamic>> rows,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final listingId = row['listing_id']?.toString();
      if (listingId == null || listingId.isEmpty) continue;
      grouped.putIfAbsent(listingId, () => <Map<String, dynamic>>[]).add(row);
    }
    return grouped;
  }

  String _humanDocumentType(String? raw) {
    switch (raw) {
      case 'ownership_deed':
        return 'Ownership deed';
      case 'fideicomiso':
        return 'Fideicomiso / trust';
      case 'rental_agreement':
        return 'Rental authority';
      case 'boat_registration':
        return 'Boat registration';
      case 'vehicle_registration':
        return 'Vehicle registration';
      case 'professional_credential':
        return 'Professional credential';
      case 'business_registration':
        return 'Business registration';
      default:
        return 'Verification proof';
    }
  }

  String _fileSize(dynamic raw) {
    final bytes = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${bytes.toStringAsFixed(0)} B';
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final foreground = isLight ? const Color(0xFF111318) : Colors.white;
    final secondary = isLight
        ? const Color(0xFF65707C)
        : Colors.white.withValues(alpha: .68);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _pending,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        final groups = _groupByListing(rows);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isLight
                ? Colors.white.withValues(alpha: .86)
                : Colors.white.withValues(alpha: .045),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isLight
                  ? Colors.black.withValues(alpha: .08)
                  : Colors.white.withValues(alpha: .13),
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
                    decoration: BoxDecoration(
                      color: const Color(0xFF1687FF).withValues(alpha: .14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFF1687FF),
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Listing verification queue',
                          style: GoogleFonts.plusJakartaSans(
                            color: foreground,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Private proof for direct owners and serious professionals.',
                          style: GoogleFonts.plusJakartaSans(
                            color: secondary,
                            fontSize: 11,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: groups.isEmpty
                          ? const Color(0xFF10B981).withValues(alpha: .12)
                          : AppTheme.brandPrimary.withValues(alpha: .14),
                    ),
                    child: Text(
                      '${groups.length} pending',
                      style: GoogleFonts.plusJakartaSans(
                        color: foreground,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Documents never appear publicly. Clients only see the blue badge after an admin approves the evidence.',
                style: GoogleFonts.plusJakartaSans(
                  color: secondary,
                  fontSize: 10.5,
                  height: 1.4,
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(),
              ] else if (snapshot.hasError) ...[
                const SizedBox(height: 14),
                Text(
                  'Verification queue unavailable: ${snapshot.error}',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.brandPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ] else if (groups.isEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF10B981),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'No verification requests waiting.',
                      style: GoogleFonts.plusJakartaSans(
                        color: foreground,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 14),
                for (final entry in groups.entries) ...[
                  _listingCard(
                    context,
                    entry.key,
                    entry.value,
                    isLight: isLight,
                    foreground: foreground,
                    secondary: secondary,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _listingCard(
    BuildContext context,
    String listingId,
    List<Map<String, dynamic>> documents, {
    required bool isLight,
    required Color foreground,
    required Color secondary,
  }) {
    final listing = _listingMeta(documents.first);
    final title = listing['title']?.toString().trim();
    final category = listing['category']?.toString().trim();
    final city = listing['city']?.toString().trim();
    final busy = _busyListingId == listingId;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isLight
            ? const Color(0xFFF5F6F8)
            : Colors.black.withValues(alpha: .18),
        border: Border.all(
          color: isLight
              ? Colors.black.withValues(alpha: .06)
              : Colors.white.withValues(alpha: .09),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title == null || title.isEmpty ? 'Listing $listingId' : title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: foreground,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            [
              if (category != null && category.isNotEmpty) category.toUpperCase(),
              if (city != null && city.isNotEmpty) city,
              '${documents.length} proof file${documents.length == 1 ? '' : 's'}',
            ].join(' · '),
            style: GoogleFonts.plusJakartaSans(
              color: secondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final document in documents)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  Icon(
                    document['mime_type']?.toString().contains('pdf') == true
                        ? Icons.picture_as_pdf_rounded
                        : Icons.insert_drive_file_rounded,
                    color: const Color(0xFF1687FF),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document['file_name']?.toString() ?? 'Verification file',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: foreground,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${_humanDocumentType(document['document_type']?.toString())} · ${_fileSize(document['file_size'])}',
                          style: GoogleFonts.plusJakartaSans(
                            color: secondary,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: busy ? null : () => _openDocument(document),
                    icon: const Icon(Icons.visibility_rounded, size: 16),
                    label: const Text('Review'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _setListingStatus(
                            listingId,
                            documents,
                            'rejected',
                          ),
                  icon: const Icon(Icons.close_rounded, size: 17),
                  label: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => _setListingStatus(
                            listingId,
                            documents,
                            'approved',
                          ),
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_rounded, size: 17),
                  label: Text(busy ? 'Saving…' : 'Approve listing'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1687FF),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
