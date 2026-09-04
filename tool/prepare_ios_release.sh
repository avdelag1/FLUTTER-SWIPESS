#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

IOS_MIN_VERSION="15.0"
SWIFTPM_MANIFEST="ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"

flutter clean
flutter pub get

# Flutter 3.44+ uses SwiftPM for supported plugins. `flutter pub get` can
# regenerate FlutterGeneratedPluginSwiftPackage with Flutter's default iOS
# minimum (13.0), even though Runner is configured for iOS 15. Running the
# config-only iOS build applies Flutter's deployment-target migration before
# Xcode resolves packages.
build_args=(ios --config-only --release --no-codesign)
if [[ -f dart_defines.json ]]; then
  build_args+=(--dart-define-from-file=dart_defines.json)
  echo "iOS release config: using local dart_defines.json"
else
  echo "iOS release config: no local dart_defines.json; Mapbox will use Swipess runtime config/fallback"
fi

flutter build "${build_args[@]}"

# Defensive fallback for the known Flutter SwiftPM regeneration issue. Xcode
# resolves Swift packages before build pre-actions, so make sure the generated
# aggregate package advertises the same minimum iOS version as Runner.
if [[ -f "$SWIFTPM_MANIFEST" ]]; then
  python3 - "$SWIFTPM_MANIFEST" "$IOS_MIN_VERSION" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
minimum = sys.argv[2]
text = path.read_text()
updated, count = re.subn(r'\.iOS\("[0-9.]+"\)', f'.iOS("{minimum}")', text, count=1)
if count:
    path.write_text(updated)

check = path.read_text()
expected = f'.iOS("{minimum}")'
if expected not in check:
    raise SystemExit(f"SwiftPM deployment target was not updated to iOS {minimum}: {path}")
print(f"SwiftPM deployment target verified: iOS {minimum}")
PY
fi

(
  cd ios
  pod install
)

python3 - "$ROOT/dart_defines.json" "$ROOT/ios/Runner/Info.plist" <<'PY'
import json
import plistlib
import sys
from pathlib import Path

defines_path = Path(sys.argv[1])
plist_path = Path(sys.argv[2])
if not defines_path.exists():
    print("Native Google Sign-In: no dart_defines.json; skipping local plist inject")
    raise SystemExit(0)

data = json.loads(defines_path.read_text())
client_id = str(data.get("GOOGLE_IOS_CLIENT_ID") or "").strip()
if not client_id.endswith(".apps.googleusercontent.com"):
    print("Native Google Sign-In: GOOGLE_IOS_CLIENT_ID missing or invalid in dart_defines.json")
    raise SystemExit(0)

reversed_id = "com.googleusercontent.apps." + client_id.removesuffix(".apps.googleusercontent.com")
plist = plistlib.loads(plist_path.read_bytes())
url_types = [item for item in plist.get("CFBundleURLTypes", []) if item.get("CFBundleURLName") != "google-sign-in"]
url_types.append({
    "CFBundleTypeRole": "Editor",
    "CFBundleURLName": "google-sign-in",
    "CFBundleURLSchemes": [reversed_id],
})
plist["CFBundleURLTypes"] = url_types
plist["GIDClientID"] = client_id
plist_path.write_bytes(plistlib.dumps(plist))
print("Native Google Sign-In: local Info.plist callback and GIDClientID configured")
PY

echo "Prepared iOS release configuration:"
grep -E '^(FLUTTER_BUILD_MODE|FLUTTER_BUILD_NAME|FLUTTER_BUILD_NUMBER)=' \
  ios/Flutter/Generated.xcconfig || true

echo "iOS minimum deployment target: $IOS_MIN_VERSION"
echo "Ready to open ios/Runner.xcworkspace in Xcode and Archive."
