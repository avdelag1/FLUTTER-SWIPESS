from pathlib import Path

p = Path('lib/src/features/events/presentation/screens/events_screen.dart')
s = p.read_text()

top_start = '''              IgnorePointer(
                ignoring: !_eventChromeVisible,
                child: AnimatedOpacity(
                  opacity: _eventChromeVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: AnimatedSlide(
                    offset: _eventChromeVisible
                        ? Offset.zero
                        : const Offset(0, -0.08),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Positioned.fill(
                      child: Stack(
'''
top_replacement = '''              if (_eventChromeVisible)
                Positioned.fill(
                  child: Stack(
'''
if top_start not in s:
    raise SystemExit('Events top chrome compositor anchor not found')
s = s.replace(top_start, top_replacement, 1)

top_end = '''                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 14,
'''
top_end_replacement = '''                    ],
                  ),
                ),
              Positioned(
                right: 14,
'''
if top_end not in s:
    raise SystemExit('Events top chrome compositor closing anchor not found')
s = s.replace(top_end, top_end_replacement, 1)

story_start = '''          IgnorePointer(
            ignoring: !widget.chromeVisible,
            child: AnimatedOpacity(
              opacity: widget.chromeVisible ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: Stack(
                fit: StackFit.expand,
'''
story_replacement = '''          if (widget.chromeVisible)
            Stack(
              fit: StackFit.expand,
'''
if story_start not in s:
    raise SystemExit('Event story compositor anchor not found')
s = s.replace(story_start, story_replacement, 1)

story_end = '''                ],
              ),
            ),
          ),
        ],
      ),
'''
story_end_replacement = '''              ],
            ),
        ],
      ),
'''
if story_end not in s:
    raise SystemExit('Event story compositor closing anchor not found')
s = s.replace(story_end, story_end_replacement, 1)

region = s[s.find('class EventsScreen'):s.find('class _RailBtn')]
if 'AnimatedOpacity(' in region or 'AnimatedSlide(' in region:
    raise SystemExit('A full-screen animated compositor still remains in Events')

p.write_text(s)
print('Events chrome now uses direct conditional painting; no full-screen opacity/scrim compositor remains.')
