import re

with open('lib/src/features/dashboard/presentation/widgets/dashboard_dock.dart', 'r') as f:
    text = f.read()

# Replace the decoration with a ClipRRect + BackdropFilter wrapper
old_container = """                height: 52,
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  // Frozen glass without a live backdrop blur. This keeps the
                  // icy/glassy depth while avoiding continuous GPU blur over
                  // dashboard videos.
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isLight
                        ? const [
                            Color(0xFAFFFFFF),
                            Color(0xE7E1E8F0),
                            Color(0xF7F9FBFF),
                          ]
                        : const [
                            Color(0xF24A515B),
                            Color(0xEB252B33),
                            Color(0xF0353C46),
                          ],
                    stops: const [0, .55, 1],
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isLight
                        ? Colors.white.withAlpha(245)
                        : Colors.white.withAlpha(112),
                    width: 1.2,
                  ),
                ),
                child: SingleChildScrollView("""

new_container = """                height: 54,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isLight
                            ? Colors.white.withAlpha(180)
                            : Colors.black.withAlpha(140),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white,
                          width: 2.0,
                        ),
                      ),
                      child: SingleChildScrollView("""

text = text.replace(old_container, new_container)

# Add import for ImageFilter if not present
if 'import \'dart:ui\';' not in text:
    text = "import 'dart:ui';\n" + text

with open('lib/src/features/dashboard/presentation/widgets/dashboard_dock.dart', 'w') as f:
    f.write(text)
