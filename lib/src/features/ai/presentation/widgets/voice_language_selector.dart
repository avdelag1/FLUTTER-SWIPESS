import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/ai/presentation/providers/voice_language_provider.dart';

/// A sleek, Capacitor-matching language selector glass pill.
class VoiceLanguageSelector extends ConsumerWidget {
  const VoiceLanguageSelector({super.key, this.isLight = false});

  final bool isLight;

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    AppHaptics.light();
    final currentLang = ref.read(voiceLanguageProvider);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isLight ? Colors.white : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(24),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isLight ? Colors.black26 : Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Language',
                  style: TextStyle(
                    color: isLight ? Colors.black : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: VoiceLanguage.values.length,
                    itemBuilder: (context, index) {
                      final lang = VoiceLanguage.values[index];
                      final isSelected = lang == currentLang;
                      return ListTile(
                        onTap: () {
                          AppHaptics.light();
                          ref.read(voiceLanguageProvider.notifier).setLanguage(lang);
                          Navigator.pop(context);
                        },
                        title: Text(
                          lang.displayName,
                          style: TextStyle(
                            color: isLight ? Colors.black : Colors.white,
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_rounded, color: Color(0xFFFF4D00))
                            : null,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(voiceLanguageProvider);

    return GestureDetector(
      onTap: () => _showLanguagePicker(context, ref),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.black.withOpacity(0.05)
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isLight
                    ? Colors.black.withOpacity(0.05)
                    : Colors.white.withOpacity(0.1),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              currentLang.shortCode,
              style: TextStyle(
                color: isLight ? Colors.black87 : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
