from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace(path: str, old: str, new: str, label: str):
    p = ROOT / path
    text = p.read_text()
    if old not in text:
        raise SystemExit(f"missing {label} in {path}")
    p.write_text(text.replace(old, new, 1))
    print(f"patched {label}: {path}")

# Dashboard Events must never share a mutable sound preference with listing cards.
replace(
    "lib/src/features/dashboard/presentation/widgets/events_teaser_card_v2.dart",
    "import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';\n",
    "",
    "events shared audio import",
)
replace(
    "lib/src/features/dashboard/presentation/widgets/events_teaser_card_v2.dart",
    "    if (soundOn) {\n      ref.read(deckSoundOnProvider.notifier).preserveAudibleHandoff();\n    }\n\n",
    "",
    "events global audio handoff state",
)

# Warm real listing video frames earlier so Play starts from an initialized
# decoder, while keeping non-Events video manual-only.
replace(
    "lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart",
    "  double get _previewWarmupThreshold => kIsWeb ? 0.42 : 0.28;\n",
    "  double get _previewWarmupThreshold => kIsWeb ? 0.22 : 0.16;\n",
    "listing preview warmup threshold",
)
replace(
    "lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart",
    "      milliseconds: (kIsWeb ? 120 : 55) + stagger * (kIsWeb ? 55 : 28),\n",
    "      milliseconds: (kIsWeb ? 24 : 12) + stagger * (kIsWeb ? 22 : 12),\n",
    "listing preview warmup delay",
)
replace(
    "lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart",
    "  void _toggleSound() {\n    AppHaptics.selection();\n    unlockDeckMedia();\n    final nextSoundOn = !_soundOn;\n",
    "  void _toggleSound() {\n    AppHaptics.selection();\n    // Browser media unlock is only a gesture capability. The actual sound\n    // preference remains LOCAL to this exact quick-filter card. Never write a\n    // shared deck/event sound provider from here.\n    unlockDeckMedia();\n    final nextSoundOn = !_soundOn;\n",
    "quick filter local audio contract",
)

# Public listing video objects are immutable URLs; long cache headers make
# repeat dashboard/deck playback much snappier without stale replacements.
replace(
    "lib/src/features/swipes/data/repositories/listing_repository.dart",
    "import 'package:cross_file/cross_file.dart';\n",
    "import 'dart:async';\n\nimport 'package:cross_file/cross_file.dart';\n",
    "listing repository async import",
)
replace(
    "lib/src/features/swipes/data/repositories/listing_repository.dart",
    "                  fileOptions: FileOptions(contentType: contentType, upsert: true),\n",
    "                  fileOptions: FileOptions(\n                    contentType: contentType,\n                    cacheControl: '31536000',\n                    upsert: true,\n                  ),\n",
    "listing video immutable cache",
)
replace(
    "lib/src/features/swipes/data/repositories/listing_repository.dart",
    "  Future<Listing> createListing(Map<String, dynamic> payload) async {\n    // Production listings are owned through owner_id. Older client payloads can\n    // still contain the retired user_id key; strip it before the first insert so\n    // publishing does not intentionally fail once before schema-retry recovers.\n    final safe = Map<String, dynamic>.from(payload)..remove('user_id');\n    return _saveWithSchemaRetry(safe, editingId: null);\n  }\n",
    "  Future<Listing> createListing(Map<String, dynamic> payload) async {\n    // Production listings are owned through owner_id. Older client payloads can\n    // still contain the retired user_id key; strip it before the first insert so\n    // publishing does not intentionally fail once before schema-retry recovers.\n    final safe = Map<String, dynamic>.from(payload)..remove('user_id');\n    final listing = await _saveWithSchemaRetry(safe, editingId: null);\n\n    // Organic Social Boost is deliberately fire-and-forget. The server checks\n    // explicit user opt-in + connected networks, and listing creation never\n    // waits for Instagram/Facebook/TikTok/YouTube latency.\n    unawaited(() async {\n      try {\n        await _client.functions.invoke(\n          'social-distribute',\n          body: {'listing_id': listing.id},\n        );\n      } catch (_) {}\n    }());\n    return listing;\n  }\n",
    "automatic social distribution after listing create",
)

# Social Boost lives in Settings for both clients and owners.
replace(
    "lib/src/features/profile/presentation/screens/settings_screen.dart",
    "import 'package:flutter_swipes/src/features/profile/presentation/screens/security_screen.dart';\n",
    "import 'package:flutter_swipes/src/features/profile/presentation/screens/security_screen.dart';\nimport 'package:flutter_swipes/src/features/profile/presentation/screens/social_boost_screen.dart';\n",
    "social boost settings import",
)
replace(
    "lib/src/features/profile/presentation/screens/settings_screen.dart",
    "                  _SettingsRow(\n                    icon: Icons.public_rounded,\n                    label: 'LANGUAGE',\n                    description: 'EN / ES locale toggle',\n                    colors: const [Color(0xFF3730A3), Color(0xFF818CF8)],\n                    onTap: () => _push(\n                      context,\n                      const SecurityScreen(initialTab: 'language'),\n                    ),\n                  ),\n",
    "                  _SettingsRow(\n                    icon: Icons.public_rounded,\n                    label: 'LANGUAGE',\n                    description: 'EN / ES locale toggle',\n                    colors: const [Color(0xFF3730A3), Color(0xFF818CF8)],\n                    onTap: () => _push(\n                      context,\n                      const SecurityScreen(initialTab: 'language'),\n                    ),\n                  ),\n                  _SettingsRow(\n                    icon: Icons.rocket_launch_rounded,\n                    label: 'SOCIAL BOOST',\n                    description: 'Google discovery + connected social publishing',\n                    colors: const [Color(0xFFE4007C), Color(0xFF8B5CF6)],\n                    onTap: () => _push(context, const SocialBoostScreen()),\n                  ),\n",
    "social boost settings row",
)

# Fix the fire-and-forget helper without relying on FunctionResponse constructors.
replace(
    "lib/src/features/social/data/social_distribution_service.dart",
    "    unawaited(\n      _client.functions\n          .invoke('social-distribute', body: {'listing_id': listingId})\n          .catchError((Object error, StackTrace stack) {\n        debugPrint('Organic social distribution skipped: $error');\n        return FunctionResponse(status: 500, data: null);\n      }),\n    );\n",
    "    unawaited(() async {\n      try {\n        await _client.functions.invoke(\n          'social-distribute',\n          body: {'listing_id': listingId},\n        );\n      } catch (error) {\n        debugPrint('Organic social distribution skipped: $error');\n      }\n    }());\n",
    "social service fire-and-forget",
)

# Organic Google discovery: sitemap endpoint must bypass Flutter SPA rewrite.
replace(
    "vercel.json",
    '  "rewrites": [\n',
    '  "rewrites": [\n    {\n      "source": "/sitemap.xml",\n      "destination": "https://vplgtcguxujxwrgguxqq.supabase.co/functions/v1/seo-sitemap"\n    },\n',
    "sitemap rewrite",
)
replace(
    "vercel.json",
    '      "source": "/((?!\\\\.well-known/|apple-app-site-association$|account-deletion\\\\.html$).*)",\n',
    '      "source": "/((?!\\\\.well-known/|apple-app-site-association$|account-deletion\\\\.html$|robots\\\\.txt$|sitemap\\\\.xml$).*)",\n',
    "SEO SPA exclusions",
)

replace(
    "web/index.html",
    '<meta name="description" content="Swipess">',
    '<meta name="description" content="Swipess helps people discover properties, workers, vehicles, events, buyers, renters and local opportunities directly.">',
    "web SEO description",
)

print("Social Boost, video warmup, audio isolation and SEO patch complete")
