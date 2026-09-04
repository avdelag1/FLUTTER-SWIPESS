from pathlib import Path

qf = Path('lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart')
text = qf.read_text()
needle = """void unregisterDashboardEventsPlaybackHooks({\n  required VoidCallback pause,\n  required VoidCallback resume,\n}) {\n  if (identical(_pauseDashboardEventsPreview, pause)) {\n    _pauseDashboardEventsPreview = null;\n  }\n  if (identical(_resumeDashboardEventsPreview, resume)) {\n    _resumeDashboardEventsPreview = null;\n  }\n}\n"""
replacement = needle + """\n/// Lets a dedicated listing teaser temporarily yield the live Events player\n/// without adopting QuickFilterMedia's controller/budget machinery.\nvoid pauseDashboardEventsPreviewForListing() =>\n    _pauseDashboardEventsPreview?.call();\n\nvoid resumeDashboardEventsPreviewAfterListing() =>\n    _resumeDashboardEventsPreview?.call();\n"""
if 'void pauseDashboardEventsPreviewForListing()' not in text:
    if needle not in text:
        raise SystemExit('events hook insertion point not found')
    text = text.replace(needle, replacement, 1)
qf.write_text(text)

bento = Path('lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart')
text = bento.read_text()
old_import = "import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/events_teaser_card.dart';\nimport 'package:flutter_swipes/src/features/dashboard/presentation/widgets/quick_filter_media.dart';"
new_import = "import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/events_teaser_card.dart';\nimport 'package:flutter_swipes/src/features/dashboard/presentation/widgets/property_teaser_card.dart';\nimport 'package:flutter_swipes/src/features/dashboard/presentation/widgets/quick_filter_media.dart';"
if old_import in text:
    text = text.replace(old_import, new_import, 1)
elif 'property_teaser_card.dart' not in text:
    raise SystemExit('dashboard import insertion point not found')

old_call = """        _BentoCard(\n          title: item.title,\n          subtitle: item.subtitle,\n          height: item.height,\n          media: liveListingMedia,\n          isLight: isLight,\n          enableVideo: isListingPreviewQuickFilter,\n          rotateSlot: item.index - 1,\n          slotCount: _bentoItems.length - 1,\n          sourceListingIds: sourceListingIds,\n          sourceImageListingIds: sourceImageListingIds,\n          videoPosterUrls: videoPosterUrls,\n          handoffCategoryId: isListingPreviewQuickFilter ? item.id : null,\n          onTap: (listingId) {\n            ref.read(accessedCategoriesProvider).markAccessed(item.id);\n            onOpen(item.id, item.title, listingId);\n          },\n        ),"""
new_call = """        _BentoCard(\n          title: item.title,\n          subtitle: item.subtitle,\n          height: item.height,\n          media: liveListingMedia,\n          isLight: isLight,\n          // During the Properties canary, every other listing category remains\n          // a static poster so hidden decoders cannot contaminate the test.\n          enableVideo: false,\n          mediaChild: item.id == 'property'\n              ? PropertyTeaserCard(\n                  media: liveListingMedia,\n                  sourceListingIds: sourceListingIds,\n                  sourceImageListingIds: sourceImageListingIds,\n                  videoPosterUrls: videoPosterUrls,\n                  onOpen: (listingId) {\n                    ref.read(accessedCategoriesProvider).markAccessed(item.id);\n                    onOpen(item.id, item.title, listingId);\n                  },\n                )\n              : null,\n          rotateSlot: item.index - 1,\n          slotCount: _bentoItems.length - 1,\n          sourceListingIds: sourceListingIds,\n          sourceImageListingIds: sourceImageListingIds,\n          videoPosterUrls: videoPosterUrls,\n          handoffCategoryId: isListingPreviewQuickFilter ? item.id : null,\n          onTap: (listingId) {\n            ref.read(accessedCategoriesProvider).markAccessed(item.id);\n            onOpen(item.id, item.title, listingId);\n          },\n        ),"""
if old_call not in text:
    raise SystemExit('BentoCard call block not found')
text = text.replace(old_call, new_call, 1)

old_ctor = """    this.videoPosterUrls = const <String, String>{},\n    this.handoffCategoryId,\n  });"""
new_ctor = """    this.videoPosterUrls = const <String, String>{},\n    this.handoffCategoryId,\n    this.mediaChild,\n  });"""
if old_ctor not in text:
    raise SystemExit('BentoCard constructor insertion point not found')
text = text.replace(old_ctor, new_ctor, 1)

old_fields = """  final Map<String, String> videoPosterUrls;\n  final String? handoffCategoryId;\n\n  @override"""
new_fields = """  final Map<String, String> videoPosterUrls;\n  final String? handoffCategoryId;\n  final Widget? mediaChild;\n\n  @override"""
if old_fields not in text:
    raise SystemExit('BentoCard fields insertion point not found')
text = text.replace(old_fields, new_fields, 1)

old_media = """              QuickFilterMedia(\n                sources: widget.media,\n                rotateSlot: widget.rotateSlot,\n                slotCount: widget.slotCount,\n                enableVideo: widget.enableVideo,\n                showMute: widget.enableVideo,\n                sourceListingIds: widget.sourceListingIds,\n                sourceImageListingIds: widget.sourceImageListingIds,\n                videoPosterUrls: widget.videoPosterUrls,\n                handoffCategoryId: widget.handoffCategoryId,\n                onOpen: widget.onTap,\n              ),"""
new_media = """              widget.mediaChild ??\n                  QuickFilterMedia(\n                    sources: widget.media,\n                    rotateSlot: widget.rotateSlot,\n                    slotCount: widget.slotCount,\n                    enableVideo: widget.enableVideo,\n                    showMute: widget.enableVideo,\n                    sourceListingIds: widget.sourceListingIds,\n                    sourceImageListingIds: widget.sourceImageListingIds,\n                    videoPosterUrls: widget.videoPosterUrls,\n                    handoffCategoryId: widget.handoffCategoryId,\n                    onOpen: widget.onTap,\n                  ),"""
if old_media not in text:
    raise SystemExit('QuickFilterMedia child block not found')
text = text.replace(old_media, new_media, 1)
bento.write_text(text)

print('property Events-style player wiring applied')
