from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)

repo = Path('.')

glow_path = repo / 'lib/src/core/widgets/glow_search_bar.dart'
glow = glow_path.read_text()

glow = replace_once(
    glow,
    "    this.onGuestsTap,\n  });",
    "    this.onGuestsTap,\n    this.compactHeader = false,\n  });",
    'GlowSearchBar constructor compactHeader',
)

glow = replace_once(
    glow,
    "  final VoidCallback? onGuestsTap;\n\n  @override",
    "  final VoidCallback? onGuestsTap;\n\n  /// Header mode keeps the AI control to one pill. The full dashboard widget\n  /// may render answers and the provider disclaimer below the field, which\n  /// must never expand the persistent app header into a second search row.\n  final bool compactHeader;\n\n  @override",
    'GlowSearchBar compactHeader field',
)

glow = replace_once(
    glow,
    "    if (wantsExplicitNavigation(input) && _runDirectSearch(input)) {\n      FocusManager.instance.primaryFocus?.unfocus();\n      return;\n    }\n\n    await _runInlineAi(input);",
    "    if (wantsExplicitNavigation(input) && _runDirectSearch(input)) {\n      FocusManager.instance.primaryFocus?.unfocus();\n      return;\n    }\n\n    // The persistent header is intentionally a single compact row. Continue\n    // conversational AI in the existing concierge overlay instead of growing\n    // the header with inline answer cards/disclaimers.\n    if (widget.compactHeader) {\n      ref.read(overlayModalsProvider.notifier).openConcierge(input);\n      FocusManager.instance.primaryFocus?.unfocus();\n      return;\n    }\n\n    await _runInlineAi(input);",
    'compact header submit behavior',
)

glow = replace_once(
    glow,
    "          _inlineAiPanel(isLight: isLight, ink: ink, blue: blue),\n          const SizedBox(height: 5),\n          Align(\n            alignment: Alignment.centerLeft,\n            child: Text(\n              'Google Gemini · can make mistakes.',\n              style: GoogleFonts.plusJakartaSans(\n                color: ink.withAlpha(isLight ? 135 : 170),\n                fontWeight: FontWeight.w500,\n                fontSize: 10.5,\n              ),\n            ),\n          ),",
    "          if (!widget.compactHeader) ...[\n            _inlineAiPanel(isLight: isLight, ink: ink, blue: blue),\n            const SizedBox(height: 5),\n            Align(\n              alignment: Alignment.centerLeft,\n              child: Text(\n                'Google Gemini · can make mistakes.',\n                style: GoogleFonts.plusJakartaSans(\n                  color: ink.withAlpha(isLight ? 135 : 170),\n                  fontWeight: FontWeight.w500,\n                  fontSize: 10.5,\n                ),\n              ),\n            ),\n          ],",
    'hide secondary AI chrome in compact header',
)

glow_path.write_text(glow)

shell_path = repo / 'lib/src/features/dashboard/presentation/screens/dashboard_shell.dart'
shell = shell_path.read_text()
shell = replace_once(
    shell,
    "                    searchBar: GlowSearchBar(\n                      controller: _dashboardSearchController,\n                      hint: 'What are you looking for?',\n                    ),",
    "                    searchBar: GlowSearchBar(\n                      controller: _dashboardSearchController,\n                      hint: 'What are you looking for?',\n                      compactHeader: true,\n                    ),",
    'DashboardShell compact AI bar',
)
shell_path.write_text(shell)

# Guard against the old dashboard-owned duplicate being reintroduced. The only
# live GlowSearchBar constructor outside its class should be DashboardShell.
bento_path = repo / 'lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart'
bento = bento_path.read_text()
if 'GlowSearchBar(' in bento:
    raise SystemExit('Bento dashboard still owns a duplicate GlowSearchBar')

print('Single dashboard AI bar patch applied.')
