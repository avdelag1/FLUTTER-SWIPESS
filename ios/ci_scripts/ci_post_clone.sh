#!/bin/sh
set -e
set -x

cd "$CI_PRIMARY_REPOSITORY_PATH"

if [ ! -d "$HOME/flutter" ]; then
    git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
fi

export PATH="$PATH:$HOME/flutter/bin"

flutter precache --ios
flutter pub get

# Regenerate the iOS launcher icon from the single authoritative source
# (assets/app_icon.png, configured in pubspec.yaml) before Xcode archives the
# app, so the archive never ships stale AppIcon files from an older build.
dart run flutter_launcher_icons

# App Store Connect rejects app icons that carry an alpha channel, which is how
# "Prepare Build for App Store Connect" fails after a successful archive.
# Flatten any residual transparency and fail fast if an icon is still invalid.
sh ios/ci_scripts/validate_app_icons.sh

HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
cd ios
pod install
cd ..

# Flutter 3.35+ can leave the generated Xcode settings in debug mode after a
# debug run. Xcode Cloud archives the Xcode project directly, so regenerate the
# iOS configuration explicitly for RELEASE immediately before Xcode takes over.
# If a public Mapbox token is configured in Xcode Cloud, forward it as a Dart
# define. Disable shell tracing around the command so the token never appears in
# build logs. Store builds without the variable still work because the app can
# recover the public token from swipess.com at runtime and has a tile fallback.
if [ -n "${MAPBOX_ACCESS_TOKEN:-}" ]; then
    set +x
    flutter build ios --config-only --release --no-codesign \
        --dart-define="MAPBOX_ACCESS_TOKEN=$MAPBOX_ACCESS_TOKEN"
    set -x
else
    flutter build ios --config-only --release --no-codesign
fi

# Keep the generated mode visible in Xcode Cloud logs so a bad archive cannot be
# mistaken for a release build again. Never print DART_DEFINES here.
grep -E '^(FLUTTER_BUILD_MODE|FLUTTER_BUILD_NAME|FLUTTER_BUILD_NUMBER)=' ios/Flutter/Generated.xcconfig || true
