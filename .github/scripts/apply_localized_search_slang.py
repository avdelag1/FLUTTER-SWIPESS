from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'{label} not found')
    return text.replace(old, new, 1)


dashboard = Path('lib/src/core/widgets/glow_search_bar.dart')
text = dashboard.read_text()

text = replace_once(
    text,
    "import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';\n",
    "import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';\n"
    "import 'package:flutter_swipes/src/features/dashboard/domain/localized_search_slang.dart';\n",
    'localized slang import',
)

old_prompts = """  List<String> get _rotatingPrompts => <String>[
    'What are you looking for today?',
    'Show me something nearby',
    'Find a beautiful property in $_place',
    'What’s happening around $_place tonight?',
    'Find trusted workers near me',
    'Show me homes for rent',
    'Find a trusted mechanic',
    'Show me yachts nearby',
    'Find motorcycles around $_place',
    'Need local legal help in $_place?',
    'What’s popular around $_place right now?',
    'Show me something worth swiping',
  ];
"""
new_prompts = """  List<String> get _rotatingPrompts {
    final discovery = ref.read(discoveryLocationProvider);
    final localHook = LocalizedSearchSlang.searchPrompt(
      city: discovery.city,
      country: discovery.country,
    );

    return <String>[
      localHook,
      'Show me something nearby',
      'Find a beautiful property in $_place',
      'What’s happening around $_place tonight?',
      'Find a massage or wellness service near me',
      'Find trusted workers near me',
      'Show me homes for rent',
      'Find a trusted mechanic',
      'Show me yachts nearby',
      'Find motorcycles around $_place',
      'Need local legal help in $_place?',
      'What’s popular around $_place right now?',
      'Show me something worth swiping',
    ];
  }
"""
text = replace_once(text, old_prompts, new_prompts, 'rotating prompt block')
dashboard.write_text(text)

workflow = Path('.github/workflows/flutter_checks.yml')
wf = workflow.read_text()
job = """  localized-slang-hotfix:
    if: github.event_name == 'push' && contains(github.event.head_commit.message, 'run localized slang hotfix')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: main
      - name: Apply localized prompt patch
        run: python3 .github/scripts/apply_localized_search_slang.py
      - name: Commit localized prompt patch
        run: |
          git config user.name \"swipess-hotfix-bot\"
          git config user.email \"actions@users.noreply.github.com\"
          git add -A
          git commit -m \"feat(ai): localize dashboard search prompts by location\"
          git push origin HEAD:main

"""
if job not in wf:
    raise SystemExit('temporary localized-slang-hotfix job not found')
wf = wf.replace(job, '', 1)
wf = wf.replace('permissions:\n  contents: write\n', 'permissions:\n  contents: read\n', 1)
workflow.write_text(wf)
Path('.github/scripts/apply_localized_search_slang.py').unlink()
