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
