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
  ConsumerState<_DirectRequestSheet> createState() =>
      _DirectRequestSheetState();
}

class _DirectRequestSheetState extends ConsumerState<_DirectRequestSheet> {
  final _message = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _openTokens() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          const FractionallySizedBox(heightFactor: .9, child: TokensModal()),
    );
    ref.invalidate(directRequestBalanceProvider);
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    AppHaptics.medium();
    try {
      await ref
          .read(directRequestRepositoryProvider)
          .create(
            receiverId: widget.receiverId,
            listingId: widget.listingId,
            message: _message.text,
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
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
        decoration: BoxDecoration(
          color: MatteSurface.canvas(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(top: BorderSide(color: ink.withAlpha(35))),
        ),
        child: SafeArea(
          top: false,
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
              const SizedBox(height: 18),
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
                    _rule('🤝 If they match you, chat opens free'),
                    _rule('⚡ 1 token reserves this priority request'),
                    _rule('↩️ Declined or unanswered? Token returns'),
                    _rule('✓ Accepted? Token is spent and chat opens'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _message,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                style: TextStyle(color: ink),
                decoration: InputDecoration(
                  hintText: 'Add useful details — dates, budget, timing…',
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
              const SizedBox(height: 12),
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
                      TextButton(
                        onPressed: _openTokens,
                        child: const Text('Get tokens'),
                      ),
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
}
