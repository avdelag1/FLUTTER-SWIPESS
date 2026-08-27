from pathlib import Path
import re

map_path = Path('lib/src/features/map/presentation/screens/real_mapbox_screen_v3.dart')
text = map_path.read_text()

const_anchor = "import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';\n"
const_block = """import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

const _swipessGitSha = String.fromEnvironment(
  'SWIPESS_GIT_SHA',
  defaultValue: 'unknown',
);
const _swipessBuildNumber = String.fromEnvironment(
  'SWIPESS_BUILD_NUMBER',
  defaultValue: 'unknown',
);
"""
if "const _swipessGitSha" not in text:
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
        """    final shortSha = _swipessGitSha.length > 12
        ? _swipessGitSha.substring(0, 12)
        : _swipessGitSha;
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
              'Build $_swipessBuildNumber • $shortSha',
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
elif "Build $_swipessBuildNumber" not in text:
    raise SystemExit('Map menu close-row anchor not found')
map_path.write_text(text)

pubspec = Path('pubspec.yaml')
ptext = pubspec.read_text()
ptext, count = re.subn(r'^version:\s*[^\n]+$', 'version: 1.2.42+636', ptext, count=1, flags=re.M)
if count != 1:
    raise SystemExit('pubspec version line not found')
pubspec.write_text(ptext)

cm = Path('codemagic.yaml')
ctext = cm.read_text()
trigger_anchor = """    instance_type: mac_mini_m2

    environment:
"""
trigger_block = """    instance_type: mac_mini_m2

    triggering:
      events:
        - push
      branch_patterns:
        - pattern: 'main'
          include: true
          source: true
      cancel_previous_builds: true

    environment:
"""
ios_prefix = ctext.split('  swipess-android-playstore:', 1)[0]
if '    triggering:\n' not in ios_prefix:
    if trigger_anchor not in ctext:
        raise SystemExit('Codemagic iOS trigger anchor not found')
    ctext = ctext.replace(trigger_anchor, trigger_block, 1)

scripts_anchor = """    scripts:
      - name: Get Flutter packages
"""
verify_script = """    scripts:
      - name: Verify exact GitHub main revision
        script: |
          set -euo pipefail
          if [ "${CM_BRANCH:-}" != "main" ]; then
            echo "Refusing iOS release from branch: ${CM_BRANCH:-unknown}"
            exit 1
          fi
          SWIPESS_GIT_SHA="$(git rev-parse HEAD)"
          echo "SWIPESS_GIT_SHA=$SWIPESS_GIT_SHA" >> "$CM_ENV"
          echo "SWIPESS_BUILD_NUMBER=636" >> "$CM_ENV"
          echo "Building exact Git commit: $SWIPESS_GIT_SHA"
          grep -q '^version: 1.2.42+636$' pubspec.yaml
          test -z "$(git status --porcelain)" || { git status --short; exit 1; }

      - name: Get Flutter packages
"""
ios_prefix = ctext.split('  swipess-android-playstore:', 1)[0]
if 'Verify exact GitHub main revision' not in ios_prefix:
    if scripts_anchor not in ctext:
        raise SystemExit('Codemagic scripts anchor not found')
    ctext = ctext.replace(scripts_anchor, verify_script, 1)

google_define = '            --dart-define=GOOGLE_IOS_CLIENT_ID="${GOOGLE_IOS_CLIENT_ID:-}"'
with_identity = google_define + ' \\\n            --dart-define=SWIPESS_GIT_SHA="$SWIPESS_GIT_SHA" \\\n            --dart-define=SWIPESS_BUILD_NUMBER="$SWIPESS_BUILD_NUMBER"'
ios_part, android_part = ctext.split('  swipess-android-playstore:', 1)
if 'SWIPESS_GIT_SHA="$SWIPESS_GIT_SHA"' not in ios_part:
    if google_define not in ios_part:
        raise SystemExit('Codemagic dart-define anchor not found')
    ios_part = ios_part.replace(google_define, with_identity)
ctext = ios_part + '  swipess-android-playstore:' + android_part

verify_anchor = """          unzip -q build/ios/ipa/*.ipa -d /tmp/swipess_ipa
          sh ios/ci_scripts/verify_release_bundle.sh /tmp/swipess_ipa/Payload/Runner.app
"""
verify_replacement = """          unzip -q build/ios/ipa/*.ipa -d /tmp/swipess_ipa
          APP=/tmp/swipess_ipa/Payload/Runner.app
          VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Info.plist")
          BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist")
          echo "IPA identity: version=$VERSION build=$BUILD commit=$SWIPESS_GIT_SHA"
          test "$VERSION" = "1.2.42"
          test "$BUILD" = "636"
          sh ios/ci_scripts/verify_release_bundle.sh "$APP"
"""
if 'IPA identity: version=' not in ctext:
    if verify_anchor not in ctext:
        raise SystemExit('Codemagic IPA verification anchor not found')
    ctext = ctext.replace(verify_anchor, verify_replacement, 1)
cm.write_text(ctext)
