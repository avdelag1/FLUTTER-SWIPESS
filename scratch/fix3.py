import os

def replace_in_file(path, old, new):
    if not os.path.exists(path): return
    with open(path, 'r') as f:
        content = f.read()
    content = content.replace(old, new)
    with open(path, 'w') as f:
        f.write(content)

# 1. app_router.dart
replace_in_file(
    'lib/src/core/routing/app_router.dart',
    'GoRoute(path: \'/auth\', builder: (ctx, _) => const AuthScreen()),',
    'GoRoute(path: \'/auth\', builder: (ctx, _) => const AuthScreen(mode: \'login\')),'
)

# 2. app_theme.dart
theme_additions = """
  static BorderRadius get radiusCard => BorderRadius.circular(24);
  static TextStyle get kicker => GoogleFonts.plusJakartaSans(color: brandAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2);
  static BoxDecoration get bottomDockDecoration => BoxDecoration(
        color: dashWell.withOpacity(0.8),
        borderRadius: BorderRadius.circular(32),
      );
  static TextStyle get buttonLabel => GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold);
  static const Color inputFill = Color(0x1AFFFFFF);
"""
replace_in_file(
    'lib/src/core/theme/app_theme.dart',
    '// Backward compatibility',
    theme_additions + '\n  // Backward compatibility'
)

# 3. chat_room_screen.dart
replace_in_file(
    'lib/src/features/messages/presentation/screens/chat_room_screen.dart',
    'message.messageText',
    'message.text'
)

# 4. events_screen.dart
# We need to see what Event has. If it doesn't have price, let's use ''
replace_in_file(
    'lib/src/features/events/presentation/screens/events_screen.dart',
    'meta: event.price,',
    'meta: \'\', // event.price missing'
)
replace_in_file(
    'lib/src/features/events/presentation/screens/events_screen.dart',
    'imageUrl: event.imageUrl,',
    'imageUrl: event.imageUrl ?? \'\','
)

# 5. profile_providers.dart
replace_in_file(
    'lib/src/features/profile/presentation/providers/profile_providers.dart',
    'class CurrentProfileNotifier extends AsyncNotifier<Profile?> {',
    'class CurrentProfileNotifier extends AsyncNotifier<UserProfile?> {'
)
replace_in_file(
    'lib/src/features/profile/presentation/providers/profile_providers.dart',
    'Future<Profile?> build() async {',
    'Future<UserProfile?> build() async {'
)
replace_in_file(
    'lib/src/features/profile/presentation/providers/profile_providers.dart',
    'final currentProfileProvider = AsyncNotifierProvider<CurrentProfileNotifier, Profile?>(',
    'final currentProfileProvider = AsyncNotifierProvider<CurrentProfileNotifier, UserProfile?>('
)
replace_in_file(
    'lib/src/features/profile/presentation/providers/profile_providers.dart',
    'import \'package:flutter_swipes/src/features/profile/domain/models/profile.dart\';',
    'import \'package:flutter_swipes/src/features/profile/domain/models/user_profile.dart\';'
)

# 6. glow_search_bar.dart
replace_in_file(
    'lib/src/core/widgets/glow_search_bar.dart',
    'final bool glowing;',
    'final bool? glowing;'
)
replace_in_file(
    'lib/src/core/widgets/glow_search_bar.dart',
    'this.glowing = false,',
    'this.glowing,'
)

print("Patched!")
