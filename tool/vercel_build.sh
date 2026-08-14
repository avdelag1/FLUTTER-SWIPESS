#!/usr/bin/env bash
# Vercel build: emit static files to build/web (the Output Directory).
set -euo pipefail

export PATH="$PWD/flutter/bin:$PATH"

if [[ ! -x flutter/bin/flutter ]]; then
  echo "Flutter SDK missing — installCommand must run tool/vercel_install.sh" >&2
  exit 1
fi

# dart_defines.json is gitignored. Supabase falls back to the prod project
# baked into lib/src/core/services/supabase_service.dart.
flutter build web --release

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
