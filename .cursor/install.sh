#!/usr/bin/env bash
# Idempotent Cloud Agent install script for the Flutter Swipes app.
# Refreshes the Flutter toolchain (if missing) and project dependencies.
set -euo pipefail

FLUTTER_DIR="/home/ubuntu/flutter"
# Pinned to the Flutter revision recorded in .metadata (Flutter 3.44.9 / Dart 3.12.2).
FLUTTER_REV="6b182d2c7585eba26d4edce0f97630effd256c33"

# Install the Flutter SDK only if it is not already present (it is normally
# baked into the environment snapshot, so this is a fallback for a bare image).
if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  git clone https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
  git -C "${FLUTTER_DIR}" checkout "${FLUTTER_REV}"
fi

git config --global --add safe.directory "${FLUTTER_DIR}" || true
export PATH="${PATH}:${FLUTTER_DIR}/bin"

# Ensure the SDK is on PATH for interactive/login shells as well.
if [ ! -f /etc/profile.d/flutter.sh ]; then
  echo 'export PATH="$PATH:/home/ubuntu/flutter/bin"' | sudo tee /etc/profile.d/flutter.sh >/dev/null || true
fi

flutter config --enable-web --no-analytics >/dev/null
# Warm the web engine artifacts so the first `flutter run` is fast.
flutter precache --web >/dev/null 2>&1 || true

# Refresh project dependencies.
flutter pub get
