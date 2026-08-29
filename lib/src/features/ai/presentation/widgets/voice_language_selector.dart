import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/ai/presentation/providers/voice_language_provider.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compact iOS-style explicit language selector.
class VoiceLanguageSelector extends ConsumerWidget {
  const VoiceLanguageSelector({super.key, this.isLight = false});

  final bool isLight;

  static const _iosBlue = Color(0xFF0A84FF);

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    AppHaptics.light();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final light = Theme.of(sheetContext).brightness == Brightness.light;
        final ink = light ? const Color(0xFF111114) : Colors.white;
        final surface = light
            ? const Color(0xFFF7F7FA)
            : const Color(0xFF17171C);

        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .72,
            ),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: light
                    ? Colors.black.withAlpha(14)
                    : Colors.white.withAlpha(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(light ? 24 : 120),
                  blurRadius: 38,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 9),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ink.withAlpha(45),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Voice language',
                              style: GoogleFonts.plusJakartaSans(
                                color: ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Speech and AI replies use this language.',
                              style: GoogleFonts.plusJakartaSans(
                                color: ink.withAlpha(130),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _iosBlue.withAlpha(light ? 18 : 34),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Manual',
                          style: GoogleFonts.plusJakartaSans(
                            color: _iosBlue,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final selected = ref.watch(voiceLanguageProvider);
                      return ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                        itemCount: VoiceLanguage.values.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          indent: 14,
                          endIndent: 14,
                          color: ink.withAlpha(16),
                        ),
                        itemBuilder: (context, index) {
                          final lang = VoiceLanguage.values[index];
                          final isSelected = lang == selected;
                          return Material(
                            color: isSelected
                                ? _iosBlue.withAlpha(light ? 14 : 28)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                AppHaptics.selection();
                                ref
                                    .read(voiceLanguageProvider.notifier)
                                    .setLanguage(lang);
                                Navigator.pop(sheetContext);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 11,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        lang.displayName,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: ink,
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: _iosBlue,
                                        size: 19,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(voiceLanguageProvider);
    final ink = isLight ? const Color(0xFF111114) : Colors.white;

    return Semantics(
      button: true,
      label: 'Voice language ${current.displayName}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showLanguagePicker(context, ref),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              height: 24,
              padding: const EdgeInsets.fromLTRB(7, 0, 5, 0),
              decoration: BoxDecoration(
                color: _iosBlue.withAlpha(isLight ? 14 : 26),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _iosBlue.withAlpha(isLight ? 70 : 95),
                  width: .8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    current.shortCode,
                    style: GoogleFonts.plusJakartaSans(
                      color: isLight ? const Color(0xFF0066CC) : _iosBlue,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .35,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: ink.withAlpha(145),
                    size: 13,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
