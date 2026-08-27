from pathlib import Path
import re

# Native iOS/Android map parity patch only. Codemagic is already configured to
# prove main/commit provenance, choose the next TestFlight build number, inject
# SWIPESS_BUILD_SHA/SWIPESS_BUILD_NUMBER, verify the IPA, and publish it.
map_path = Path('lib/src/features/map/presentation/screens/real_mapbox_screen_v3.dart')
text = map_path.read_text()

const_anchor = "import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';\n"
const_block = """import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

const _swipessBuildSha = String.fromEnvironment(
  'SWIPESS_BUILD_SHA',
  defaultValue: 'unknown',
);
const _swipessBuildNumber = String.fromEnvironment(
  'SWIPESS_BUILD_NUMBER',
  defaultValue: 'unknown',
);
const _swipessBuildChannel = String.fromEnvironment(
  'SWIPESS_BUILD_CHANNEL',
  defaultValue: 'local',
);
"""
if "const _swipessBuildSha" not in text:
    if const_anchor not in text:
        raise SystemExit('Mapbox import anchor not found')
    text = text.replace(const_anchor, const_block, 1)

old_top = """              child: Row(
                children: [
                  _IconOnly(
                    icon: _menu ? Icons.close_rounded : Icons.menu_rounded,
                    label: 'Map menu',
                    onTap: () => setState(() {
                      _menu = !_menu;
                      _cities = false;
                    }),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'SWIPESS',
"""
new_top = """              child: Row(
                children: [
                  _IconOnly(
                    icon: Icons.arrow_back_ios_new_rounded,
                    label: 'Back',
                    onTap: _closeMap,
                  ),
                  const SizedBox(width: 2),
                  _IconOnly(
                    icon: _menu ? Icons.close_rounded : Icons.menu_rounded,
                    label: 'Map menu',
                    onTap: () => setState(() {
                      _menu = !_menu;
                      _cities = false;
                    }),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'SWIPESS',
"""
if old_top in text:
    text = text.replace(old_top, new_top, 1)
elif "label: 'Back'" not in text:
    raise SystemExit('Native map top-row anchor not found')

old_search_tail = """                  _IconOnly(
                    icon: _search ? Icons.close_rounded : Icons.search_rounded,
                    label: 'Search map',
                    onTap: () => setState(() {
                      _search = !_search;
                      _menu = false;
                      _cities = false;
                    }),
                  ),
                ],
              ),
"""
new_search_tail = """                  _IconOnly(
                    icon: _search ? Icons.close_rounded : Icons.search_rounded,
                    label: 'Search map',
                    onTap: () => setState(() {
                      _search = !_search;
                      _menu = false;
                      _cities = false;
                    }),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
"""
if old_search_tail in text:
    text = text.replace(old_search_tail, new_search_tail, 1)

menu_return = """    return Container(
      width: 190,
"""
if "final shortSha =" not in text:
    if menu_return not in text:
        raise SystemExit('Map menu return anchor not found')
    text = text.replace(
        menu_return,
        """    final shortSha = _swipessBuildSha.length > 12
        ? _swipessBuildSha.substring(0, 12)
        : _swipessBuildSha;
    return Container(
      width: 190,
""",
        1,
    )

close_row = """        row(Icons.close_rounded, 'Close map', onClose),
      ]),
"""
fingerprint = """        row(Icons.close_rounded, 'Close map', onClose),
        const Divider(height: 10),
        Padding(
          padding: const EdgeInsets.fromLTRB(11, 2, 11, 7),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$_swipessBuildChannel • build $_swipessBuildNumber • $shortSha',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.black45,
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ]),
"""
if close_row in text:
    text = text.replace(close_row, fingerprint, 1)
elif "build $_swipessBuildNumber" not in text:
    raise SystemExit('Map menu close-row anchor not found')

map_path.write_text(text)

# Keep repository metadata aligned with the next expected build. Codemagic still
# resolves the real next TestFlight number from App Store Connect and overrides
# --build-number, so this cannot accidentally reuse an old TestFlight number.
pubspec = Path('pubspec.yaml')
ptext = pubspec.read_text()
ptext, count = re.subn(r'^version:\s*[^\n]+$', 'version: 1.2.42+636', ptext, count=1, flags=re.M)
if count != 1:
    raise SystemExit('pubspec version line not found')
pubspec.write_text(ptext)
