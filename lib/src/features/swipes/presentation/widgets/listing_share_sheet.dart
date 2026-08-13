import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showListingShareSheet(
  BuildContext context, {
  required Listing listing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => _ShareSheet(listing: listing),
  );
}

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({required this.listing});
  final Listing listing;

  String get _url => 'https://www.swipess.com/listing/${listing.id}';
  String get _text =>
      'Check out ${listing.title ?? 'this listing'} on Swipess — $_url';

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0x33FFFFFF))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.share_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                'SHARE',
                style: AppTheme.displayItalic.copyWith(fontSize: 22),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: listing.primaryImage != null
                        ? Image.network(listing.primaryImage!, fit: BoxFit.cover)
                        : const ColoredBox(color: Color(0xFF16161C)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    listing.title ?? 'Listing',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ShareBtn(
                  icon: Icons.link_rounded,
                  label: 'COPY',
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: _url));
                    HapticFeedback.selectionClick();
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied')),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ShareBtn(
                  icon: Icons.chat_rounded,
                  label: 'WHATSAPP',
                  onTap: () async {
                    final uri = Uri.parse(
                      'https://wa.me/?text=${Uri.encodeComponent(_text)}',
                    );
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ShareBtn(
                  icon: Icons.email_outlined,
                  label: 'EMAIL',
                  onTap: () async {
                    final uri = Uri(
                      scheme: 'mailto',
                      queryParameters: {
                        'subject': listing.title ?? 'Swipess listing',
                        'body': _text,
                      },
                    );
                    await launchUrl(uri);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareBtn extends StatelessWidget {
  const _ShareBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.brandPrimary),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
