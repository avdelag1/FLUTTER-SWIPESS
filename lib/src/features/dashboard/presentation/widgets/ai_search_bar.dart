import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/intel_core_sheet.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/search_frame_shine.dart';
import 'package:flutter_swipes/src/features/needs/presentation/widgets/need_composer_sheet.dart';
import 'package:google_fonts/google_fonts.dart';

/// AI entry point. Normal questions still open Intel Core; marketplace intent
/// opens the action composer so AI can find/post something after confirmation.
class AiSearchBar extends ConsumerStatefulWidget {
  const AiSearchBar({super.key});

  @override
  ConsumerState<AiSearchBar> createState() => _AiSearchBarState();
}

class _AiSearchBarState extends ConsumerState<AiSearchBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  static final _marketplaceIntent = RegExp(
    r'\b(i need|need a|need an|find me|looking for|i want|rent|buy|hire|book|scooter|motorcycle|bike|bicycle|villa|apartment|property|yacht|massage|cleaner|worker|service)\b',
    caseSensitive: false,
  );

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final q = _controller.text.trim();
    AppHaptics.selection();
    _focus.unfocus();
    if (q.isNotEmpty && _marketplaceIntent.hasMatch(q)) {
      await showNeedComposerSheet(context, initialQuery: q);
      return;
    }
    await showIntelCoreSheet(context, initialQuery: q);
  }

  Future<void> _openNeed() async {
    AppHaptics.selection();
    _focus.unfocus();
    await showNeedComposerSheet(context, initialQuery: _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final isLight = ref.watch(isLightThemeProvider);
    final glow = isLight ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD);
    final frame = isLight ? const Color(0xFF2563EB) : const Color(0xFF60A5FA);
    final fill = AppTheme.wellFor(isLight: isLight);
    final ink = isLight ? const Color(0xFF0A0A0D) : Colors.white;
    return SearchFrameShine(
      color: glow,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: frame, width: 1.5),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.search_rounded, color: glow.withAlpha(220), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                textInputAction: TextInputAction.search,
                style: GoogleFonts.plusJakartaSans(
                  color: ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.1,
                ),
                cursorColor: glow,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: 'Ask AI or say “I need…”',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: ink.withAlpha(140),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    letterSpacing: -0.1,
                  ),
                ),
                onSubmitted: (_) => _runSearch(),
              ),
            ),
            IconButton(
              onPressed: _openNeed,
              tooltip: 'I Need',
              icon: const Icon(
                Icons.bolt_rounded,
                color: Color(0xFFFF4D00),
                size: 20,
              ),
            ),
            IconButton(
              onPressed: _runSearch,
              tooltip: 'Ask AI',
              icon: Icon(
                Icons.arrow_forward_rounded,
                color: glow.withAlpha(230),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
