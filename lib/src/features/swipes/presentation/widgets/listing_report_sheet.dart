import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> showListingReportSheet(
  BuildContext context, {
  required Listing listing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReportSheet(listing: listing),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.listing});
  final Listing listing;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  String? _type;
  final _details = TextEditingController();
  bool _busy = false;

  static const _types = [
    ('spam', 'Spam or scam'),
    ('misleading', 'Misleading info'),
    ('inappropriate', 'Inappropriate content'),
    ('unavailable', 'No longer available'),
    ('other', 'Other'),
  ];

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_type == null || _details.text.trim().isEmpty) return;
    setState(() => _busy = true);
    AppHaptics.medium();

    final user = ref.read(currentUserProvider);
    await ref
        .read(swipeRepositoryProvider)
        .reportListing(
          reporterId: user?.id,
          listingId: widget.listing.id,
          ownerId: widget.listing.ownerId ?? '',
          type: _type!,
          details: _details.text.trim(),
        );

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted — thank you')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom =
        MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0x33FFFFFF))),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'REPORT LISTING',
                style: AppTheme.displayItalic.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 6),
              Text(
                widget.listing.title ?? 'Listing',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              for (final t in _types)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _type = t.$1),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: _type == t.$1
                            ? AppTheme.brandPrimary.withAlpha(40)
                            : Colors.white.withAlpha(12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _type == t.$1
                              ? AppTheme.brandPrimary
                              : Colors.white24,
                        ),
                      ),
                      child: Text(
                        t.$2,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _details,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Describe the issue…',
                  hintStyle: const TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.white, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Colors.white30,
                      width: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _busy || _type == null || _details.text.trim().isEmpty
                      ? null
                      : _submit,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white12,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _busy ? 'Submitting…' : 'Submit report',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
