import os

PROJECT_ROOT = "/Users/alejandrovillarreal/Documents/FUTTER SWIPESS"
swipe_container_path = os.path.join(PROJECT_ROOT, "lib/src/features/swipes/presentation/screens/client_swipe_container.dart")
swipeable_card_stack_path = os.path.join(PROJECT_ROOT, "lib/src/features/swipes/presentation/widgets/swipeable_card_stack.dart")
swipe_card_path = os.path.join(PROJECT_ROOT, "lib/src/features/swipes/presentation/widgets/swipe_card.dart")

# Fix ClientSwipeContainer
with open(swipe_container_path, 'r') as f:
    content = f.read()

content = content.replace(
    "primaryImage: 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9'", 
    "images: ['https://images.unsplash.com/photo-1600596542815-ffad4c1539a9']"
)
content = content.replace(
    "primaryImage: 'https://images.unsplash.com/photo-1603584173870-7f23fdae1b7a'", 
    "images: ['https://images.unsplash.com/photo-1603584173870-7f23fdae1b7a']"
)
content = content.replace(
    "primaryImage: 'https://images.unsplash.com/photo-1567899378494-47b22a2ae96a'", 
    "images: ['https://images.unsplash.com/photo-1567899378494-47b22a2ae96a']"
)

with open(swipe_container_path, 'w') as f:
    f.write(content)

# Fix SwipeableCardStack
with open(swipeable_card_stack_path, 'r') as f:
    content = f.read()

content = content.replace(
    "..scaleByDouble(scale)",
    "..scale(scale, scale, scale)"
)
content = content.replace(
    "..scaleByDouble(1.0 - (_swipeProgress * 0.07))",
    "..scale(1.0 - (_swipeProgress * 0.07), 1.0 - (_swipeProgress * 0.07), 1.0 - (_swipeProgress * 0.07))"
)
content = content.replace(
    "if (direction == SwipeDirection.right) HapticFeedback.heavyImpact();\n      else HapticFeedback.mediumImpact();",
    "if (direction == SwipeDirection.right) { HapticFeedback.heavyImpact(); } else { HapticFeedback.mediumImpact(); }"
)
content = content.replace("..translate(_dragOffset.dx, _dragOffset.dy)", "..setTranslationRaw(_dragOffset.dx, _dragOffset.dy, 0.0)")

with open(swipeable_card_stack_path, 'w') as f:
    f.write(content)

# Fix SwipeCard unused import and null-aware
with open(swipe_card_path, 'r') as f:
    content = f.read()

content = content.replace("import 'package:flutter_swipes/src/core/theme/app_theme.dart';\n", "")
content = content.replace("if (overlay != null) overlay!,", "overlay ?? const SizedBox.shrink(),")

with open(swipe_card_path, 'w') as f:
    f.write(content)

print("Deck issues fixed")
