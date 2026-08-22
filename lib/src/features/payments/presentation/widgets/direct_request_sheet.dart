import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/payments/data/direct_request_repository.dart';
import 'package:flutter_swipes/src/features/payments/presentation/widgets/tokens_modal.dart';
import 'package:google_fonts/google_fonts.dart';

Future<bool?> showDirectRequestSheet(
  BuildContext context, {
  required String receiverId,
  String? listingId,
  required String listingTitle,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DirectRequestSheet(
      receiverId: receiverId,
      listingId: listingId,
      listingTitle: listingTitle,
    ),
  );
}

class _DirectRequestSheet extends ConsumerStatefulWidget {
  const _DirectRequestSheet({
    required this.receiverId,
    this.listingId,
    required this.listingTitle,
  });

  final String receiverId;
  final String? listingId;
  final String listingTitle;

  @override
  ConsumerState<_DirectRequestSheet> createState() => _DirectRequestSheetState();
}

class _DirectRequestSheetState extends ConsumerState<_DirectRequestSheet> {
  final _message = TextEditingController();
  final _budget = TextEditingController();
  final _location = TextEditingController();
  final _partySize = TextEditingController();
  DateTime? _startsAt;
  DateTime? _endsAt;
  String _urgency = 'flexible';
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    _budget.dispose();
    _location.dispose();
    _partySize.dispose();
    super.dispose();
  }

  Future<void> _openTokens() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FractionallySizedBox(
        heightFactor: .9,
        child: TokensModal(),
      ),
    );
    ref.invalidate(directRequestBalanceProvider);
  }

  Future<void> _pickDate({required bool end}) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: end ? (_endsAt ?? _startsAt ?? now) : (_startsAt ?? now),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (end) {
        _endsAt = selected;
        if (_startsAt != null && _endsAt!.isBefore(_startsAt!)) {
          _startsAt = selected;
        }
      } else {
        _startsAt = selected;
        if (_endsAt != null && _endsAt!.isBefore(selected)) _endsAt = selected;
      }
    });
  }

  DirectRequestContext _context() => DirectRequestContext(
        startsAt: _startsAt,
        endsAt: _endsAt,
        budgetMax: double.tryParse(_budget.text.trim()),
        location: _location.text.trim(),
        partySize: int.tryParse(_partySize.text.trim()),
        urgency: _urgency,
      );

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    AppHaptics.medium();
    try {
      await ref.read(directRequestRepositoryProvider).createStructured(
            receiverId: widget.receiverId,
            listingId: widget.listingId,
            message: _message.text,
            context: _context(),
          );
      ref.invalidate(directRequestBalanceProvider);
      ref.invalidate(outgoingDirectRequestsProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚡ Direct Request sent. Your token is reserved and is only spent if they accept.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final text = error.toString().toLowerCase();
      setState(() {
        _sending = false;
        _error = text.contains('no direct request tokens')
            ? 'You need an available Direct Request token.'
            : 'Could not send the Direct Request. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = MatteSurface.isLight(context);
    final ink = MatteSurface.ink(context);
    final balance = ref.watch(directRequestBalanceProvider);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
        decoration: BoxDecoration(
          color: MatteSurface.canvas(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(top: BorderSide(color: ink.withAlpha(35))),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ink.withAlpha(50),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '⚡ DIRECT REQUEST',
                  style: GoogleFonts.plusJakartaSans(
                    color: ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Want ${widget.listingTitle} without waiting for a match?',
                  style: GoogleFonts.plusJakartaSans(
                    color: MatteSurface.muted(context),
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: ink.withAlpha(isLight ? 8 : 18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: ink.withAlpha(28)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _rule('❤️ Interest is always free'),
                      _rule('🤝 A mutual match opens chat free'),
                      _rule('⚡ 1 token is reserved for this priority request'),
                      _rule('↩️ Declined or unanswered? The token returns'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'MAKE IT EASY TO SAY YES',
                  style: GoogleFonts.plusJakartaSans(
                    color: MatteSurface.muted(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: _detailButton(
                        icon: Icons.calendar_today_rounded,
                        label: _startsAt == null ? 'START' : _shortDate(_startsAt!),
                        onTap: () => _pickDate(end: false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _detailButton(
                        icon: Icons.event_available_rounded,
                        label: _endsAt == null ? 'END' : _shortDate(_endsAt!),
                        onTap: () => _pickDate(end: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        controller: _budget,
                        hint: 'Max budget',
                        icon: Icons.payments_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _field(
                        controller: _partySize,
                        hint: 'People',
                        icon: Icons.group_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _field(
                  controller: _location,
                  hint: 'Location / neighborhood',
                  icon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final entry in const {
                      'now': 'NOW',
                      'today': 'TODAY',
                      'this_week': 'THIS WEEK',
                      'flexible': 'FLEXIBLE',
                    }.entries)
                      ChoiceChip(
                        selected: _urgency == entry.key,
                        onSelected: (_) => setState(() => _urgency = entry.key),
                        showCheckmark: false,
                        shape: const StadiumBorder(),
                        side: BorderSide(color: ink.withAlpha(28)),
                        backgroundColor: ink.withAlpha(isLight ? 6 : 14),
                        selectedColor: AppTheme.brandPrimary,
                        label: Text(entry.value),
                        labelStyle: GoogleFonts.plusJakartaSans(
                          color: _urgency == entry.key ? Colors.white : ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _message,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 1000,
                  style: TextStyle(color: ink),
                  decoration: InputDecoration(
                    hintText: 'Anything else they should know?',
                    hintStyle: TextStyle(color: MatteSurface.muted(context)),
                    filled: true,
                    fillColor: ink.withAlpha(isLight ? 7 : 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: ink.withAlpha(28)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: ink.withAlpha(28)),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _error!,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                balance.when(
                  loading: () => const LinearProgressIndicator(minHeight: 2),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (b) => Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${b.available} available · ${b.reserved} reserved',
                          style: GoogleFonts.plusJakartaSans(
                            color: MatteSurface.muted(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (b.available == 0)
                        TextButton(onPressed: _openTokens, child: const Text('Get tokens')),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _sending
                        ? null
                        : balance.maybeWhen(
                            data: (b) => b.available > 0 ? _send : null,
                            orElse: () => null,
                          ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.brandPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('SEND DIRECT REQUEST · 1 TOKEN'),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Wait for a free match'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    final ink = MatteSurface.ink(context);
    final isLight = MatteSurface.isLight(context);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.plusJakartaSans(
        color: ink,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: MatteSurface.muted(context), size: 17),
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(color: MatteSurface.muted(context), fontSize: 11),
        filled: true,
        fillColor: ink.withAlpha(isLight ? 7 : 15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: ink.withAlpha(28)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: ink.withAlpha(28)),
        ),
      ),
    );
  }

  Widget _detailButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final ink = MatteSurface.ink(context);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: BorderSide(color: ink.withAlpha(28)),
        shape: const StadiumBorder(),
        minimumSize: const Size.fromHeight(46),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _rule(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            color: MatteSurface.ink(context),
            fontSize: 12.5,
            height: 1.3,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  static String _shortDate(DateTime date) => '${date.month}/${date.day}/${date.year}';
}
