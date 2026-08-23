import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/features/legal/data/repositories/contract_repository.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/contract_sign_screen.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/document_attachment.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `DocumentMessageCard.tsx` — in-thread document/contract bubble.
/// Rendered in place of a text bubble whenever a message carries
/// `message_type: document` + `attachments`.
class DocumentMessageCard extends ConsumerStatefulWidget {
  const DocumentMessageCard({
    super.key,
    required this.attachment,
    required this.isMyMessage,
  });

  final DocumentAttachment attachment;
  final bool isMyMessage;

  @override
  ConsumerState<DocumentMessageCard> createState() =>
      _DocumentMessageCardState();
}

class _DocumentMessageCardState extends ConsumerState<DocumentMessageCard> {
  bool _opening = false;

  Color get _tone {
    switch (widget.attachment.status) {
      case 'signed':
        return const Color(0xFF34D399);
      case 'sent':
        return const Color(0xFFFBBF24);
      case 'draft':
        return const Color(0xFF38BDF8);
      default:
        return Colors.white;
    }
  }

  Future<void> _handleOpen() async {
    if (_opening) return;
    AppHaptics.medium();
    if (!widget.attachment.isContract) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open the Documents vault to view this file'),
        ),
      );
      return;
    }
    setState(() => _opening = true);
    try {
      final contract = await ref
          .read(contractRepositoryProvider)
          .fetchById(widget.attachment.id);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ContractSignScreen(contract: contract),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open this document')));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = widget.isMyMessage;
    final isLight = MatteSurface.isLight(context);
    final att = widget.attachment;

    final bg = mine
        ? Colors.white.withAlpha(26)
        : (isLight ? Colors.white : Color(0xFF141418));
    final border = mine
        ? Colors.white.withAlpha(51)
        : (isLight ? Color(0xFFE2E2E6) : Colors.white.withAlpha(31));
    final textColor = mine ? Colors.white : MatteSurface.ink(context);

    return GestureDetector(
      onTap: _handleOpen,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color:
                          (att.isSigned
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFFFB7185))
                              .withAlpha(38),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.description_rounded,
                      color: att.isSigned
                          ? const Color(0xFF34D399)
                          : const Color(0xFFFB7185),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          att.title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: textColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: _tone.withAlpha(31),
                            border: Border.all(color: _tone.withAlpha(90)),
                          ),
                          child: Text(
                            contractStatusLabel(att.status).toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              color: _tone,
                              fontWeight: FontWeight.w900,
                              fontSize: 8,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_opening)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (att.isContract && att.status == 'sent') ...[
                    Icon(
                      Icons.edit_note_rounded,
                      size: 13,
                      color: mine ? Colors.white : const Color(0xFFFB7185),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      mine ? 'AWAITING SIGNATURE' : 'TAP TO SIGN',
                      style: GoogleFonts.plusJakartaSans(
                        color: mine ? Colors.white : const Color(0xFFFB7185),
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: 1,
                      ),
                    ),
                  ] else if (att.isContract && att.status == 'draft') ...[
                    Text(
                      'VIEW DOCUMENT',
                      style: GoogleFonts.plusJakartaSans(
                        color: mine ? Colors.white : textColor.withAlpha(110),
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: 1,
                      ),
                    ),
                  ] else if (att.status == 'uploaded') ...[
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 13,
                      color: mine ? Colors.white : textColor.withAlpha(140),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'OPEN FILE',
                      style: GoogleFonts.plusJakartaSans(
                        color: mine ? Colors.white : textColor.withAlpha(140),
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
