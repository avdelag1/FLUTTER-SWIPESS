from pathlib import Path
import re


def once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing expected block: {label}")
    return text.replace(old, new, 1)


def regex_once(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(
        pattern,
        lambda _: replacement,
        text,
        count=1,
        flags=re.S,
    )
    if count != 1:
        raise SystemExit(f"missing/ambiguous regex block: {label} ({count})")
    return updated


# ---------------------------------------------------------------------------
# Dashboard AI search: explicit language + compact scrollable answer/contact UI
# ---------------------------------------------------------------------------
path = Path("lib/src/core/widgets/glow_search_bar.dart")
s = path.read_text()

s = once(
    s,
    "import 'package:flutter_swipes/src/features/ai/presentation/services/live_voice_input.dart';\n",
    "import 'package:flutter_swipes/src/features/ai/presentation/services/live_voice_input.dart';\n"
    "import 'package:flutter_swipes/src/features/ai/presentation/providers/voice_language_provider.dart';\n"
    "import 'package:flutter_swipes/src/features/ai/presentation/widgets/voice_language_selector.dart';\n",
    "dashboard voice language imports",
)

s = s.replace(
    "import 'package:flutter_swipes/src/features/ai/presentation/widgets/intel_local_brain_card.dart';\n",
    "",
    1,
)

s = once(
    s,
    "  static const _voiceLocale = 'en-US';\n",
    "",
    "remove hard-wired dashboard English locale",
)

s = once(
    s,
    "  bool get _isListeningSession =>\n",
    "  VoiceLanguage get _voiceLanguage => ref.read(voiceLanguageProvider);\n"
    "  String get _voiceLocale => _voiceLanguage.localeCode;\n\n"
    "  bool get _isListeningSession =>\n",
    "dashboard selected voice locale getter",
)

s = once(
    s,
    "            locationContext: {\n"
    "              'passportMode': true,\n"
    "              'passportLabel': widget.locationLabel,\n"
    "              'radiusKm': 50,\n"
    "            },\n",
    "            locationContext: {\n"
    "              'passportMode': true,\n"
    "              'passportLabel': widget.locationLabel,\n"
    "              'radiusKm': 50,\n"
    "              'compactDashboard': true,\n"
    "              'responseLanguage':\n"
    "                  ref.read(voiceLanguageProvider).displayName,\n"
    "            },\n",
    "dashboard compact/language AI context",
)

new_inline_panel = r'''  void _openContactInChat(Map<String, dynamic> data) {
    final name = (data['name'] ?? data['full_name'] ?? data['title'])
        ?.toString()
        .trim();
    if (name == null || name.isEmpty) return;
    AppHaptics.selection();
    _dismissInlineAi();
    widget.onSubmitted?.call('Tell me only about this person: $name');
  }

  Widget _inlineAiPanel({
    required bool isLight,
    required Color ink,
    required Color blue,
  }) {
    final answer = _inlineAnswer;
    final brain = _inlineLocalBrain.take(3).toList(growable: false);
    final profileSlots = math.max(0, 3 - brain.length).toInt();
    final profiles = _inlineProfiles.take(profileSlots).toList(growable: false);
    final listings = _inlineListings.take(2).toList(growable: false);
    final hasResults =
        brain.isNotEmpty || profiles.isNotEmpty || listings.isNotEmpty;
    if (!_inlineAiLoading &&
        (answer == null || answer.trim().isEmpty) &&
        !hasResults) {
      return const SizedBox.shrink();
    }

    final maxPanelHeight = math.min(
      360.0,
      MediaQuery.sizeOf(context).height * .42,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 210),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: isLight ? blue.withAlpha(10) : blue.withAlpha(20),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: blue.withAlpha(isLight ? 70 : 90)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isLight ? 10 : 34),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: _inlineAiLoading
          ? Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: blue),
                ),
                const SizedBox(width: 9),
                Text(
                  'Google Gemini is thinking…',
                  style: GoogleFonts.plusJakartaSans(
                    color: ink.withAlpha(180),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          : ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxPanelHeight),
              child: SingleChildScrollView(
                primary: false,
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'GOOGLE GEMINI',
                          style: GoogleFonts.plusJakartaSans(
                            color: blue,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _dismissInlineAi,
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: ink.withAlpha(120),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (answer != null && answer.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        answer,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: ink,
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (hasResults) ...[
                      if (answer != null && answer.trim().isNotEmpty)
                        const SizedBox(height: 9),
                      for (final entry in brain)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: _DashboardContactPreview(
                            data: entry,
                            isLight: isLight,
                            accent: blue,
                            onTap: () => _openContactInChat(entry),
                          ),
                        ),
                      for (final profile in profiles)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: _DashboardContactPreview(
                            data: profile,
                            isLight: isLight,
                            accent: blue,
                            onTap: () => _openContactInChat(profile),
                          ),
                        ),
                      for (final listing in listings)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: IntelListingCard(data: listing),
                        ),
                    ],
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Answer stays on Dashboard',
                            style: GoogleFonts.plusJakartaSans(
                              color: ink.withAlpha(120),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _continueInChat,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: blue.withAlpha(isLight ? 18 : 32),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: blue.withAlpha(75)),
                            ),
                            child: Text(
                              'Continue in chat',
                              style: GoogleFonts.plusJakartaSans(
                                color: blue,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
'''

s = regex_once(
    s,
    r"  Widget _inlineAiPanel\(\{.*?\n  @override\n  Widget build",
    new_inline_panel + "\n  @override\n  Widget build",
    "compact dashboard AI panel",
)

s = once(
    s,
    "                IconButton(\n"
    "                  visualDensity: VisualDensity.compact,\n"
    "                  tooltip: 'Send',\n",
    "                const SizedBox(width: 4),\n"
    "                VoiceLanguageSelector(isLight: isLight),\n"
    "                const SizedBox(width: 2),\n"
    "                IconButton(\n"
    "                  visualDensity: VisualDensity.compact,\n"
    "                  tooltip: 'Send',\n",
    "dashboard language selector placement",
)

if "class _DashboardContactPreview" not in s:
    s += r'''

class _DashboardContactPreview extends StatelessWidget {
  const _DashboardContactPreview({
    required this.data,
    required this.isLight,
    required this.accent,
    required this.onTap,
  });

  final Map<String, dynamic> data;
  final bool isLight;
  final Color accent;
  final VoidCallback onTap;

  String _first(List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final ink = isLight ? const Color(0xFF101014) : Colors.white;
    final name = _first(['name', 'full_name', 'title']);
    final category = _first(['category', 'active_mode']);
    final city = _first(['city', 'location']);
    final description = _first(['recommendation_note', 'description']);
    final image = _first(['card_image_url', 'photo_url', 'avatar_url', 'image']);
    final channels = <String>[
      if (_first(['whatsapp']).isNotEmpty) 'WhatsApp',
      if (_first(['instagram']).isNotEmpty) 'Instagram',
    ];
    final subtitle = [
      if (category.isNotEmpty) category,
      if (city.isNotEmpty && city.toLowerCase() != 'global') city,
    ].join(' · ');

    return Material(
      color: isLight ? Colors.white.withAlpha(180) : Colors.white.withAlpha(7),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(9, 9, 8, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: accent.withAlpha(isLight ? 34 : 48)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 39,
                height: 39,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: accent.withAlpha(isLight ? 16 : 28),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: image.isNotEmpty
                    ? Image.network(
                        image,
                        fit: BoxFit.cover,
                        cacheWidth: 150,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.person_rounded,
                          color: accent,
                          size: 20,
                        ),
                      )
                    : Icon(Icons.person_rounded, color: accent, size: 20),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Contact' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: ink,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: accent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: ink.withAlpha(170),
                            fontSize: 10.5,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    if (channels.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          channels.join(' · '),
                          style: GoogleFonts.plusJakartaSans(
                            color: ink.withAlpha(115),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: ink.withAlpha(95),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
'''

path.write_text(s)


# ---------------------------------------------------------------------------
# Full Intel chat: the chosen language also locks AI reply language.
# ---------------------------------------------------------------------------
path = Path("lib/src/features/dashboard/presentation/widgets/intel_core_sheet.dart")
s = path.read_text()
needle = "                  'radiusKm': loc.radiusKm,\n"
count = s.count(needle)
if count < 2:
    raise SystemExit(f"expected at least two Intel Core location blocks, got {count}")
s = s.replace(
    needle,
    needle
    + "                  'responseLanguage':\n"
    + "                      ref.read(voiceLanguageProvider).displayName,\n",
)
path.write_text(s)


# ---------------------------------------------------------------------------
# AI Edge Function: compact dashboard behavior, language lock, exact-name drill
# ---------------------------------------------------------------------------
path = Path("supabase/functions/ai-concierge/index.ts")
s = path.read_text()

s = once(
    s,
    "      p_limit: 8,\n"
    "    });\n"
    "    if (error) {\n"
    "      console.error(\"[ai-concierge-v80] local brain context\", error.message);\n"
    "      return [];\n"
    "    }\n"
    "    return Array.isArray(data) ? data : [];\n",
    "      p_limit: body?.locationContext?.compactDashboard === true ? 5 : 8,\n"
    "    });\n"
    "    if (error) {\n"
    "      console.error(\"[ai-concierge-v80] local brain context\", error.message);\n"
    "      return [];\n"
    "    }\n"
    "    const rows = Array.isArray(data) ? data : [];\n"
    "    const normalize = (value: unknown) => String(value ?? \"\")\n"
    "      .toLowerCase()\n"
    "      .replace(/[^a-z0-9áéíóúñü\\s-]/g, \" \")\n"
    "      .replace(/\\s+/g, \" \")\n"
    "      .trim();\n"
    "    const normalizedQuery = normalize(query);\n"
    "    const exactNamed = rows.filter((row: any) => {\n"
    "      const name = normalize(row?.name);\n"
    "      return name.length >= 3 && normalizedQuery.includes(name);\n"
    "    });\n"
    "    if (exactNamed.length) return exactNamed.slice(0, 1);\n"
    "    const maxRows = body?.locationContext?.compactDashboard === true ? 3 : 5;\n"
    "    return rows.slice(0, maxRows);\n",
    "local brain result cap and exact-name drilldown",
)

s = once(
    s,
    "  const preferredIntent = body?.preferredIntent?.toString().trim().toLowerCase() || \"\";\n"
    "  const peopleFirst = preferredIntent === \"profiles\" || wantsPeople(query);\n",
    "  const preferredIntent = body?.preferredIntent?.toString().trim().toLowerCase() || \"\";\n"
    "  const compactDashboard = body?.locationContext?.compactDashboard === true;\n"
    "  const peopleFirst = preferredIntent === \"profiles\" || wantsPeople(query);\n",
    "compact dashboard context flag",
)

s = once(
    s,
    "  return { category, listings, events, profiles, localBrain, userMemory, peopleFirst };\n",
    "  return { category, listings, events, profiles, localBrain, userMemory, peopleFirst, compactDashboard };\n",
    "return compact dashboard flag",
)

s = once(
    s,
    "  const location = body?.locationContext?.passportLabel?.toString().trim();\n"
    "  const character = body?.character?.toString().trim();\n"
    "  const casualCount = recentCasualCount(history);\n",
    "  const location = body?.locationContext?.passportLabel?.toString().trim();\n"
    "  const character = body?.character?.toString().trim();\n"
    "  const responseLanguage = body?.locationContext?.responseLanguage?.toString().trim();\n"
    "  const compactDashboard = body?.locationContext?.compactDashboard === true;\n"
    "  const casualCount = recentCasualCount(history);\n",
    "AI response language and compact prompt flags",
)

s = once(
    s,
    "    \"Reply in the same language as the user's latest message unless they ask for another language.\",\n"
    "    \"Be concise, useful, conversational, friendly, and action-oriented.\",\n",
    "    responseLanguage\n"
    "      ? `LANGUAGE LOCK: Reply only in ${responseLanguage}. The user explicitly selected this language; do not auto-detect or switch languages unless they explicitly ask you to translate.`\n"
    "      : \"Reply in the same language as the user's latest message unless they ask for another language.\",\n"
    "    \"Be concise, useful, conversational, friendly, and action-oriented.\",\n"
    "    compactDashboard\n"
    "      ? \"DASHBOARD COMPACT MODE: Keep the visible prose to 1-2 short sentences. Never dump every profile or every saved detail into prose. Contact cards render separately. If one person is clearly the best match, mention only that person in prose; otherwise briefly say there are a few good matches.\"\n"
    "      : \"\",\n",
    "AI language lock and compact response rule",
)

s = once(
    s,
    "    ctx.peopleFirst && ctx.localBrain.length ? \"CONTACT-FIRST RULE: answer from the curated Local Brain matches only and do not mix in unrelated listings or profiles.\" : \"\",\n",
    "    ctx.peopleFirst && ctx.localBrain.length ? \"CONTACT-FIRST RULE: answer from the curated Local Brain matches only and do not mix in unrelated listings or profiles.\" : \"\",\n"
    "    compactDashboard && ctx.peopleFirst && ctx.localBrain.length ? \"RANKING RULE: trust the Local Brain relevance order. Recommend the first/best match first. Do not describe all matches unless the user explicitly asks for options.\" : \"\",\n",
    "compact contact ranking rule",
)

s = once(
    s,
    "    const intro = ctx.localBrain.length === 1\n"
    "      ? `I found a trusted local match: ${first?.name || \"this contact\"}.`\n"
    "      : `I found ${ctx.localBrain.length} trusted local matches for you.`;\n",
    "    const intro = ctx.compactDashboard\n"
    "      ? `Best match: ${first?.name || \"this contact\"}.`\n"
    "      : ctx.localBrain.length === 1\n"
    "      ? `I found a trusted local match: ${first?.name || \"this contact\"}.`\n"
    "      : `I found ${ctx.localBrain.length} trusted local matches for you.`;\n",
    "compact emergency contact reply",
)

s = s.replace(
    'mode: "grounded-flexible-local-brain-cards-v2"',
    'mode: "grounded-compact-local-brain-cards-v3"',
    1,
)

path.write_text(s)
