import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/intel_core_sheet.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/search_frame_shine.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/utils/open_swipe_deck.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Keyword-first dashboard search.
///
/// Pressing Enter routes direct marketplace keywords to the right Swipess
/// section. Only open Intel Core chat when the text is an actual assistant
/// question or the keyword cannot be resolved safely.
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
    AppHaptics.selection();
    _focus.unfocus();

    if (q.isEmpty) {
      await showIntelCoreSheet(context);
      return;
    }

    if (_routeKeyword(q)) {
      _controller.clear();
      return;
    }

    await showIntelCoreSheet(context, initialQuery: q);
  }

  bool _routeKeyword(String input) {
    final q = _normalize(input);
    bool has(String pattern) => RegExp(pattern).hasMatch(q);

    if (has(r'\b(legal admin|lawyer admin|admin legal)\b')) {
      context.go(AppPaths.legalAdminDashboard);
      return true;
    }

    if (has(r'\b(admin|back office|control panel|dashboard admin)\b')) {
      context.go(AppPaths.adminDashboard);
      return true;
    }

    if (has(r'\b(business|owner dashboard|owner side|landlord|host dashboard)\b')) {
      context.go(AppPaths.ownerDashboard);
      return true;
    }

    if (has(r'\b(documents?|document vault|vault|paperwork|files?|pdfs?|passport files?|ids?)\b')) {
      context.go(AppPaths.documents);
      return true;
    }

    if (has(r'\b(map|maps|near me|nearby|gps|passport|location|city|ciudad|zona|area)\b')) {
      ref.read(overlayModalsProvider.notifier).openPassportMap();
      return true;
    }

    if (has(r'\b(events?|party|parties|nightlife|concert|festival|happening|tonight)\b')) {
      context.go(AppPaths.exploreEvents);
      return true;
    }

    if (has(r'\b(legal|lawyer|lawyers|attorney|contract|contracts|fideicomiso|escrow|police help|legal help)\b')) {
      context.go(AppPaths.clientLegalServices);
      return true;
    }

    if (has(r'\b(workers?|hire|services?|maintenance|plumber|cleaner|cleaning|maid|chef|cook|driver|chauffeur|nanny|electrician|handyman|gardener|mechanic|contractor|painter|carpenter|welder|technician)\b')) {
      context.go(AppPaths.clientServices);
      return true;
    }

    if (has(r'\b(people|persons?|profiles?|users?|roommates?|seekers?|friends?|buyers?|renters?|gente|personas|amigos?)\b')) {
      context.go(AppPaths.exploreSeekers);
      return true;
    }

    if (has(r'\b(yachts?|boats?|catamarans?|sailboats?|yates?|barcos?)\b')) {
      openClientSwipeDeck(context, categoryId: 'yacht', categoryTitle: 'YACHTS');
      return true;
    }

    if (has(r'\b(motorcycles?|motorbikes?|motos?|scooters?|vespas?|motocicletas?)\b')) {
      openClientSwipeDeck(
        context,
        categoryId: 'motorcycle',
        categoryTitle: 'MOTORCYCLES',
      );
      return true;
    }

    if (has(r'\b(bicycles?|bikes?|bicis?|bicicletas?)\b')) {
      openClientSwipeDeck(context, categoryId: 'bicycle', categoryTitle: 'BICYCLES');
      return true;
    }

    if (has(r'\b(properties?|property|listings?|homes?|houses?|apartments?|rooms?|studios?|villas?|condos?|rentals?|rent|buy|sale|renta|casas?|departamentos?)\b')) {
      openClientSwipeDeck(
        context,
        categoryId: 'property',
        categoryTitle: 'PROPERTIES',
      );
      return true;
    }

    if (has(r'\b(filters?|filter search|search filters)\b')) {
      context.go(AppPaths.clientFilters);
      return true;
    }

    return false;
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúñü\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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
                  hintText: 'Search properties, workers, people, events...',
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
