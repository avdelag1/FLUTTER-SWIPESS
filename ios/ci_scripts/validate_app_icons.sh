#!/bin/sh
# Flatten transparency out of the iOS AppIcon set and verify it is App Store
# safe. App Store Connect rejects icons with an alpha channel and requires a
# 1024x1024 marketing icon, which surfaces as a "Prepare Build for App Store
# Connect failed" error long after the archive itself succeeded.
set -e

ICON_DIR="ios/Runner/Assets.xcassets/AppIcon.appiconset"
MARKETING_ICON="$ICON_DIR/Icon-App-1024x1024@1x.png"

if [ ! -f "$MARKETING_ICON" ]; then
    echo "error: missing $MARKETING_ICON" >&2
    exit 1
fi

for icon in "$ICON_DIR"/*.png; do
    if [ "$(sips -g hasAlpha "$icon" | awk '/hasAlpha/ {print $2}')" = "yes" ]; then
        echo "flattening alpha channel out of $icon"
        sips -s format png -s formatOptions best --setProperty hasAlpha false "$icon" --out "$icon" >/dev/null
    fi

    if [ "$(sips -g hasAlpha "$icon" | awk '/hasAlpha/ {print $2}')" = "yes" ]; then
        echo "error: $icon still has an alpha channel" >&2
        exit 1
    fi
done

WIDTH=$(sips -g pixelWidth "$MARKETING_ICON" | awk '/pixelWidth/ {print $2}')
HEIGHT=$(sips -g pixelHeight "$MARKETING_ICON" | awk '/pixelHeight/ {print $2}')

if [ "$WIDTH" != "1024" ] || [ "$HEIGHT" != "1024" ]; then
    echo "error: marketing icon must be 1024x1024, got ${WIDTH}x${HEIGHT}" >&2
    exit 1
fi

echo "AppIcon set is App Store safe: opaque icons, ${WIDTH}x${HEIGHT} marketing icon"
