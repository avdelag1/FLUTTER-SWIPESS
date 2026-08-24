import re

with open('lib/src/core/widgets/glow_search_bar.dart', 'r') as f:
    code = f.read()

# Replace the mic badge logic
mic_badge_old = r'''                if \(_voiceActive\)\n                  BreathingWidget\(\n                    duration: const Duration\(milliseconds: 1050\),\n                    minOpacity: \.55,\n                    maxOpacity: 1,\n                    child: const Icon\(\n                      Icons\.mic_rounded,\n                      color: Colors\.white,\n                      size: 18,\n                    \),\n                  \)\n                else\n                  Icon\(Icons\.mic_rounded, color: blue, size: 18\),\n                if \(_countdown != null\)\n                  Positioned\(\n                    right: -5,\n                    top: -5,\n                    child: Container\(\n                      width: 18,\n                      height: 18,\n                      alignment: Alignment\.center,\n                      decoration: BoxDecoration\(\n                        color: Colors\.white,\n                        shape: BoxShape\.circle,\n                        border: Border\.all\(color: blue, width: 1\.3\),\n                      \),\n                      child: Text\(\n                        '\$_countdown',\n                        style: GoogleFonts\.plusJakartaSans\(\n                          color: blue,\n                          fontSize: 9,\n                          fontWeight: FontWeight\.w900,\n                          height: 1,\n                        \),\n                      \),\n                    \),\n                  \),'''

mic_badge_new = '''                if (_countdown != null)
                  Text(
                    '$_countdown',
                    key: ValueKey(_countdown),
                    style: GoogleFonts.plusJakartaSans(
                      color: _voiceActive ? Colors.white : blue,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                else if (_voiceActive)
                  BreathingWidget(
                    duration: const Duration(milliseconds: 1050),
                    minOpacity: .55,
                    maxOpacity: 1,
                    child: const Icon(
                      Icons.mic_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  )
                else
                  Icon(Icons.mic_rounded, color: blue, size: 18),'''

code = re.sub(mic_badge_old, mic_badge_new, code)

with open('lib/src/core/widgets/glow_search_bar.dart', 'w') as f:
    f.write(code)
