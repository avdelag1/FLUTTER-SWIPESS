import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_popup.dart';
import 'package:flutter_swipes/src/features/payments/data/direct_request_repository.dart';
import 'package:google_fonts/google_fonts.dart';

class DirectRequestReviewScreen extends ConsumerStatefulWidget {
  const DirectRequestReviewScreen({
    super.key,
    required this.requestId,
    this.senderName = 'Member',
  });

  final String requestId;
  final String senderName;

  @override
  ConsumerState<DirectRequestReviewScreen> createState() =>
      _DirectRequestReviewScreenState();
}

class _DirectRequestReviewScreenState
    extends ConsumerState<DirectRequestReviewScreen> {
  bool _busy = false;

  Future<void> _respond(DirectRequest request, bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);
    AppHaptics.medium();
    try {
      final result = await ref.read(directRequestRepositoryProvider).respond(
            requestId: request.id,
            accept: accept,
          );
      ref.invalidate(incomingDirectRequestsProvider);
      ref.invalidate(directRequestBalanceProvider);
      if (!mounted) return;
      if (!accept) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request declined. Their token was returned.'),
          ),
        );
        Navigator.of(context).pop();
        return;
      }
      await AppHaptics.success();
      final conversationId = result.conversationId;
      if (conversationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request accepted. Chat is now open.')),
        );
        Navigator.of(context).pop();
        return;
      }
      await showChatPopup(
        context,
        isNewConversation: true,
        conversation: ChatConversation(
          id: conversationId,
          otherUserId: request.senderId,
          name: widget.senderName,
          lastMessage: request.message,
          timestamp: 'now',
          listingTag: request.listingId,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update this Direct Request. Please retry.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    return Scaffold(
      backgroundColor: MatteSurface.canvas(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ink,
        title: const Text('Direct Request'),
      ),
      body: FutureBuilder<List<DirectRequest>>(
        future: ref
            .read(directRequestRepositoryProvider)
            .fetchIncoming(requestId: widget.requestId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const <DirectRequest>[];
          if (items.isEmpty) {
            return Center(
              child: Text(
                'This Direct Request is no longer available.',
                style: TextStyle(color: MatteSurface.muted(context)),
              ),
            );
          }
          final request = items.first;
          final pending = request.isPending;
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 40),
            children: [
              Text(
                '⚡ PRIORITY REQUEST',
                style: GoogleFonts.plusJakartaSans(
                  color: ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'They used a Direct Request because they want an answer sooner.',
                style: GoogleFonts.plusJakartaSans(
                  color: MatteSurface.muted(context),
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: ink.withAlpha(35)),
                  color: ink.withAlpha(10),
                ),
                child: Text(
                  request.message.trim().isEmpty
                      ? 'No extra message — they are interested in connecting.'
                      : request.message,
                  style: GoogleFonts.plusJakartaSans(
                    color: ink,
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!request.context.isEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'REQUEST DETAILS',
                  style: GoogleFonts.plusJakartaSans(
                    color: MatteSurface.muted(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: _contextChips(request.context),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                pending
                    ? 'Accept → their token is spent and chat opens.\nDecline → their token returns automatically.'
                    : 'Status: ${request.status.toUpperCase()}',
                style: GoogleFonts.plusJakartaSans(
                  color: MatteSurface.muted(context),
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (pending) ...[
                const SizedBox(height: 28),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _busy ? null : () => _respond(request, true),
                    child: const Text('ACCEPT & OPEN CHAT'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _respond(request, false),
                    child: const Text('DECLINE'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'A Direct Request never removes your choice. Accept only if you want to talk.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: MatteSurface.faint(context),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  List<Widget> _contextChips(DirectRequestContext details) {
    final items = <(IconData, String)>[];
    if (details.startsAt != null) {
      final start = _date(details.startsAt!);
      final end = details.endsAt == null ? null : _date(details.endsAt!);
      items.add((Icons.calendar_today_rounded, end == null ? start : '$start – $end'));
    }
    if (details.budgetMax != null) {
      items.add((
        Icons.payments_outlined,
        'Up to ${details.currency} ${details.budgetMax!.toStringAsFixed(0)}',
      ));
    }
    if (details.location?.trim().isNotEmpty == true) {
      items.add((Icons.location_on_outlined, details.location!.trim()));
    }
    if (details.partySize != null) {
      items.add((Icons.group_outlined, '${details.partySize} people'));
    }
    if (details.urgency != 'flexible') {
      items.add((Icons.bolt_rounded, details.urgency.replaceAll('_', ' ').toUpperCase()));
    }
    return [for (final item in items) _chip(item.$1, item.$2)];
  }

  Widget _chip(IconData icon, String text) {
    final ink = MatteSurface.ink(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: ink.withAlpha(9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ink.withAlpha(28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: ink, size: 13),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  static String _date(DateTime value) => '${value.month}/${value.day}/${value.year}';
}
