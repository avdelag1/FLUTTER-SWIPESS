#!/usr/bin/env bash
# Vercel build: emit static files to build/web (the Output Directory).
# Production redeploy trigger for the 2026-09-02 video editor audio + 60s trim release.
set -euo pipefail

export PATH="$PWD/flutter/bin:$PATH"

if [[ ! -x flutter/bin/flutter ]]; then
  echo "Flutter SDK missing — installCommand must run tool/vercel_install.sh" >&2
  exit 1
fi

# Vercel environment variables are shell variables, while Flutter's
# String.fromEnvironment values are compile-time constants. Forward only the
# supported public client configuration as dart-defines. Never echo token values
# into build logs.
build_args=(web --release)

# Accept the legacy Capacitor/Vite variable names during the migration, while
# compiling one canonical key that AppConfig reads.
MAPBOX_ACCESS_TOKEN="${MAPBOX_ACCESS_TOKEN:-${MAPBOX_TOKEN:-${VITE_MAPBOX_TOKEN:-}}}"

add_public_define() {
  local name="$1"
  local value="${!name:-}"
  if [[ -n "$value" ]]; then
    build_args+=("--dart-define=${name}=${value}")
    echo "Flutter config: ${name} is configured"
  else
    echo "Flutter config: ${name} is not configured"
  fi
}

add_public_define MAPBOX_ACCESS_TOKEN
add_public_define GOOGLE_SERVER_CLIENT_ID
add_public_define GOOGLE_IOS_CLIENT_ID

flutter build "${build_args[@]}"

# Replace Flutter's cache-first generated service worker with the Swipess
# freshness-first worker. Installed PWAs must follow the current production
# bundle instead of pinning main.dart.js/assets from a previous deployment.
cp web/swipess_service_worker.js build/web/flutter_service_worker.js

# Mapbox `pk.` access tokens are public client configuration. Publish the same
# token already embedded in the web app as a tiny runtime config file so native
# Xcode/TestFlight builds can configure Mapbox even when they were archived
# without Flutter --dart-define arguments. Do not publish secret (`sk.`) tokens.
if [[ -n "$MAPBOX_ACCESS_TOKEN" && "$MAPBOX_ACCESS_TOKEN" == pk.* ]]; then
  MAPBOX_ACCESS_TOKEN="$MAPBOX_ACCESS_TOKEN" python3 - <<'PY'
import json
import os
from pathlib import Path

Path('build/web/mapbox-config.json').write_text(
    json.dumps({'mapboxAccessToken': os.environ['MAPBOX_ACCESS_TOKEN']}),
    encoding='utf-8',
)
PY
  echo "Flutter config: native Mapbox runtime config published"
else
  rm -f build/web/mapbox-config.json
  echo "Flutter config: native Mapbox runtime config not published"
fi

# Flutter may skip dotfolders. Host Apple / Android association files
# at /.well-known so Universal Links do not fall through to index.html.
mkdir -p build/web/.well-known
cp web/well-known/apple-app-site-association build/web/.well-known/apple-app-site-association
cp web/well-known/apple-app-site-association build/web/apple-app-site-association
cp web/well-known/assetlinks.json build/web/.well-known/assetlinks.json
cp web/account-deletion.html build/web/account-deletion.html

test -f build/web/index.html
test -f build/web/flutter_bootstrap.js
test -f build/web/flutter_service_worker.js
test -f build/web/.well-known/apple-app-site-association
