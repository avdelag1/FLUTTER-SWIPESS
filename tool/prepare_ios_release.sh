#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

flutter clean
flutter pub get

build_args=(ios --config-only --release --no-codesign)
if [[ -f dart_defines.json ]]; then
  build_args+=(--dart-define-from-file=dart_defines.json)
  echo "iOS release config: using local dart_defines.json"
else
  echo "iOS release config: no local dart_defines.json; Mapbox will use Swipess runtime config/fallback"
fi

flutter build "${build_args[@]}"

(
  cd ios
  pod install
)

echo "Prepared iOS release configuration:"
grep -E '^(FLUTTER_BUILD_MODE|FLUTTER_BUILD_NAME|FLUTTER_BUILD_NUMBER)=' \
  ios/Flutter/Generated.xcconfig || true
