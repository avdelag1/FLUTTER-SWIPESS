#!/usr/bin/env bash
set -euo pipefail

if command -v flutter >/dev/null 2>&1; then
  FLUTTER_BIN="$(command -v flutter)"
elif [[ -x "$PWD/flutter/bin/flutter" ]]; then
  FLUTTER_BIN="$PWD/flutter/bin/flutter"
else
  cat >&2 <<'EOF'
Flutter SDK not found.

Options:
  1. Install Flutter globally and put flutter/bin on PATH.
  2. Run tool/vercel_install.sh to install the repo-local flutter/bin SDK.
  3. Push a PR and let .github/workflows/flutter_checks.yml run in GitHub.
EOF
  exit 127
fi

"$FLUTTER_BIN" pub get
if [[ "${VERIFY_FORMAT:-0}" == "1" ]]; then
  if command -v dart >/dev/null 2>&1; then
    DART_BIN="$(command -v dart)"
  else
    DART_BIN="$(dirname "$FLUTTER_BIN")/dart"
  fi
  if [[ ! -x "$DART_BIN" ]]; then
    echo "Dart executable not found next to Flutter; add dart to PATH." >&2
    exit 127
  fi
  "$DART_BIN" format --output=none --set-exit-if-changed lib test
fi
"$FLUTTER_BIN" analyze
"$FLUTTER_BIN" test

if [[ "${VERIFY_WEB_BUILD:-0}" == "1" ]]; then
  "$FLUTTER_BIN" build web --release
fi
