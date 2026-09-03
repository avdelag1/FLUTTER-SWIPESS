from pathlib import Path
import re


def read(path: str) -> str:
    return Path(path).read_text()


def write(path: str, text: str) -> None:
    Path(path).write_text(text)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing patch target: {label}")
    return text.replace(old, new, 1)


def sub_once(text: str, pattern: str, repl: str, label: str, flags: int = 0) -> str:
    updated, count = re.subn(pattern, repl, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f"missing/ambiguous patch target: {label} ({count})")
    return updated


# 1) Reuse the dashboard's existing full-featured location/date/guest pickers
# from the shared top-right menu instead of duplicating weaker picker logic.
actions_path = (
    "lib/src/features/dashboard/presentation/providers/"
    "dashboard_discovery_menu_actions_provider.dart"
)
write(
    actions_path,
    r'''import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class DashboardDiscoveryMenuActions {
  const DashboardDiscoveryMenuActions({
    this.openLocation,
    this.openDates,
    this.openGuests,
  });

  final VoidCallback? openLocation;
  final VoidCallback? openDates;
  final VoidCallback? openGuests;

  bool get available =>
      openLocation != null && openDates != null && openGuests != null;
}

class DashboardDiscoveryMenuActionsNotifier
    extends Notifier<DashboardDiscoveryMenuActions> {
  @override
  DashboardDiscoveryMenuActions build() =>
      const DashboardDiscoveryMenuActions();

  void register({
    required VoidCallback openLocation,
    required VoidCallback openDates,
    required VoidCallback openGuests,
  }) {
    state = DashboardDiscoveryMenuActions(
      openLocation: openLocation,
      openDates: openDates,
      openGuests: openGuests,
    );
  }

  void clear() => state = const DashboardDiscoveryMenuActions();
}

final dashboardDiscoveryMenuActionsProvider = NotifierProvider<
    DashboardDiscoveryMenuActionsNotifier,
    DashboardDiscoveryMenuActions>(DashboardDiscoveryMenuActionsNotifier.new);
''',
)

# 2) Register the existing dashboard picker methods while this screen is alive,
# and tighten spacing now that the discovery chip row is leaving the canvas.
p = "lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart"
s = read(p)
import_anchor = (
    "import 'package:flutter_swipes/src/features/dashboard/presentation/providers/"
    "discovery_location_provider.dart';\n"
)
actions_import = (
    "import 'package:flutter_swipes/src/features/dashboard/presentation/providers/"
    "dashboard_discovery_menu_actions_provider.dart';\n"
)
if actions_import not in s:
    s = replace_once(s, import_anchor, import_anchor + actions_import, "dashboard actions import")

s = replace_once(
    s,
    "  final _scroll = ScrollController();\n\n  @override\n  void dispose() {\n    _scroll.dispose();\n",
    "  final _scroll = ScrollController();\n\n"
    "  @override\n"
    "  void initState() {\n"
    "    super.initState();\n"
    "    WidgetsBinding.instance.addPostFrameCallback((_) {\n"
    "      if (!mounted) return;\n"
    "      ref.read(dashboardDiscoveryMenuActionsProvider.notifier).register(\n"
    "            openLocation: _pickCity,\n"
    "            openDates: _pickDates,\n"
    "            openGuests: _pickGuests,\n"
    "          );\n"
    "    });\n"
    "  }\n\n"
    "  @override\n"
    "  void dispose() {\n"
    "    ref.read(dashboardDiscoveryMenuActionsProvider.notifier).clear();\n"
    "    _scroll.dispose();\n",
    "register dashboard discovery menu actions",
)

s = replace_once(
    s,
    "padding: EdgeInsets.fromLTRB(16, 48, 16, 8),",
    "padding: EdgeInsets.fromLTRB(16, 48, 16, 2),",
    "search to cards vertical gap",
)
s = replace_once(
    s,
    "child: Padding(\n                    padding: EdgeInsets.all(8),",
    "child: Padding(\n                    padding: EdgeInsets.fromLTRB(8, 2, 8, 8),",
    "bento top padding",
)
write(p, s)

# 3) Remove the old location/date/guest pill row from the AI search widget.
# The public callback API remains intact because the header now invokes the
# exact same dashboard handlers via the action registry above.
p = "lib/src/core/widgets/glow_search_bar.dart"
s = read(p)
s = sub_once(
    s,
    r'''\n\s*const SizedBox\(height: 7\),\n\s*Row\(\n\s*children: \[\n\s*Expanded\(\n\s*child: _outerPill\(\n\s*Icons\.location_on_rounded,\n\s*widget\.locationLabel,\n\s*ink,\n\s*isLight,\n\s*widget\.onLocationTap,\n\s*\),\n\s*\),\n\s*const SizedBox\(width: 6\),\n\s*Expanded\(\n\s*child: _outerPill\(\n\s*Icons\.calendar_month_rounded,\n\s*widget\.dateLabel,\n\s*ink,\n\s*isLight,\n\s*widget\.onDatesTap,\n\s*\),\n\s*\),\n\s*const SizedBox\(width: 6\),\n\s*Expanded\(\n\s*child: _outerPill\(\n\s*Icons\.person_rounded,\n\s*widget\.guestLabel,\n\s*ink,\n\s*isLight,\n\s*widget\.onGuestsTap,\n\s*\),\n\s*\),\n\s*\],\n\s*\),''',
    "",
    "remove dashboard discovery pills",
    flags=re.S,
)
write(p, s)

# 4) Reorganize the burger around what helps discovery first, then app controls,
# then monetization. Values are visible directly in the menu without cluttering
# the dashboard canvas.
p = "lib/src/core/widgets/app_top_bar.dart"
s = read(p)
base_import = (
    "import 'package:flutter_swipes/src/features/swipes/presentation/widgets/"
    "filter_bottom_sheet.dart';\n"
)
menu_imports = (
    "import 'package:flutter_swipes/src/features/dashboard/presentation/providers/"
    "dashboard_discovery_menu_actions_provider.dart';\n"
    "import 'package:flutter_swipes/src/features/dashboard/presentation/providers/"
    "discovery_location_provider.dart';\n"
)
if "dashboard_discovery_menu_actions_provider.dart" not in s:
    s = replace_once(s, base_import, base_import + menu_imports, "header discovery imports")

s = replace_once(
    s,
    "    final unreadCount = ref.watch(unreadNotificationsProvider).value ?? 0;\n\n    return Row(",
    "    final unreadCount = ref.watch(unreadNotificationsProvider).value ?? 0;\n"
    "    final discovery = ref.watch(discoveryLocationProvider);\n"
    "    final discoveryActions = ref.watch(dashboardDiscoveryMenuActionsProvider);\n"
    "    final showDiscovery = isDashboard && discoveryActions.available;\n\n"
    "    return Row(",
    "header discovery state",
)

s = replace_once(
    s,
    "              case 'filters':\n                ref.read(overlayModalsProvider.notifier).closeAll();\n                FilterBottomSheet.show(context);\n                break;\n",
    "              case 'location':\n"
    "                discoveryActions.openLocation?.call();\n"
    "                break;\n"
    "              case 'dates':\n"
    "                discoveryActions.openDates?.call();\n"
    "                break;\n"
    "              case 'guests':\n"
    "                discoveryActions.openGuests?.call();\n"
    "                break;\n"
    "              case 'filters':\n"
    "                ref.read(overlayModalsProvider.notifier).closeAll();\n"
    "                FilterBottomSheet.show(context);\n"
    "                break;\n",
    "discovery menu actions",
)

new_items = r'''          itemBuilder: (_) => [
            if (showDiscovery) ...[
              PopupMenuItem<String>(
                enabled: false,
                height: 28,
                child: _HeaderMenuSection(label: 'DISCOVERY', ink: ink),
              ),
              PopupMenuItem<String>(
                value: 'location',
                height: 44,
                child: _HeaderMenuRow(
                  icon: Icons.location_on_rounded,
                  label: 'Location',
                  trailing: discovery.city,
                  ink: ink,
                  accented: true,
                ),
              ),
              PopupMenuItem<String>(
                value: 'dates',
                height: 44,
                child: _HeaderMenuRow(
                  icon: Icons.calendar_month_rounded,
                  label: 'Dates',
                  trailing: discovery.dateLabel,
                  ink: ink,
                ),
              ),
              PopupMenuItem<String>(
                value: 'guests',
                height: 44,
                child: _HeaderMenuRow(
                  icon: Icons.group_rounded,
                  label: 'People',
                  trailing:
                      '${discovery.guests} ${discovery.guests == 1 ? 'person' : 'people'}',
                  ink: ink,
                ),
              ),
              const PopupMenuDivider(height: 10),
            ],
            PopupMenuItem<String>(
              enabled: false,
              height: 28,
              child: _HeaderMenuSection(label: 'APP', ink: ink),
            ),
            PopupMenuItem<String>(
              value: 'filters',
              height: 44,
              child: _HeaderMenuRow(
                icon: Icons.tune_rounded,
                label: 'Filters',
                ink: ink,
              ),
            ),
            PopupMenuItem<String>(
              value: 'notifications',
              height: 44,
              child: _HeaderMenuRow(
                icon: Icons.notifications_none_rounded,
                label: 'Notifications',
                trailing: unreadCount > 0
                    ? (unreadCount > 99 ? '99+' : '$unreadCount')
                    : null,
                ink: ink,
              ),
            ),
            PopupMenuItem<String>(
              value: 'theme',
              height: 44,
              child: _HeaderMenuRow(
                icon: isLight
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                label: isLight ? 'Dark appearance' : 'Light appearance',
                ink: ink,
              ),
            ),
            const PopupMenuDivider(height: 10),
            PopupMenuItem<String>(
              enabled: false,
              height: 28,
              child: _HeaderMenuSection(label: 'ACCOUNT', ink: ink),
            ),
            PopupMenuItem<String>(
              value: 'tokens',
              height: 44,
              child: _HeaderMenuRow(
                icon: Icons.toll_rounded,
                label: 'Tokens',
                trailing: tokensLabel,
                ink: ink,
                accented: true,
              ),
            ),
            PopupMenuItem<String>(
              value: 'premium',
              height: 44,
              child: _HeaderMenuRow(
                icon: Icons.workspace_premium_rounded,
                label: 'Premium packages',
                ink: ink,
                accented: true,
              ),
            ),
          ],
          child: SizedBox('''
s = sub_once(
    s,
    r"          itemBuilder: \(_\) => \[.*?          \],\n          child: SizedBox\(",
    new_items,
    "reorganize burger menu",
    flags=re.S,
)

# Make long date/location labels safe inside the compact popup.
s = replace_once(
    s,
    "              child: Text(\n                trailing!,\n                style: GoogleFonts.plusJakartaSans(\n                  color: AppTheme.brandPrimary,\n                  fontSize: 10,\n                  fontWeight: FontWeight.w900,\n                ),\n              ),\n",
    "              child: ConstrainedBox(\n"
    "                constraints: const BoxConstraints(maxWidth: 112),\n"
    "                child: Text(\n"
    "                  trailing!,\n"
    "                  maxLines: 1,\n"
    "                  overflow: TextOverflow.ellipsis,\n"
    "                  style: GoogleFonts.plusJakartaSans(\n"
    "                    color: AppTheme.brandPrimary,\n"
    "                    fontSize: 10,\n"
    "                    fontWeight: FontWeight.w900,\n"
    "                  ),\n"
    "                ),\n"
    "              ),\n",
    "safe menu trailing labels",
)

section_class = r'''
class _HeaderMenuSection extends StatelessWidget {
  const _HeaderMenuSection({required this.label, required this.ink});

  final String label;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        color: ink.withAlpha(105),
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    );
  }
}

'''
s = replace_once(
    s,
    "class _HeaderMenuRow extends StatelessWidget {",
    section_class + "class _HeaderMenuRow extends StatelessWidget {",
    "menu section widget",
)
write(p, s)

# 5) Guard the instant listing-video work from accidental regression while this
# UI patch is applied. These strings represent the important warm/carry behavior.
qf = read("lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart")
card = read("lib/src/features/swipes/presentation/widgets/cap_swipe_card.dart")
handoff = read("lib/src/features/swipes/presentation/providers/swipe_deck_media_handoff.dart")
for needle, body, label in [
    ("preparation: preparation", qf, "cold video preparation handoff"),
    ("controller: existing", qf, "live player transfer"),
    ("if (!controller.value.isPlaying && handoff.position > Duration.zero)", card, "no rewind while playing"),
    ("Icons.pause_rounded", card, "listing play pause control"),
    ("final Future<void>? preparation;", handoff, "in-flight player contract"),
]:
    if needle not in body:
        raise SystemExit(f"instant video regression guard failed: {label}")
