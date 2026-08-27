import 'dart:io';

void main() {
  var file = File('lib/src/core/widgets/app_top_bar.dart');
  var content = file.readAsStringSync();
  
  // 1. Add imports if missing
  if (!content.contains("import 'dart:async';")) {
    content = "import 'dart:async';\nimport 'dart:math' as math;\n" + content;
  }
  
  // 2. Replace the Row containing children with the new layout
  var startStr = '''        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [''';
          
  var endStr = '''              ],
            ),
          ],
        ),
      ),
    );
  }
}''';

  var startIndex = content.indexOf(startStr);
  var endIndex = content.indexOf(endStr, startIndex) + endStr.length;
  
  var newLayout = '''        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isProfileRoute)
                  _HudButton(
                    key: const ValueKey('header-profile-back'),
                    semanticLabel: 'Back',
                    onTap: () => _backFromProfile(context),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: ink,
                    ),
                  )
                else
                  _HudButton(
                    key: const ValueKey('header-map'),
                    semanticLabel: 'Open map',
                    onTap: () {
                      AppHaptics.medium();
                      ref.read(overlayModalsProvider.notifier).openPassportMap();
                    },
                    child: _AnimatedWorldIcon(color: ink),
                  ),
                SizedBox(width: chromeGap),
                _HudButton(
                  key: const ValueKey('header-create'),
                  semanticLabel: 'Create a listing',
                  onTap: () {
                    AppHaptics.medium();
                    showCreateListingChooser(context);
                  },
                  child: Icon(Icons.add_rounded, size: 25, color: ink),
                ),
                SizedBox(width: chromeGap),
                _HudButton(
                  key: const ValueKey('header-tokens'),
                  semanticLabel:
                      'Open Direct Requests, available \$tokenSemanticLabel',
                  wide: true,
                  onTap: () {
                    AppHaptics.medium();
                    showGlassModal(
                      context: context,
                      builder: (_) => const TokensModal(),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        size: 21,
                        color: ink,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        tokensLabel,
                        style: GoogleFonts.plusJakartaSans(
                          color: ink,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HudButton(
                  key: const ValueKey('header-notifications'),
                  semanticLabel: 'Open notifications',
                  onTap: () {
                    AppHaptics.medium();
                    showGlassModal(
                      context: context,
                      builder: (_) => const NotificationsScreen(),
                    );
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 23,
                        color: ink,
                      ),
                      ref.watch(unreadNotificationsProvider).when(
                            data: (count) => count <= 0
                                ? const SizedBox.shrink()
                                : const Positioned(
                                    right: -1,
                                    top: -1,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: AppTheme.brandPrimary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: SizedBox(width: 7, height: 7),
                                    ),
                                  ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, _) => const SizedBox.shrink(),
                          ),
                    ],
                  ),
                ),
                SizedBox(width: chromeGap),
                _HudButton(
                  key: const ValueKey('header-theme'),
                  semanticLabel: isLight
                      ? 'Switch to dark appearance'
                      : 'Switch to light appearance',
                  onTap: () {
                    AppHaptics.medium();
                    ref.read(visualThemeProvider.notifier).toggle();
                  },
                  child: Icon(
                    isLight
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    size: 22,
                    color: ink,
                  ),
                ),
                if (!isProfileRoute) ...[
                  SizedBox(width: chromeGap),
                  _ProfileAvatarButton(
                    key: const ValueKey('header-profile'),
                    avatarUrl: avatarUrl,
                    seed: firstName ?? avatarUrl ?? 'swipess-you',
                    semanticLabel: 'Open profile, \$_label',
                    onTap: () => _openProfile(context),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}''';

  content = content.replaceRange(startIndex, endIndex, newLayout);
  
  // 3. Add _AnimatedWorldIcon class
  var animatedWorldIconClass = '''

class _AnimatedWorldIcon extends StatefulWidget {
  const _AnimatedWorldIcon({required this.color});
  final Color color;

  @override
  State<_AnimatedWorldIcon> createState() => _AnimatedWorldIconState();
}

class _AnimatedWorldIconState extends State<_AnimatedWorldIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scheduleNextShine();
  }

  void _scheduleNextShine() {
    // Random interval between 8 and 10 seconds
    final delay = Duration(seconds: 8 + _random.nextInt(3));
    _timer = Timer(delay, () {
      if (mounted) {
        _controller.forward(from: 0).then((_) => _scheduleNextShine());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // 0.0 to 1.0 back to 0.0 smoothly
        final intensity = math.sin(t * math.pi);
        
        return Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.public_rounded, size: 22, color: widget.color),
            if (intensity > 0)
              Opacity(
                opacity: intensity,
                child: Icon(
                  Icons.public_rounded,
                  size: 22,
                  color: AppTheme.brandPrimary, 
                ),
              ),
          ],
        );
      },
    );
  }
}
''';

  if (!content.contains('class _AnimatedWorldIcon')) {
    content += animatedWorldIconClass;
  }
  
  file.writeAsStringSync(content);
}
