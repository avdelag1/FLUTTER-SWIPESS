import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/intel_core_sheet.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/search_frame_shine.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `AISearchBar` — type first, submit opens Intel Core with the query.
class AiSearchBar extends ConsumerStatefulWidget {
  const AiSearchBar({super.key});

  @override
  ConsumerState<AiSearchBar> createState() => _AiSearchBarState();
}

class _AiSearchBarState extends ConsumerState<AiSearchBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final q = _controller.text.trim();
    HapticFeedback.selectionClick();
    _focus.unfocus();
    await showIntelCoreSheet(context, initialQuery: q);
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
          border: Border.all(color: frame, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: frame.withValues(alpha: 0.85),
              offset: const Offset(1.5, 1.5),
            ),
            BoxShadow(
              color: glow.withValues(alpha: 0.22),
              blurRadius: 18,
            ),
          ],
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
                  hintText: 'Ask AI to find anything...',
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
              onPressed: _runSearch,
              tooltip: 'Search',
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
