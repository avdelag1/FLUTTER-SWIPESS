import os

def replace_in_file(path, old, new):
    if not os.path.exists(path): return
    with open(path, 'r') as f:
        content = f.read()
    content = content.replace(old, new)
    with open(path, 'w') as f:
        f.write(content)

# 1. client_swipe_container.dart
replace_in_file(
    'lib/src/features/swipes/presentation/screens/client_swipe_container.dart',
    'final listingsAsync = ref.watch(swipeListingsProvider(widget.categoryId));',
    'final listingsAsync = ref.watch(swipeListingsProvider(widget.categoryId));\n    final profile = ref.watch(currentProfileProvider).value;\n    final authUser = profile?.userId;'
)

# 2. app_theme.dart
old_glass_pill = """  static BoxDecoration glassPill() => cinematicGlassDecoration.copyWith(
        borderRadius: BorderRadius.circular(100),
      );"""

new_glass_pill = """  static BoxDecoration glassPill({bool glowing = false}) {
    final base = cinematicGlassDecoration.copyWith(
      borderRadius: BorderRadius.circular(100),
    );
    if (!glowing) return base;
    return base.copyWith(
      boxShadow: [
        if (base.boxShadow != null) ...base.boxShadow!,
        BoxShadow(
          color: brandPrimary.withAlpha(100),
          blurRadius: 16,
          spreadRadius: 2,
        ),
      ],
    );
  }"""

replace_in_file(
    'lib/src/core/theme/app_theme.dart',
    old_glass_pill,
    new_glass_pill
)

print("Patched!")
