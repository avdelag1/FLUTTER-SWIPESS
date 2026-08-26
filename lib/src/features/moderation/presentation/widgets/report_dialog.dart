import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/theme/nexus_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cap `ReportDialog` — Trust & Safety for listings or profiles.
enum ReportCategory { listing, userProfile, content }

Future<void> showReportDialog(
  BuildContext context, {
  required ReportCategory category,
  String? reportedUserId,
  String? reportedListingId,
  String? reportedUserName,
  String? reportedListingTitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => ReportDialog(
      category: category,
      reportedUserId: reportedUserId,
      reportedListingId: reportedListingId,
      reportedUserName: reportedUserName,
      reportedListingTitle: reportedListingTitle,
    ),
  );
}

class ReportDialog extends StatefulWidget {
  const ReportDialog({
    super.key,
    required this.category,
    this.reportedUserId,
    this.reportedListingId,
    this.reportedUserName,
    this.reportedListingTitle,
  });

  final ReportCategory category;
  final String? reportedUserId;
  final String? reportedListingId;
  final String? reportedUserName;
  final String? reportedListingTitle;

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String? _type;
  final _details = TextEditingController();
  bool _busy = false;

  List<(String, String)> get _types {
    switch (widget.category) {
      case ReportCategory.listing:
        return const [
          ('fake_listing', 'Fake listing'),
          ('not_real_owner', 'Not the real owner'),
          ('misleading_info', 'Misleading info'),
          ('inappropriate_content', 'Inappropriate content'),
          ('scam', 'Scam'),
          ('spam', 'Spam'),
          ('other', 'Other'),
        ];
      case ReportCategory.userProfile:
        return const [
          ('fake_profile', 'Fake profile'),
          ('not_real_owner', 'Not the real owner'),
          ('broker_posing_as_client', 'Broker posing as client'),
          ('broker_posing_as_owner', 'Broker posing as owner'),
          ('inappropriate_content', 'Inappropriate content'),
          ('harassment', 'Harassment'),
          ('scam', 'Scam'),
          ('spam', 'Spam'),
          ('other', 'Other'),
        ];
      case ReportCategory.content:
        return const [
          ('inappropriate_content', 'Inappropriate content'),
          ('harassment', 'Harassment'),
          ('spam', 'Spam'),
          ('other', 'Other'),
        ];
    }
  }

  String get _title {
    switch (widget.category) {
      case ReportCategory.listing:
        return 'Report Listing';
      case ReportCategory.userProfile:
        return 'Report User';
      case ReportCategory.content:
        return 'Report Content';
    }
  }

  String get _categoryKey {
    switch (widget.category) {
      case ReportCategory.listing:
        return 'listing';
      case ReportCategory.userProfile:
        return 'user_profile';
      case ReportCategory.content:
        return 'content';
    }
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_type == null) return;
    setState(() => _busy = true);
    AppHaptics.medium();
    try {
      final user = Supabase.instance.client.auth.currentUser;
      await Supabase.instance.client.from('reports').insert({
        'reporter_id': user?.id,
        'reported_listing_id': widget.reportedListingId,
        'reported_user_id': widget.reportedUserId,
        'report_type': _type,
        'report_category': _categoryKey,
        'description': _details.text.trim(),
        'status': 'open',
      });
    } catch (_) {}
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted — thank you')),
    );
  }

  Future<void> _blockUser() async {
    final id = widget.reportedUserId;
    if (id == null || id.isEmpty) return;
    AppHaptics.heavy();
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      await Supabase.instance.client.from('blocked_users').insert({
        'blocker_id': user.id,
        'blocked_id': id,
      });
    } catch (_) {
      // Table may not exist in every env — still close.
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Blocked ${widget.reportedUserName ?? 'user'}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final hairline = MatteSurface.hairline(context);
    final isLight = MatteSurface.isLight(context);
    final bottom =
        MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.paddingOf(context).bottom;
    final subject = widget.reportedUserName ?? widget.reportedListingTitle;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: BoxDecoration(
          color: isLight ? Colors.white : const Color(0xFF121214),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: hairline)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: NexusTheme.rose.withAlpha(28),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: NexusTheme.rose.withAlpha(80)),
                    ),
                    child: const Icon(
                      Icons.flag_rounded,
                      color: NexusTheme.rose,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          style: GoogleFonts.plusJakartaSans(
                            color: ink,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          'TRUST & SAFETY',
                          style: GoogleFonts.plusJakartaSans(
                            color: muted,
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: MatteSurface.cardFill(context),
                      side: BorderSide(color: hairline),
                    ),
                    icon: Icon(Icons.close_rounded, color: muted),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                shrinkWrap: true,
                children: [
                  Text(
                    'Help us keep Swipess safe. Your report is confidential.',
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  if (subject != null && subject.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isLight
                            ? const Color(0xFFF8FAFC)
                            : const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: hairline),
                      ),
                      child: Text(
                        subject,
                        style: GoogleFonts.plusJakartaSans(
                          color: ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  for (final t in _types) ...[
                    _TypeRow(
                      label: t.$2,
                      selected: _type == t.$1,
                      onTap: () => setState(() => _type = t.$1),
                    ),
                    SizedBox(height: 8),
                  ],
                  SizedBox(height: 8),
                  TextField(
                    controller: _details,
                    maxLines: 3,
                    style: TextStyle(color: ink),
                    decoration: InputDecoration(
                      hintText: 'Optional details…',
                      hintStyle: TextStyle(color: muted),
                      filled: true,
                      fillColor: MatteSurface.well(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _type == null || _busy ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NexusTheme.rose,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: NexusTheme.rose.withAlpha(80),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _busy ? 'SENDING…' : 'SUBMIT REPORT',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  if (widget.category == ReportCategory.userProfile &&
                      widget.reportedUserId != null) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _busy ? null : _blockUser,
                      child: Text(
                        'BLOCK ${widget.reportedUserName?.toUpperCase() ?? 'ENTITY'}',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFEF4444),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'False reports may affect your account standing.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: muted.withAlpha(140),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final hairline = MatteSurface.hairline(context);
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? NexusTheme.rose.withAlpha(28) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? NexusTheme.rose.withAlpha(120) : hairline,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? NexusTheme.rose : ink.withAlpha(120),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
