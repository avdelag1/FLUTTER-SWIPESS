import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/ai/domain/concierge_parse.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/ai_disclosure.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/intel_result_cards.dart';
import 'package:google_fonts/google_fonts.dart';

class IntelChatBubble {
  const IntelChatBubble({
    required this.id,
    required this.role,
    required this.content,
    this.provider = 'groq',
  });

  final String id;
  final String role;
  final String content;
  final String provider;

  bool get isUser => role == 'user';

  IntelChatBubble copyWith({String? content, String? provider}) {
    return IntelChatBubble(
      id: id,
      role: role,
      content: content ?? this.content,
      provider: provider ?? this.provider,
    );
  }
}

/// Cap `MessageBubble` — copy / edit / resend / translate / delete / speak.
class IntelMessageBubble extends StatefulWidget {
  const IntelMessageBubble({
    super.key,
    required this.message,
    required this.isLight,
    required this.onCopy,
    required this.onDelete,
    required this.onSpeak,
    this.onEdit,
    this.onResend,
    this.onTranslate,
    this.speaking = false,
  });

  final IntelChatBubble message;
  final bool isLight;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final VoidCallback onSpeak;
  final VoidCallback? onEdit;
  final VoidCallback? onResend;
  final VoidCallback? onTranslate;
  final bool speaking;

  @override
  State<IntelMessageBubble> createState() => _IntelMessageBubbleState();
}

class _IntelMessageBubbleState extends State<IntelMessageBubble> {
  bool _showActions = false;
  bool _copied = false;

  Color get _ink => widget.isLight ? const Color(0xFF0A0A0D) : Colors.white;

  bool _hasStructuredPayload(ConciergeParse? parsed) {
    if (parsed == null) return false;
    return parsed.listings.isNotEmpty ||
        parsed.profiles.isNotEmpty ||
        parsed.events.isNotEmpty ||
        parsed.navPaths.isNotEmpty ||
        parsed.filterAction != null ||
        parsed.passportAction != null ||
        parsed.passportCity != null;
  }

  String _assistantDisplayText(String raw, ConciergeParse? parsed) {
    final clean = parsed?.cleanContent.trim() ?? '';
    if (clean.isNotEmpty) return clean;

    if (parsed != null && _hasStructuredPayload(parsed)) {
      if (parsed.listings.isNotEmpty) {
        return 'I found matching listings for you.';
      }
      if (parsed.profiles.isNotEmpty) {
        return 'I found matching people for you.';
      }
      if (parsed.events.isNotEmpty) {
        return 'I found matching events for you.';
      }
      return 'Done — I prepared that action for you.';
    }

    final trimmed = raw.trim();
    final looksTechnical =
        trimmed.startsWith('[') ||
        trimmed.startsWith('{') ||
        trimmed.startsWith('data:') ||
        RegExp(
          r'(font-family|rgba\(|<html|<!doctype|class=|style=|choices|delta|content)',
          caseSensitive: false,
        ).hasMatch(trimmed);

    if (looksTechnical) {
      return 'I found results, but the answer came back without a clean sentence.';
    }

    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
    final parsed = isUser ? null : ConciergeParse.of(widget.message.content);
    final text = isUser
        ? widget.message.content
        : _assistantDisplayText(widget.message.content, parsed);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.88,
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                AppHaptics.selection();
                setState(() => _showActions = !_showActions);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? AppTheme.brandPrimary
                      : (widget.isLight
                            ? Colors.white
                            : Colors.white.withAlpha(12)),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(22),
                    topRight: const Radius.circular(22),
                    bottomLeft: Radius.circular(isUser ? 22 : 8),
                    bottomRight: Radius.circular(isUser ? 8 : 22),
                  ),
                  border: Border.all(
                    color: isUser
                        ? AppTheme.brandPrimary
                        : _ink.withAlpha(widget.isLight ? 220 : 200),
                    width: 1.4,
                  ),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: isUser ? 0 : 18),
                      child: Text(
                        text,
                        style: GoogleFonts.plusJakartaSans(
                          color: isUser ? Colors.white : _ink,
                          fontSize: 14.5,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (!isUser)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: widget.onSpeak,
                          child: Icon(
                            widget.speaking
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            size: 14,
                            color: widget.speaking
                                ? AppTheme.brandPrimary
                                : _ink.withAlpha(90),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 10,
                      color: AppTheme.brandPrimary.withAlpha(180),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'POWERED BY ${aiProviderBubbleLabel(widget.message.provider).toUpperCase()}',
                      style: GoogleFonts.plusJakartaSans(
                        color: _ink.withAlpha(100),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            if (!isUser && parsed != null) ...[
              for (final listing in parsed.listings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: IntelListingCard(data: listing),
                ),
              for (final profile in parsed.profiles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: IntelProfileCard(data: profile),
                ),
            ],
            if (_showActions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ActionBtn(
                      icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
                      color: _copied ? const Color(0xFF4ADE80) : _ink,
                      isLight: widget.isLight,
                      onTap: () {
                        widget.onCopy();
                        setState(() => _copied = true);
                        Future<void>.delayed(const Duration(seconds: 2), () {
                          if (mounted) setState(() => _copied = false);
                        });
                      },
                    ),
                    if (isUser && widget.onEdit != null)
                      _ActionBtn(
                        icon: Icons.edit_outlined,
                        color: _ink,
                        isLight: widget.isLight,
                        onTap: widget.onEdit!,
                      ),
                    if (widget.onResend != null)
                      _ActionBtn(
                        icon: Icons.refresh_rounded,
                        color: _ink,
                        isLight: widget.isLight,
                        onTap: widget.onResend!,
                      ),
                    if (!isUser && widget.onTranslate != null)
                      _ActionBtn(
                        icon: Icons.translate_rounded,
                        color: _ink,
                        isLight: widget.isLight,
                        onTap: widget.onTranslate!,
                      ),
                    _ActionBtn(
                      icon: Icons.delete_outline_rounded,
                      color: const Color(0xFFF87171),
                      isLight: widget.isLight,
                      onTap: widget.onDelete,
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

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.isLight,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final bool isLight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          AppHaptics.selection();
          onTap();
        },
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isLight
                ? const Color(0xFFF1F1F4)
                : Colors.white.withAlpha(28),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}
