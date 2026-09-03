from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def load(rel: str) -> str:
    return (ROOT / rel).read_text()


def save(rel: str, text: str) -> None:
    (ROOT / rel).write_text(text)


def replace_once(rel: str, old: str, new: str) -> None:
    text = load(rel)
    if old not in text:
        raise SystemExit(f'missing anchor in {rel}: {old[:100]!r}')
    save(rel, text.replace(old, new, 1))


def regex_once(rel: str, pattern: str, replacement: str) -> None:
    text = load(rel)
    next_text, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f'expected one regex match in {rel}, got {count}: {pattern[:100]!r}')
    save(rel, next_text)


# ---------------------------------------------------------------------------
# Dashboard quick-filter media: opaque Supabase video URLs are authoritative,
# edge taps change media, center tap opens the category, and pressing Play
# immediately owns the single dashboard playback slot (so Events stops first).
# ---------------------------------------------------------------------------
QF = 'lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart'
replace_once(
    QF,
    "    this.videoPosterUrls = const <String, String>{},\n    this.handoffCategoryId,\n  });",
    "    this.videoPosterUrls = const <String, String>{},\n    this.handoffCategoryId,\n    this.onOpen,\n  });",
)
replace_once(
    QF,
    "  final Map<String, String> videoPosterUrls;\n  final String? handoffCategoryId;",
    "  final Map<String, String> videoPosterUrls;\n  final String? handoffCategoryId;\n  final VoidCallback? onOpen;",
)
replace_once(
    QF,
    "      _VideoPlaybackCoordinator.release(this);\n      return;\n    }\n\n    setState(() {\n      _videoPreviewEnabled = true;",
    "      _VideoPlaybackCoordinator.release(this);\n      return;\n    }\n\n    // Claim the one dashboard playback slot synchronously on the user's tap.\n    // This silences Events/another listing before video initialization starts,\n    // so two streams can never overlap while a network player warms up.\n    _VideoPlaybackCoordinator.activate(this, _visibleFraction);\n\n    setState(() {\n      _videoPreviewEnabled = true;",
)
replace_once(QF, "      if (!isQuickFilterVideoUrl(before)) return before;", "      if (!_isKnownVideoUrl(before)) return before;")
replace_once(QF, "      if (!isQuickFilterVideoUrl(after)) return after;", "      if (!_isKnownVideoUrl(after)) return after;")
replace_once(QF, "  Widget _buildMedia(String url) {\n    if (isQuickFilterVideoUrl(url)) {", "  Widget _buildMedia(String url) {\n    if (_isKnownVideoUrl(url)) {")
replace_once(QF, "        if (isQuickFilterVideoUrl(current))\n          Positioned(", "        if (_isKnownVideoUrl(current))\n          Positioned(")
replace_once(
    QF,
    "            behavior: HitTestBehavior.opaque,\n            onHorizontalDragStart: (_) => _dragDx = 0,",
    "            behavior: HitTestBehavior.opaque,\n            onTapUp: (details) {\n              final render = context.findRenderObject();\n              final width = render is RenderBox && render.hasSize\n                  ? render.size.width\n                  : 0.0;\n              if (_sources.length > 1 && width > 0) {\n                final x = details.localPosition.dx;\n                if (x <= width * .34) {\n                  AppHaptics.selection();\n                  _advance(-1);\n                  return;\n                }\n                if (x >= width * .66) {\n                  AppHaptics.selection();\n                  _advance(1);\n                  return;\n                }\n              }\n              widget.onOpen?.call();\n            },\n            onHorizontalDragStart: (_) => _dragDx = 0,",
)

# The card no longer puts an opaque tap layer above QuickFilterMedia. That old
# layer was swallowing its horizontal gestures. QuickFilterMedia now owns body
# taps and calls onOpen only from the center zone.
BENTO = 'lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart'
replace_once(BENTO, "class _BentoCardState extends State<_BentoCard> {\n  bool _pressed = false;\n", "class _BentoCardState extends State<_BentoCard> {\n")
replace_once(BENTO, "      scale: _pressed ? 0.985 : 1,", "      scale: 1,")
replace_once(
    BENTO,
    "                  videoPosterUrls: widget.videoPosterUrls,\n                  handoffCategoryId: widget.handoffCategoryId,\n                ),",
    "                  videoPosterUrls: widget.videoPosterUrls,\n                  handoffCategoryId: widget.handoffCategoryId,\n                  onOpen: widget.onTap,\n                ),",
)
regex_once(
    BENTO,
    r"\n              // Open the category from the card body, but leave the bottom-right\n              // control stack free so volume/play taps are never stolen\.\n              Positioned\(\n                top: 0,\n                left: 0,\n                right: 52,\n                bottom: 52,\n                child: GestureDetector\(.*?\n              \),",
    "\n              // Body taps/swipes are handled inside QuickFilterMedia so edge\n              // navigation and center-open never fight an opaque overlay.",
)

# ---------------------------------------------------------------------------
# Swipe/event chrome: one consistent six-second HUD window. The Events eye is
# a reveal/hide control, not a permanent pin. Keep the native video texture at
# a fixed full-screen render size while only the surrounding clip animates; this
# prevents the audible/visual micro-cut caused by resizing the video texture.
# ---------------------------------------------------------------------------
CHROME = 'lib/src/features/swipes/presentation/providers/chrome_reveal_provider.dart'
replace_once(CHROME, "  static const railHideMs = 5000;\n  static const chromeHideMs = 5600;", "  static const railHideMs = 6000;\n  static const chromeHideMs = 6000;")

EVENTS = 'lib/src/features/events/presentation/screens/events_screen.dart'
replace_once(EVENTS, "  static const _chromeTimeout = Duration(milliseconds: 5600);", "  static const _chromeTimeout = Duration(seconds: 6);")
regex_once(EVENTS, r"\n  void _togglePin\(\) \{.*?\n  \}\n\n  void _touchChrome\(\)", "\n  void _touchChrome()")
replace_once(EVENTS, "              onTap: _togglePin,", "              onTap: _toggleChrome,")
replace_once(
    EVENTS,
    "        final viewport = MediaQuery.sizeOf(context);\n        final viewWidth = constraints.hasBoundedWidth\n            ? constraints.maxWidth\n            : viewport.width;\n        final viewHeight = constraints.hasBoundedHeight\n            ? constraints.maxHeight\n            : viewport.height;",
    "        final viewport = MediaQuery.sizeOf(context);\n        // The eye button changes only the clip/frame around the movie. Keep the\n        // actual VideoPlayer texture at a stable full-screen size so Android,\n        // iOS and web never reconfigure the decoder or drop audio on reveal.\n        final viewWidth = viewport.width;\n        final viewHeight = viewport.height;",
)

# ---------------------------------------------------------------------------
# Back behavior: when a route reached with go() has no real stack entry, our
# fallback history must REPLACE the current browser entry. Using go(previous)
# creates a new browser-history item and causes the exact "back echo" loop.
# ---------------------------------------------------------------------------
BACK = 'lib/src/core/widgets/cap_back_button.dart'
replace_once(BACK, "        router.go(previous);", "        router.replace(previous);")
replace_once(BACK, "        router.go(fallback);\n        return;", "        router.replace(fallback);\n        return;")
replace_once(BACK, "    if (router != null && currentPath != fallback) router.go(fallback);", "    if (router != null && currentPath != fallback) router.replace(fallback);")

# ---------------------------------------------------------------------------
# Light mode: use a truly white application canvas and stop major swipe/discovery
# screens from overriding ThemeData with a permanent black Scaffold.
# ---------------------------------------------------------------------------
THEME = 'lib/src/core/theme/app_theme.dart'
replace_once(THEME, "  static const Color lightDashBg = Color(0xFFF2F2F7);\n  static const Color lightDashWell = Color(0xFFEDEDF2);", "  static const Color lightDashBg = Color(0xFFFFFFFF);\n  static const Color lightDashWell = Color(0xFFF6F6F8);")
for rel in [
    'lib/src/features/swipes/presentation/screens/client_swipe_container.dart',
    'lib/src/features/roommates/presentation/screens/roommate_matching_screen.dart',
    'lib/src/features/seekers/presentation/screens/people_intent_discovery_screen.dart',
]:
    replace_once(rel, "      backgroundColor: const Color(0xFF0A0A0D),", "      backgroundColor: Theme.of(context).scaffoldBackgroundColor,")

# ---------------------------------------------------------------------------
# Video upload is open to every authenticated account. Backend is authoritative;
# the UI must not flash a Premium lock while the entitlement RPC resolves.
# ---------------------------------------------------------------------------
MANUAL = 'lib/src/features/add/presentation/screens/add_listing_screen.dart'
regex_once(
    MANUAL,
    r"    final videoAccess = ref\.watch\(paidListingVideoAccessProvider\);\n    final subscription = ref\.watch\(subscriptionProvider\)\.value;\n    final canUploadVideo =\n        videoAccess\.value \?\? subscription\?\.isPaidActive == true;\n\n    void openPremiumVideo\(\) \{.*?\n    \}\n",
    "    const canUploadVideo = true;\n",
)
replace_once(
    MANUAL,
    "                onTap: () {\n                  if (!canUploadVideo) {\n                    openPremiumVideo();\n                    return;\n                  }\n                  if (draft.video == null) {",
    "                onTap: () {\n                  if (draft.video == null) {",
)

AI = 'lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart'
regex_once(
    AI,
    r"  Future<bool> _ensurePaidVideoAccess\(\) async \{.*?\n  \}\n\n  Future<void> _pickVideo\(\)",
    "  Future<bool> _ensurePaidVideoAccess() async {\n    // Video creation/editing is available to every signed-in listing account.\n    // The server/storage policies remain the final authorization layer.\n    return true;\n  }\n\n  Future<void> _pickVideo()",
)
regex_once(
    AI,
    r"  Widget _buildVideoPanel\(\) \{\n    final videoAccess = ref\.watch\(paidListingVideoAccessProvider\);\n    final subscription = ref\.watch\(subscriptionProvider\)\.value;\n    final canUploadVideo =\n        videoAccess\.value \?\? subscription\?\.isPaidActive == true;",
    "  Widget _buildVideoPanel() {\n    const canUploadVideo = true;",
)
replace_once(AI, "            : 'Paid Premium · Quick Filter exposure',", "            : 'Portrait 9:16 · Quick Filter ready',")

ADD_PROVIDER = 'lib/src/features/add/presentation/providers/add_listing_provider.dart'
replace_once(
    ADD_PROVIDER,
    "              'Active listing limit reached for $tier tier$suffix. Deactivate an existing listing or upgrade your plan.',",
    "              'Active listing limit reached$suffix for this category. Deactivate an existing listing in this category before publishing another.',",
)
replace_once(
    ADD_PROVIDER,
    "                'Listing video + dashboard Quick Filter exposure is a paid Premium benefit. Upgrade or remove the video to publish.',",
    "                'Listing video access could not be verified. Sign in again or retry the upload.',",
)

PACKAGES = 'lib/src/features/subscriptions/presentation/screens/subscription_packages_screen_v3.dart'
replace_once(
    PACKAGES,
    "                    text: 'AI, AI Listing Creator, Legal, Events, Premium listing capacity/visibility and other Premium advantages lock until you choose a Premium package. Listing video upload and dashboard Quick Filter video exposure always require a paid package.',",
    "                    text: 'AI, AI Listing Creator, Legal, Events, Premium listing capacity/visibility and other Premium advantages lock until you choose a Premium package. Listing video upload remains available to signed-in users.',",
)

# Keep the migration in source control too. Existing trusted-account overrides
# are defined by the prior migration; this migration changes only the universal
# category cap + video entitlement/policies.
MIGRATION = ROOT / 'supabase/migrations/20260903084420_open_listing_video_and_category_caps.sql'
if not MIGRATION.exists():
    MIGRATION.write_text("""-- Listing videos are available to every authenticated user.\n-- Listing capacity is 6 active listings per category unless a per-user override exists.\n\ncreate or replace function public._has_paid_listing_video_access(p_user_id uuid)\nreturns boolean language sql stable security definer set search_path = '' as $$\n  select p_user_id is not null;\n$$;\n\ncreate or replace function public.rpc_can_upload_listing_video()\nreturns boolean language sql stable security definer set search_path = '' as $$\n  select auth.uid() is not null;\n$$;\n\ndrop policy if exists \"listing videos insert own folder\" on storage.objects;\ncreate policy \"listing videos insert own folder\"\non storage.objects for insert to authenticated\nwith check (\n  bucket_id = 'listing-videos'\n  and (storage.foldername(name))[1] = (select auth.uid()::text)\n  and public._has_paid_listing_video_access((select auth.uid()))\n);\n\ndrop policy if exists \"listing videos update own folder\" on storage.objects;\ncreate policy \"listing videos update own folder\"\non storage.objects for update to authenticated\nusing (\n  bucket_id = 'listing-videos'\n  and (storage.foldername(name))[1] = (select auth.uid()::text)\n)\nwith check (\n  bucket_id = 'listing-videos'\n  and (storage.foldername(name))[1] = (select auth.uid()::text)\n  and public._has_paid_listing_video_access((select auth.uid()))\n);\n\ncreate or replace function public.rpc_can_publish_listing(p_category text)\nreturns jsonb language plpgsql stable security definer set search_path = '' as $$\ndeclare\n  v_user uuid := auth.uid();\n  v_category text := lower(btrim(coalesce(p_category, '')));\n  v_status jsonb;\n  v_video_enabled boolean;\n  v_limit integer;\n  v_category_count integer;\n  v_has_override boolean := false;\nbegin\n  if v_user is null then raise exception 'Authentication required'; end if;\n  v_status := public.content_quota_status();\n  select exists(select 1 from public.user_content_limit_overrides o where o.user_id = v_user) into v_has_override;\n  if v_has_override then\n    select o.max_active_per_listing_category into v_limit from public.user_content_limit_overrides o where o.user_id = v_user;\n  else\n    v_limit := 6;\n  end if;\n  select count(*)::integer into v_category_count from public.listings x\n   where x.owner_id = v_user and lower(coalesce(x.category, '')) = v_category\n     and coalesce(x.is_active, true) and coalesce(x.status, 'active') = 'active';\n  select mr.video_enabled into v_video_enabled from public.platform_media_rules mr where mr.content_type = v_category;\n  return v_status || jsonb_build_object(\n    'quota_override', v_has_override, 'listing_quota_scope', 'category',\n    'category', v_category, 'active_listings', v_category_count,\n    'max_active_listings', v_limit,\n    'listing_remaining', case when v_limit is null then null else greatest(v_limit-v_category_count,0) end,\n    'can_create_listing', v_limit is null or v_category_count < v_limit,\n    'video_enabled', coalesce(v_video_enabled,false),\n    'can_upload_video', true, 'video_requires_paid_premium', false\n  );\nend;\n$$;\n\ncreate or replace function public.enforce_listing_content_guardrails()\nreturns trigger language plpgsql security definer set search_path = '' as $$\ndeclare\n  v_limit integer; v_count integer; v_video_enabled boolean;\n  v_category text := lower(btrim(coalesce(new.category, '')));\n  v_video_changed boolean := false; v_has_override boolean := false;\nbegin\n  if public._is_active_admin(new.owner_id) then return new; end if;\n  v_video_changed := new.video_url is not null and btrim(new.video_url) <> ''\n    and (tg_op = 'INSERT' or old.video_url is distinct from new.video_url);\n  if v_video_changed then\n    select mr.video_enabled into v_video_enabled from public.platform_media_rules mr where mr.content_type = v_category;\n    if coalesce(v_video_enabled,false) = false then raise exception 'Video is not enabled for % listings', coalesce(new.category,'this category'); end if;\n  end if;\n  if coalesce(new.is_active,true) and coalesce(new.status,'active') = 'active' then\n    if tg_op = 'UPDATE' and coalesce(old.is_active,true) and coalesce(old.status,'active') = 'active'\n       and lower(btrim(coalesce(old.category,''))) = v_category then return new; end if;\n    select exists(select 1 from public.user_content_limit_overrides o where o.user_id = new.owner_id) into v_has_override;\n    if v_has_override then\n      select o.max_active_per_listing_category into v_limit from public.user_content_limit_overrides o where o.user_id = new.owner_id;\n    else\n      v_limit := 6;\n    end if;\n    if v_limit is not null then\n      select count(*)::integer into v_count from public.listings x\n       where x.owner_id = new.owner_id and lower(btrim(coalesce(x.category,''))) = v_category\n         and coalesce(x.is_active,true) and coalesce(x.status,'active') = 'active'\n         and (tg_op <> 'UPDATE' or x.id <> new.id);\n      if v_count >= v_limit then raise exception 'Active % listing limit reached (% listings)', v_category, v_limit; end if;\n    end if;\n  end if;\n  return new;\nend;\n$$;\n\nrevoke execute on function public._has_paid_listing_video_access(uuid) from public, anon, authenticated;\nrevoke execute on function public.enforce_listing_content_guardrails() from public, anon, authenticated;\nrevoke execute on function public.rpc_can_upload_listing_video() from public, anon;\ngrant execute on function public.rpc_can_upload_listing_video() to authenticated;\nrevoke execute on function public.rpc_can_publish_listing(text) from public, anon;\ngrant execute on function public.rpc_can_publish_listing(text) to authenticated;\n""")

print('media/theme/navigation hotfix applied')
