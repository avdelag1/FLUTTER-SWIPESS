import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/features/payments/data/direct_request_repository.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> showDirectRequestComposer(
  BuildContext context, {
  required Listing listing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DirectRequestComposer(listing: listing),
  );
}

class _DirectRequestComposer extends ConsumerStatefulWidget {
  const _DirectRequestComposer({required this.listing});

  final Listing listing;

  @override
  ConsumerState<_DirectRequestComposer> createState() =>
      _DirectRequestComposerState();
}

class _DirectRequestComposerState
    extends ConsumerState<_DirectRequestComposer> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final ownerId = widget.listing.ownerId;
    if (ownerId == null || ownerId.isEmpty || _sending) return;

    final balance = await ref.read(directRequestRepositoryProvider).fetchBalance();
    if (!mounted) return;
    if (balance.available < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No Direct Requests available. Get tokens or Premium to skip the wait.',
          ),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await ref.read(directRequestRepositoryProvider).send(
            receiverId: ownerId,
            listingId: widget.listing.id,
            message: _controller.text.trim(),
          );
      ref.invalidate(directRequestBalanceProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Direct Request sent. Your token is only spent if they accept.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send Direct Request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final isLight = MatteSurface.isLight(context);
    final ink = isLight ? Colors.black : Colors.white;
    final muted = isLight ? Colors.black54 : Colors.white60;
    final balance = ref.watch(directRequestBalanceProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        decoration: BoxDecoration(
          color: MatteSurface.canvas(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(top: BorderSide(color: ink.withAlpha(28))),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ink.withAlpha(55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.brandPrimary.withAlpha(25),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: AppTheme.brandPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DIRECT REQUEST',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.brandPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.3,
                          ),
                        ),
                        Text(
                          'Skip the wait',
                          style: GoogleFonts.plusJakartaSans(
                            color: ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  balance.when(
                    data: (b) => Text(
                      '${b.available} ⚡',
                      style: GoogleFonts.plusJakartaSans(
                        color: ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    loading: () => const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Interested is always free. Use 1 Direct Request when you want your request seen now.',
                style: GoogleFonts.plusJakartaSans(
                  color: muted,
                  fontSize: 13.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppTheme.brandPrimary.withAlpha(16),
                  border: Border.all(color: AppTheme.brandPrimary.withAlpha(55)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.replay_rounded,
                      size: 18,
                      color: AppTheme.brandPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Only spent if they accept. Declined, cancelled or expired = returned.',
                        style: GoogleFonts.plusJakartaSans(
                          color: ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                maxLength: 1000,
                minLines: 2,
                maxLines: 5,
                style: TextStyle(color: ink),
                decoration: InputDecoration(
                  hintText: 'Add dates, budget or what you need…',
                  hintStyle: TextStyle(color: muted),
                  filled: false,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.bolt_rounded),
                  label: Text(
                    _sending ? 'SENDING…' : 'SEND DIRECT REQUEST · 1 ⚡',
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
