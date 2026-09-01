import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin-only control for granting or removing the public blue listing badge
/// without requiring a legal-document submission.
class ManualListingVerificationPanel extends StatefulWidget {
  const ManualListingVerificationPanel({super.key});

  @override
  State<ManualListingVerificationPanel> createState() =>
      _ManualListingVerificationPanelState();
}

class _ManualListingVerificationPanelState
    extends State<ManualListingVerificationPanel> {
  final SupabaseClient _client = Supabase.instance.client;
  final TextEditingController _search = TextEditingController();
  late Future<List<Map<String, dynamic>>> _listings;
  String? _busyListingId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _listings = _loadListings();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadListings() async {
    final rows = await _client
        .from('listings')
        .select(
          'id, owner_id, title, category, city, created_at, is_active, status, verification_status, verification_method',
        )
        .order('created_at', ascending: false)
        .limit(250);
    return [for (final row in rows) Map<String, dynamic>.from(row)];
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _listings = _loadListings());
  }

  bool _matches(Map<String, dynamic> row) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final haystack = [
      row['id'],
      row['title'],
      row['category'],
      row['city'],
    ].whereType<Object>().map((e) => e.toString().toLowerCase()).join(' ');
    return haystack.contains(q);
  }

  Future<void> _setBadge(Map<String, dynamic> row, bool verified) async {
    final listingId = row['id']?.toString();
    if (listingId == null || listingId.isEmpty || _busyListingId != null) return;

    final title = row['title']?.toString().trim();
    final label = title == null || title.isEmpty ? 'this listing' : '“$title”';
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(verified ? 'Give blue badge?' : 'Remove blue badge?'),
            content: Text(
              verified
                  ? 'Approve $label as a verified direct owner or serious professional without requiring an uploaded legal document.'
                  : 'Remove the verified status from $label. The public blue check will disappear.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: Icon(
                  verified ? Icons.verified_rounded : Icons.remove_circle_outline,
                ),
                label: Text(verified ? 'Verify listing' : 'Remove badge'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _busyListingId = listingId);
    try {
      await _client.rpc(
        'rpc_admin_set_listing_verification',
        params: {
          'p_listing_id': listingId,
          'p_verified': verified,
          'p_note': verified
              ? 'Blue badge granted manually by authorized Swipess admin.'
              : 'Blue badge removed manually by authorized Swipess admin.',
        },
      );

      final ownerId = row['owner_id']?.toString();
      if (ownerId != null && ownerId.isNotEmpty) {
        try {
          await _client.rpc(
            'create_notification_for_user',
            params: {
              'p_user_id': ownerId,
              'p_notification_type': 'system_announcement',
              'p_title': verified ? 'Listing verified ✓' : 'Verification updated',
              'p_message': verified
                  ? '$label was verified by Swipess. The blue check is now visible to clients.'
                  : 'The blue verification badge was removed from $label.',
            },
          );
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            verified
                ? 'Blue badge enabled for $label.'
                : 'Blue badge removed from $label.',
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

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final foreground = isLight ? const Color(0xFF111318) : Colors.white;
    final secondary = isLight
        ? const Color(0xFF65707C)
        : Colors.white.withValues(alpha: .68);

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
                  Icons.verified_rounded,
                  color: Color(0xFF1687FF),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manual blue badge control',
                      style: GoogleFonts.plusJakartaSans(
                        color: foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Admins can verify a trusted owner or professional with or without a document.',
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
              IconButton(
                tooltip: 'Refresh listings',
                onPressed: _busyListingId == null ? _refresh : null,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Search listing, city, category or ID',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: isLight
                  ? Colors.black.withValues(alpha: .035)
                  : Colors.white.withValues(alpha: .055),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _listings,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return Text(
                  'Could not load listings: ${snapshot.error}',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.brandPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }

              final rows = (snapshot.data ?? const <Map<String, dynamic>>[])
                  .where(_matches)
                  .take(30)
                  .toList();
              if (rows.isEmpty) {
                return Text(
                  'No listings match this search.',
                  style: GoogleFonts.plusJakartaSans(
                    color: secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }

              return Column(
                children: [
                  for (final row in rows) ...[
                    _listingRow(
                      row,
                      isLight: isLight,
                      foreground: foreground,
                      secondary: secondary,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _listingRow(
    Map<String, dynamic> row, {
    required bool isLight,
    required Color foreground,
    required Color secondary,
  }) {
    final id = row['id']?.toString() ?? '';
    final title = row['title']?.toString().trim();
    final category = row['category']?.toString().trim();
    final city = row['city']?.toString().trim();
    final status = row['verification_status']?.toString() ?? 'unverified';
    final method = row['verification_method']?.toString() ?? 'none';
    final verified = status == 'approved';
    final busy = _busyListingId == id;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLight
            ? const Color(0xFFF5F6F8)
            : Colors.black.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLight
              ? Colors.black.withValues(alpha: .06)
              : Colors.white.withValues(alpha: .09),
        ),
      ),
      child: Row(
        children: [
          Icon(
            verified ? Icons.verified_rounded : Icons.radio_button_unchecked,
            color: verified ? const Color(0xFF1687FF) : secondary,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title == null || title.isEmpty ? 'Listing $id' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (category != null && category.isNotEmpty)
                      category.toUpperCase(),
                    if (city != null && city.isNotEmpty) city,
                    verified
                        ? method == 'manual'
                            ? 'MANUAL VERIFIED'
                            : 'DOCUMENT VERIFIED'
                        : status.toUpperCase(),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: secondary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (busy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (verified)
            OutlinedButton(
              onPressed: () => _setBadge(row, false),
              child: const Text('Remove'),
            )
          else
            FilledButton.icon(
              onPressed: () => _setBadge(row, true),
              icon: const Icon(Icons.verified_rounded, size: 17),
              label: const Text('Blue badge'),
            ),
        ],
      ),
    );
  }
}
