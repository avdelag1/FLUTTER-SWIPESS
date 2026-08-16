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

# Always regenerate the iOS launcher icon from the single authoritative source
# before Xcode archives the app. This prevents Xcode Cloud from shipping stale
# AppIcon files left over from an older local build.
dart run flutter_launcher_icons

echo "Launcher icons regenerated from assets/app_icon.png"

HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
cd ios
pod install