#!/bin/sh
set -eu

APP_PATH="${1:-build/ios/iphoneos/Runner.app}"

if [ ! -d "$APP_PATH" ]; then
  echo "error: iOS app bundle not found at $APP_PATH" >&2
  exit 1
fi

# Flutter debug/JIT applications ship a kernel blob. App Store/TestFlight builds
# must be AOT release builds, so fail the release pipeline if one is present.
DEBUG_KERNEL="$(find "$APP_PATH" -name kernel_blob.bin -print -quit)"
if [ -n "$DEBUG_KERNEL" ]; then
  echo "error: debug Flutter artifact found in store bundle: $DEBUG_KERNEL" >&2
  echo "error: rebuild with: flutter build ipa --release" >&2
  exit 1
fi

PLIST="$APP_PATH/Info.plist"
if [ ! -f "$PLIST" ]; then
  echo "error: missing app Info.plist at $PLIST" >&2
  exit 1
fi

BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST" 2>/dev/null || true)"
BUILD_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST" 2>/dev/null || true)"

if [ -z "$BUILD_NUMBER" ] || [ -z "$BUILD_NAME" ]; then
  echo "error: release bundle is missing version/build metadata" >&2
  exit 1
fi

echo "Verified iOS AOT release bundle: $BUILD_NAME ($BUILD_NUMBER)"
