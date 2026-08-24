import re

def fix_bar(path):
    with open(path, 'r') as f:
        code = f.read()

    # Remove countdown from hintText
    hint_old = r'''                      hintText: _voiceActive\n                          \? \(_countdown != null\n                                \? 'Sending in \$_countdown…'\n                                : 'Listening… your words appear here'\)\n                          : 'Search properties, workers, people, events...','''
    hint_new = '''                      hintText: _voiceActive\n                          ? 'Listening… your words appear here'\n                          : 'Search properties, workers, people, events...','''
    code = re.sub(hint_old, hint_new, code)

    # Now make the mic button show the big countdown INSTEAD of the mic icon
    # ai_search_bar currently has:
    #                 if (_countdown != null)
    #                   Positioned(
    #                     right: -5,
    #                     top: -6,
    #                     child: Container(...)
    mic_badge_old = r'''                if \(_voiceActive\)\n                  BreathingWidget\(\n                    duration: const Duration\(milliseconds: 1100\),\n                    minOpacity: \.55,\n                    maxOpacity: 1,\n                    child: const Icon\(\n                      Icons\.mic_rounded,\n                      color: Colors\.white,\n                      size: 20,\n                    \),\n                  \)\n                else\n                  Icon\(Icons\.mic_rounded, color: glow, size: 21\),\n                if \(_countdown != null\)\n                  Positioned\(\n                    right: -5,\n                    top: -6,\n                    child: Container\(\n                      width: 20,\n                      height: 20,\n                      alignment: Alignment\.center,\n                      decoration: BoxDecoration\(\n                        color: Colors\.white,\n                        shape: BoxShape\.circle,\n                        border: Border\.all\(color: glow, width: 1\.4\),\n                      \),\n                      child: Text\(\n                        '\$_countdown',\n                        style: GoogleFonts\.plusJakartaSans\(\n                          color: glow,\n                          fontSize: 9,\n                          fontWeight: FontWeight\.w900,\n                          height: 1,\n                        \),\n                      \),\n                    \),\n                  \),'''

    mic_badge_new = '''                if (_countdown != null)
                  Text(
                    '$_countdown',
                    key: ValueKey(_countdown),
                    style: GoogleFonts.plusJakartaSans(
                      color: _voiceActive ? Colors.white : glow,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                else if (_voiceActive)
                  BreathingWidget(
                    duration: const Duration(milliseconds: 1100),
                    minOpacity: .55,
                    maxOpacity: 1,
                    child: const Icon(
                      Icons.mic_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  )
                else
                  Icon(Icons.mic_rounded, color: glow, size: 21),'''
    
    code = re.sub(mic_badge_old, mic_badge_new, code)
    
    with open(path, 'w') as f:
        f.write(code)

fix_bar('lib/src/features/dashboard/presentation/widgets/ai_search_bar.dart')
fix_bar('lib/src/core/widgets/glow_search_bar.dart')

