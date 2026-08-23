import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `SupportDialog` — Neural Support / Customer Sync ticket sheet.
Future<void> showSupportDialog(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _SupportDialogSheet(),
  );
}

class _SupportDialogSheet extends StatefulWidget {
  const _SupportDialogSheet();

  @override
  State<_SupportDialogSheet> createState() => _SupportDialogSheetState();
}

class _SupportDialogSheetState extends State<_SupportDialogSheet> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String _category = 'general';
  String _priority = 'medium';
  bool _sending = false;
  bool _sent = false;

  static const _categories = [
    ('general', 'General', Icons.info_outline_rounded),
    ('technical', 'Technical', Icons.bug_report_rounded),
    ('billing', 'Billing', Icons.attach_money_rounded),
    ('account', 'Account', Icons.person_outline_rounded),
    ('property', 'Property', Icons.home_outlined),
    ('matching', 'Matching', Icons.chat_bubble_outline_rounded),
  ];

  static const _priorities = [
    ('low', 'Low'),
    ('medium', 'Medium'),
    ('high', 'High'),
    ('urgent', 'Urgent'),
  ];

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_subject.text.trim().isEmpty || _message.text.trim().isEmpty) return;
    AppHaptics.medium();
    setState(() => _sending = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    // Bases: insert into support_tickets via repository.
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = true;
      _subject.clear();
      _message.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0D).withAlpha(240),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(24, 18, 24, bottom + 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFA855F7),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'NEURAL SUPPORT',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFA855F7),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'CUSTOMER SYNC',
                      style: AppTheme.displayItalic.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Access help for account protocols, liquidations, or neural glitches.',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (_sent)
            Container(
              padding: const EdgeInsets.all(18),
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withAlpha(28),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF10B981).withAlpha(80),
                ),
              ),
              child: Text(
                'Support ticket created. Our team will sync back soon.',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Text(
            'NEW PROTOCOL',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _categories)
                ChoiceChip(
                  label: Text(c.$2),
                  selected: _category == c.$1,
                  onSelected: (_) => setState(() => _category = c.$1),
                  selectedColor: AppTheme.brandPrimary,
                  labelStyle: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                  avatar: Icon(c.$3, size: 14, color: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final p in _priorities)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Center(child: Text(p.$2)),
                      selected: _priority == p.$1,
                      onSelected: (_) => setState(() => _priority = p.$1),
                      selectedColor: const Color(0xFFF59E0B),
                      labelStyle: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          GlassTextField(controller: _subject, hint: 'Subject'),
          const SizedBox(height: 10),
          GlassTextField(
            controller: _message,
            hint: 'Describe the issue…',
            maxLines: 5,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _submit,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _sending ? 'SENDING…' : 'OPEN TICKET',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
