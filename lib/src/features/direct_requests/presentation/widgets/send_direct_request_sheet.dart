import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/direct_requests/data/direct_request_repository.dart';
import 'package:flutter_swipes/src/features/payments/data/token_repository.dart';
import 'package:flutter_swipes/src/features/payments/presentation/widgets/tokens_modal.dart';
import 'package:google_fonts/google_fonts.dart';

Future<bool?> showSendDirectRequestSheet(
  BuildContext context, {
  required String receiverId,
  String? listingId,
  String? listingTitle,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SendDirectRequestSheet(
      receiverId: receiverId,
      listingId: listingId,
      listingTitle: listingTitle,
    ),
  );
}

class _SendDirectRequestSheet extends StatefulWidget {
  const _SendDirectRequestSheet({
    required this.receiverId,
    this.listingId,
    this.listingTitle,
  });

  final String receiverId;
  final String? listingId;
  final String? listingTitle;

  @override
  State<_SendDirectRequestSheet> createState() => _SendDirectRequestSheetState();
}

class _SendDirectRequestSheetState extends State<_SendDirectRequestSheet> {
  final _controller = TextEditingController();
  final _tokenRepo = TokenRepository();
  final _requestRepo = DirectRequestRepository();
  DirectRequestTokenBalance? _balance;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    final value = await _tokenRepo.fetchDirectRequestBalance();
    if (mounted) setState(() => _balance = value);
  }

  Future<void> _buyTokens() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FractionallySizedBox(
        heightFactor: .88,
        child: TokensModal(),
      ),
    );
    await _loadBalance();
  }

  Future<void> _send() async {
    if (_busy) return;
    final balance = _balance;
    if (balance == null) return;
    if (balance.available < 1) {
      await _buyTokens();
      return;
    }

    setState(() => _busy = true);
    AppHaptics.medium();
    try {
      final result = await _requestRepo.send(
        receiverId: widget.receiverId,
        listingId: widget.listingId,
        message: _controller.text.trim(),
      );
      if (!mounted) return;
      await AppHaptics.success();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Direct Request sent. Your token is only spent if they accept.',
          ),
        ),
      );
      Navigator.of(context).pop(result.status == 'pending');
    } catch (error) {
      if (!mounted) return;
      final text = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text.contains('No Direct Request tokens')
            ? 'No Direct Requests available. Add tokens or choose Premium.'
            : 'Could not send Direct Request. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final balance = _balance;
    final available = balance?.available ?? 0;
    final reserved = balance?.reserved ?? 0;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: SwipessTokens.darkCanvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 30),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'DIRECT REQUEST',
                      style: SwipessTokens.displayItalic(fontSize: 25),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      balance == null ? '…' : '$available available',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.listingTitle?.trim().isNotEmpty == true
                    ? 'Want ${widget.listingTitle} now? Skip the normal match queue.'
                    : 'Skip the normal match queue when this matters now.',
                style: SwipessTokens.bodyClean(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                '1 token is reserved now and spent only if they accept. Declined, cancelled or expired requests return automatically.',
                style: SwipessTokens.bodyClean(color: Colors.white54, fontSize: 12),
              ),
              if (reserved > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '$reserved token${reserved == 1 ? '' : 's'} currently reserved for pending requests.',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFF59E0B),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              TextField(
                controller: _controller,
                maxLines: 4,
                maxLength: 1000,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Add dates, budget, availability or what you need…',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withAlpha(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: Colors.white.withAlpha(30)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: Colors.white.withAlpha(30)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _busy || balance == null ? null : _send,
                  icon: Icon(available > 0 ? Icons.bolt_rounded : Icons.add_rounded),
                  label: Text(
                    available > 0
                        ? (_busy ? 'SENDING…' : 'SEND — 1 TOKEN HELD')
                        : 'GET DIRECT REQUESTS',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white12,
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Interest is free. Matches chat for free. Direct Requests buy priority — never consent.',
                textAlign: TextAlign.center,
                style: SwipessTokens.bodyClean(color: Colors.white38, fontSize: 10.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
