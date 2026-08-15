import re

# 1. Fix Top Padding in Bento Dashboard
bento_path = "lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart"
with open(bento_path, "r") as f:
    bento = f.read()

# Replace padding
bento = re.sub(
    r"padding: const EdgeInsets\.fromLTRB\(16, 24, 16, 16\),",
    r"padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 72, 16, 16),",
    bento
)

# Replace CategoryChip container background
bento = re.sub(
    r"color: selected \? Colors\.black\.withAlpha\(20\) : Colors\.white12,",
    r"color: selected ? Colors.black.withAlpha(20) : spec.color.withOpacity(0.2),",
    bento
)

with open(bento_path, "w") as f:
    f.write(bento)

# 2. Fix Tokens Icon in App Top Bar
topbar_path = "lib/src/core/widgets/app_top_bar.dart"
with open(topbar_path, "r") as f:
    topbar = f.read()

# Replace multi-line Icons.generating_tokens_rounded with Icons.stars_rounded
topbar = re.sub(
    r"Icons\s*\.\s*generating_tokens_rounded",
    r"Icons.stars_rounded",
    topbar
)

with open(topbar_path, "w") as f:
    f.write(topbar)
