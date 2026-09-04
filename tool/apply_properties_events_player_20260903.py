from pathlib import Path

quick_path = Path('lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart')
quick = quick_path.read_text()

quick_anchor = '''class _VideoBudget {'''
quick_insert = '''/// Public bridge used by the dedicated Properties teaser. Events remains the\n/// default live dashboard player; a manual Properties video temporarily owns\n/// the playback slot, then gives it back on pause/end.\nvoid pauseDashboardEventsPreviewForListing() =>\n    _pauseDashboardEventsPreview?.call();\n\nvoid resumeDashboardEventsPreviewAfterListing() =>\n    _resumeDashboardEventsPreview?.call();\n\nclass _VideoBudget {'''
if 'void pauseDashboardEventsPreviewForListing()' not in quick:
    if quick_anchor not in quick:
        raise SystemExit('quick filter Events-hook insertion point not found')
    quick = quick.replace(quick_anchor, quick_insert, 1)
quick_path.write_text(quick)

screen_path = Path('lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart')
screen = screen_path.read_text()

import_anchor = "import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/events_teaser_card.dart';\n"
property_import = "import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/properties_teaser_card.dart';\n"
if property_import not in screen:
    if import_anchor not in screen:
        raise SystemExit('dashboard Events import anchor not found')
    screen = screen.replace(import_anchor, import_anchor + property_import, 1)

anchor = '''    return Stack(\n      children: [\n        _BentoCard(\n          title: item.title,'''
property_block = '''    // Properties now uses the same proven controller architecture as Events:\n    // one current controller, one prepared-next controller, direct VideoPlayer\n    // cover rendering and controller handoff. Keep the generic QuickFilterMedia\n    // path untouched for the other listing categories until Properties is proven.\n    if (item.id == 'property' && orderedPreviewListings.isNotEmpty) {\n      return Stack(\n        children: [\n          Container(\n            height: item.height,\n            decoration: AppTheme.qfNeoFrame(isLight: isLight),\n            child: ClipRRect(\n              borderRadius: AppTheme.qfNeoFrameRadius,\n              child: Stack(\n                fit: StackFit.expand,\n                children: [\n                  PropertiesTeaserCard(\n                    listings: orderedPreviewListings,\n                    onOpen: (listingId) {\n                      ref.read(accessedCategoriesProvider).markAccessed(item.id);\n                      onOpen(item.id, item.title, listingId);\n                    },\n                  ),\n                  const IgnorePointer(\n                    child: DecoratedBox(\n                      decoration: BoxDecoration(\n                        gradient: LinearGradient(\n                          begin: Alignment.topCenter,\n                          end: Alignment.bottomCenter,\n                          colors: [\n                            Colors.transparent,\n                            Colors.transparent,\n                            Color(0x4D000000),\n                          ],\n                          stops: [0, 0.82, 1],\n                        ),\n                      ),\n                    ),\n                  ),\n                  Positioned(\n                    left: 8,\n                    right: 75,\n                    bottom: 8,\n                    child: IgnorePointer(\n                      child: Column(\n                        crossAxisAlignment: CrossAxisAlignment.start,\n                        children: [\n                          FittedBox(\n                            fit: BoxFit.scaleDown,\n                            alignment: Alignment.centerLeft,\n                            child: Text(\n                              item.title,\n                              maxLines: 1,\n                              softWrap: false,\n                              style: AppTheme.displayItalic.copyWith(\n                                fontSize: 12,\n                                letterSpacing: 1.6,\n                                height: 1.1,\n                              ),\n                            ),\n                          ),\n                          const SizedBox(height: 2),\n                          Text(\n                            item.subtitle,\n                            style: GoogleFonts.plusJakartaSans(\n                              color: Colors.white.withAlpha(238),\n                              fontWeight: FontWeight.w700,\n                              fontSize: 11,\n                              letterSpacing: 0.4,\n                            ),\n                            maxLines: 1,\n                            overflow: TextOverflow.ellipsis,\n                          ),\n                        ],\n                      ),\n                    ),\n                  ),\n                ],\n              ),\n            ),\n          ),\n          badgeWidget,\n        ],\n      );\n    }\n\n    return Stack(\n      children: [\n        _BentoCard(\n          title: item.title,'''
if 'PropertiesTeaserCard(' not in screen:
    if anchor not in screen:
        raise SystemExit('generic BentoCard return anchor not found')
    screen = screen.replace(anchor, property_block, 1)

screen_path.write_text(screen)

if "properties_teaser_card.dart" not in screen:
    raise SystemExit('Properties teaser import missing after patch')
if "item.id == 'property' && orderedPreviewListings.isNotEmpty" not in screen:
    raise SystemExit('Properties special route missing after patch')
if 'void pauseDashboardEventsPreviewForListing()' not in quick:
    raise SystemExit('Events pause bridge missing after patch')

print('Properties Events-style player wiring applied')
