import re

with open('lib/src/features/add/presentation/screens/add_listing_screen.dart', 'r') as f:
    text = f.read()

# Replace body: ListView(
# with body: SafeArea(child: ListView(
text = text.replace('body: ListView(', 'body: SafeArea(\n        child: ListView(')

# And we need to add a closing parenthesis for SafeArea.
# Wait, let's just find the closing bracket for body: ListView
# Actually, the quickest way is regex or manual replace.
