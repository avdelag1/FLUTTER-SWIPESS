#!/usr/bin/env bash
# Vercel install: clone Flutter (no SDK on the image) and fetch pub packages.
set -euo pipefail

if [[ ! -x flutter/bin/flutter ]]; then
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git flutter
fi

./flutter/bin/flutter config --no-analytics --enable-web
./flutter/bin/flutter precache --web
./flutter/bin/flutter pub get
