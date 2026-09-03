#!/usr/bin/env bash
# Vercel install: install the pinned video worker dependencies, then clone
# Flutter (no SDK on the image) and fetch pub packages.
set -euo pipefail

if [[ -f package-lock.json ]]; then
  npm ci --omit=dev --no-audit --no-fund
else
  # Keep builds usable during the one-time lockfile bootstrap commit.
  npm install --omit=dev --no-audit --no-fund
fi

if [[ ! -x flutter/bin/flutter ]]; then
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git flutter
fi

./flutter/bin/flutter config --no-analytics --enable-web
./flutter/bin/flutter precache --web
./flutter/bin/flutter pub get
