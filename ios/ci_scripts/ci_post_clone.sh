#!/bin/sh
# Fail this script if any command fails.
set -e

# The default execution directory of this script is the ci_scripts directory.
cd $CI_PRIMARY_REPOSITORY_PATH

# Clone Flutter
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $WORKSPACE/flutter
export PATH="$PATH:$WORKSPACE/flutter/bin"

# Install Flutter dependencies and build iOS
flutter precache --ios
flutter pub get
HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
cd ios
pod install
