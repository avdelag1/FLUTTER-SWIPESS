#!/usr/bin/env bash
# Vercel build: emit static files to build/web (the Output Directory).
set -euo pipefail

export PATH="$PWD/flutter/bin:$PATH"

if [[ ! -x flutter/bin/flutter ]]; then
  echo "Flutter SDK missing — installCommand must run tool/vercel_install.sh" >&2
  exit 1
fi

# Vercel environment variables are shell variables, while Flutter's
# String.fromEnvironment values are compile-time constants. Forward only the
# supported public client configuration as dart-defines; never write it to a
# generated file or echo its value into the build log.
build_args=(web --release --no-wasm-dry-run)

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

# Fail on Dart syntax/type errors before spending minutes compiling dart2js.
flutter analyze --no-pub
flutter build "${build_args[@]}"

# Flutter may skip dotfolders. Host Apple / Android association files
# at /.well-known so Universal Links do not fall through to index.html.
mkdir -p build/web/.well-known
cp web/well-known/apple-app-site-association build/web/.well-known/apple-app-site-association
cp web/well-known/apple-app-site-association build/web/apple-app-site-association
cp web/well-known/assetlinks.json build/web/.well-known/assetlinks.json
cp web/account-deletion.html build/web/account-deletion.html

test -f build/web/index.html
test -f build/web/flutter_bootstrap.js
test -f build/web/.well-known/apple-app-site-association
