import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_glass.dart';
import 'package:flutter_swipes/src/features/ai/domain/concierge_parse.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/ai_disclosure.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/intel_local_brain_card.dart';
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

/// Premium Intel message surface. Structured results render below the answer,
/// while raw tool payload stays hidden behind [ConciergeParse].
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
  Color get _muted =>
      widget.isLight ? const Color(0xFF73737D) : const Color(0xFFB8C0CE);

  bool _hasStructuredPayload(ConciergeParse? parsed) {
    if (parsed == null) return false;
    return parsed.localBrain.isNotEmpty ||
        parsed.listings.isNotEmpty ||
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
      if (parsed.localBrain.isNotEmpty) {
        return parsed.localBrain.length == 1
            ? 'I found a trusted local match for you.'
            : 'I found trusted local matches for you.';
      }
      if (parsed.profiles.isNotEmpty) return 'I found matching people for you.';
      if (parsed.listings.isNotEmpty)
        return 'I found matching listings for you.';
      if (parsed.events.isNotEmpty) return 'I found matching events for you.';
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
    final preferProfiles = parsed?.profiles.isNotEmpty == true;
    final width = MediaQuery.sizeOf(context).width;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width * .90),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  AppHaptics.selection();
                  setState(() => _showActions = !_showActions);
                },
                child: isUser
                    ? _UserBubble(text: text)
                    : _AssistantBubble(
                        text: text,
                        ink: _ink,
                        muted: _muted,
                        speaking: widget.speaking,
                        provider: widget.message.provider,
                        onSpeak: widget.onSpeak,
                      ),
              ),
              if (!isUser && parsed != null) ...[
                const SizedBox(height: 5),
                for (final entry in parsed.localBrain.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: IntelLocalBrainCard(data: entry),
                  ),
                if (!preferProfiles)
                  for (final listing in parsed.listings.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: IntelListingCard(data: listing),
                    ),
                for (final profile in parsed.profiles.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: IntelProfileCard(data: profile),
                  ),
              ],
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: _showActions
                    ? Padding(
                        key: const ValueKey('intel-actions'),
                        padding: const EdgeInsets.only(top: 2, bottom: 2),
                        child: SwipessGlassPanel(
                          radius: 16,
                          blur: 14,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 5,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ActionBtn(
                                icon: _copied
                                    ? Icons.check_rounded
                                    : Icons.copy_rounded,
                                color: _copied ? const Color(0xFF42C978) : _ink,
                                onTap: () {
                                  widget.onCopy();
                                  setState(() => _copied = true);
                                  Future<void>.delayed(
                                    const Duration(seconds: 2),
                                    () {
                                      if (mounted) {
                                        setState(() => _copied = false);
                                      }
                                    },
                                  );
                                },
                              ),
                              if (isUser && widget.onEdit != null)
                                _ActionBtn(
                                  icon: Icons.edit_outlined,
                                  color: _ink,
                                  onTap: widget.onEdit!,
                                ),
                              if (widget.onResend != null)
                                _ActionBtn(
                                  icon: Icons.refresh_rounded,
                                  color: _ink,
                                  onTap: widget.onResend!,
                                ),
                              if (!isUser && widget.onTranslate != null)
                                _ActionBtn(
                                  icon: Icons.translate_rounded,
                                  color: _ink,
                                  onTap: widget.onTranslate!,
                                ),
                              _ActionBtn(
                                icon: Icons.delete_outline_rounded,
                                color: const Color(0xFFF87171),
                                onTap: widget.onDelete,
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF4D78), Color(0xFF9B5DE5)],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(8),
        ),
        border: Border.all(color: const Color(0x66FF9A68)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D78).withAlpha(46),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 14.5,
          height: 1.42,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({
    required this.text,
    required this.ink,
    required this.muted,
    required this.speaking,
    required this.provider,
    required this.onSpeak,
  });

  final String text;
  final Color ink;
  final Color muted;
  final bool speaking;
  final String provider;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    return SwipessGlassPanel(
      radius: 25,
      blur: 22,
      strong: true,
      padding: const EdgeInsets.fromLTRB(13, 11, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF5C8A), Color(0xFFFF9A68)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SWIPESS INTEL',
                style: GoogleFonts.plusJakartaSans(
                  color: ink,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.25,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onSpeak,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: speaking
                        ? SwipessGlassLook.ai.withAlpha(25)
                        : SwipessGlassLook.field(context),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: speaking
                          ? SwipessGlassLook.aiSoft.withAlpha(90)
                          : SwipessGlassLook.hairline(context),
                    ),
                  ),
                  child: Icon(
                    speaking
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    size: 15,
                    color: speaking ? SwipessGlassLook.aiSoft : muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 14.5,
              height: 1.43,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 10,
                color: SwipessGlassLook.aiSoft,
              ),
              const SizedBox(width: 4),
              Text(
                'POWERED BY ${aiProviderBubbleLabel(provider).toUpperCase()}',
                style: GoogleFonts.plusJakartaSans(
                  color: muted,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AppHaptics.selection();
          onTap();
        },
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}
