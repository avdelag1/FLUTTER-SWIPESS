#!/usr/bin/env bash
# Static deployment regression check that does not require the Flutter SDK.
set -euo pipefail

build_script="tool/vercel_build.sh"

test -x "$build_script"
grep -Fq 'add_public_define MAPBOX_ACCESS_TOKEN' "$build_script"
grep -Fq 'VITE_MAPBOX_TOKEN' "$build_script"
grep -Fq 'add_public_define GOOGLE_SERVER_CLIENT_ID' "$build_script"
grep -Fq 'flutter build "${build_args[@]}"' "$build_script"
grep -Fq -- '--no-wasm-dry-run' "$build_script"

if grep -Eq 'pk\.[A-Za-z0-9._-]{20,}|ghp_[A-Za-z0-9]{20,}' \
  "$build_script" lib/src/core/config/app_config.dart; then
  echo "A credential-like value was committed to deployment configuration." >&2
  exit 1
fi

echo "Vercel compile-time configuration wiring is present and secret-free."
