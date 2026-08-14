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

test -f build/web/index.html
test -f build/web/flutter_bootstrap.js
