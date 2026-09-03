from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text()


def write(path: str, text: str) -> None:
    Path(path).write_text(text)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing patch target: {label}")
    return text.replace(old, new, 1)


# 1) Make the floating dock visibly shorter/narrower while intentionally
# keeping a little horizontal overflow so users can slide it left/right.
p = "lib/src/features/dashboard/presentation/widgets/dashboard_dock.dart"
s = read(p)
s = replace_once(
    s,
    "constraints: const BoxConstraints(maxWidth: 420),",
    "constraints: const BoxConstraints(maxWidth: 342),",
    "dock max width",
)
s = replace_once(s, "                height: 52,", "                height: 46,", "dock height")
s = replace_once(
    s,
    "                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 4),",
    "                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 3),",
    "dock padding",
)
s = replace_once(
    s,
    "                              44.0,\n                          bottom: 0,\n                          width: 44.0,\n                          height: 44.0,",
    "                              40.0,\n                          bottom: 0,\n                          width: 40.0,\n                          height: 40.0,",
    "selected indicator geometry",
)
s = replace_once(
    s,
    "                              padding: EdgeInsets.only(bottom: 2),",
    "                              padding: EdgeInsets.only(bottom: 1),",
    "selected indicator padding",
)
s = replace_once(
    s,
    "                            SizedBox(\n                              width: 44,\n                              height: 44,",
    "                            SizedBox(\n                              width: 40,\n                              height: 40,",
    "dock item slot",
)
s = replace_once(
    s,
    "    return SizedBox(\n      width: 44,\n      height: 44,",
    "    return SizedBox(\n      width: 40,\n      height: 40,",
    "dock button visual size",
)
s = replace_once(s, "              radius: 19,", "              radius: 18,", "dock splash radius")
s = replace_once(
    s,
    "                              size: item.accent ? 23 : 21,",
    "                              size: item.accent ? 22 : 20,",
    "dock icon size",
)
write(p, s)


# 2) Give the burger menu a deliberate native-feeling open/close curve. The
# existing actions stay unchanged because Tokens, Premium, theme, notifications
# and Filters are already routed correctly.
p = "lib/src/core/widgets/app_top_bar.dart"
s = read(p)
s = replace_once(
    s,
    "          tooltip: 'Menu',\n          position: PopupMenuPosition.under,",
    "          tooltip: 'Menu',\n          popUpAnimationStyle: const AnimationStyle(\n            duration: Duration(milliseconds: 180),\n            reverseDuration: Duration(milliseconds: 130),\n            curve: Curves.easeOutCubic,\n            reverseCurve: Curves.easeInCubic,\n          ),\n          position: PopupMenuPosition.under,",
    "burger popup animation",
)
s = replace_once(
    s,
    "          onOpened: AppHaptics.light,",
    "          enableFeedback: true,\n          onOpened: AppHaptics.light,",
    "burger feedback",
)
write(p, s)


# 3) Raise the dedicated listing-camera capture/gallery JPEG quality while
# keeping dimensions bounded enough for fast uploads and memory-safe previews.
p = "lib/src/features/camera/presentation/screens/listing_camera_screen.dart"
s = read(p)
s = replace_once(
    s,
    "        imageQuality: 88,\n        preferredCameraDevice: CameraDevice.rear,",
    "        imageQuality: 93,\n        maxWidth: 2880,\n        maxHeight: 2880,\n        preferredCameraDevice: CameraDevice.rear,",
    "camera photo quality",
)
s = replace_once(
    s,
    "        imageQuality: 88,\n        limit: _remaining,",
    "        imageQuality: 93,\n        maxWidth: 2880,\n        maxHeight: 2880,\n        limit: _remaining,",
    "gallery photo quality",
)
write(p, s)
