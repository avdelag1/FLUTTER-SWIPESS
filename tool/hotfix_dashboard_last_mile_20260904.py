from pathlib import Path

path = Path("lib/src/core/widgets/glow_search_bar.dart")
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    if old not in text:
        raise SystemExit(f"Missing target for {label}")
    text = text.replace(old, new, 1)


# Remove the rotating/marquee prompt machinery entirely. The AI field should
# stay calm and immediately readable with one short neutral prompt.
replace_once(
    "  Timer? _promptTimer;\n  int _promptIndex = 0;\n",
    "",
    "prompt state",
)

replace_once(
    """  List<String> get _rotatingPrompts {
    final adminPrompts = ref.watch(dashboardAiPromptsProvider).value;
    if (adminPrompts != null && adminPrompts.isNotEmpty) {
      return adminPrompts;
    }

    // Never show the old local-slang placeholder while remote copy is loading.
    // The editable neutral default is clearer for new users and avoids random
    // phrases appearing in the main search field.
    return defaultDashboardAiPrompts;
  }

""",
    "",
    "rotating prompts getter",
)

replace_once(
    "    _schedulePrompt();\n",
    "",
    "prompt schedule init",
)

replace_once(
    """    if (oldWidget.locationLabel != widget.locationLabel && mounted) {
      setState(() => _promptIndex = 0);
    }
""",
    "",
    "prompt reset",
)

replace_once(
    "    _promptTimer?.cancel();\n",
    "",
    "prompt timer dispose",
)

replace_once(
    """  void _schedulePrompt() {
    _promptTimer?.cancel();
    _promptTimer = Timer(const Duration(milliseconds: 12000), () {
      if (!mounted) return;
      if (_showPrompt) {
        final prompts = _rotatingPrompts;
        setState(() => _promptIndex = (_promptIndex + 1) % prompts.length);
      }
      _schedulePrompt();
    });
  }

""",
    "",
    "prompt scheduler",
)

replace_once(
    """    final prompts = _rotatingPrompts;
    final displayHint = prompts[_promptIndex % prompts.length];
""",
    "    const displayHint = 'What do you need?';\n",
    "build prompt source",
)

old_marquee = """                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final promptStyle =
                                      GoogleFonts.plusJakartaSans(
                                        color: ink.withAlpha(
                                          isLight ? 190 : 225,
                                        ),
                                        fontWeight: FontWeight.w600,
                                        fontSize: widget.compactHeader
                                            ? 12.5
                                            : 14.0,
                                      );
                                  final nextHint =
                                      prompts[(_promptIndex + 1) %
                                          prompts.length];
                                  const separator = '      •      ';
                                  final currentRun = '$displayHint$separator';
                                  final tickerText = '$currentRun$nextHint';
                                  final painter = TextPainter(
                                    text: TextSpan(
                                      text: currentRun,
                                      style: promptStyle,
                                    ),
                                    maxLines: 1,
                                    textDirection: Directionality.of(context),
                                  )..layout();
                                  final travel = painter.width;
                                  return ClipRect(
                                    child: TweenAnimationBuilder<double>(
                                      key: ValueKey<String>(displayHint),
                                      tween: Tween<double>(begin: 0, end: 1),
                                      duration: const Duration(
                                        milliseconds: 12000,
                                      ),
                                      curve: Curves.linear,
                                      builder: (context, progress, child) {
                                        return Transform.translate(
                                          offset: Offset(-travel * progress, 0),
                                          child: child,
                                        );
                                      },
                                      child: Text(
                                        tickerText,
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.visible,
                                        style: promptStyle,
                                      ),
                                    ),
                                  );
                                },
                              ),"""

new_static = """                              child: Text(
                                displayHint,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: ink.withAlpha(isLight ? 190 : 225),
                                  fontWeight: FontWeight.w600,
                                  fontSize: widget.compactHeader ? 12.5 : 14.0,
                                ),
                              ),"""
replace_once(old_marquee, new_static, "animated marquee")

path.write_text(text)
print("AI search prompt simplified to static: What do you need?")
