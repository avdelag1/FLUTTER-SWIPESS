from pathlib import Path

AI = Path('lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart')
source = AI.read_text()

old = '''        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 4, child: _buildVideoPanel()),
              SizedBox(width: 9),
              Expanded(flex: 3, child: _buildPhotoPanel()),
            ],
          ),
        ),'''

new = '''        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: SizedBox(height: 118, child: _buildVideoPanel()),
            ),
            SizedBox(width: 9),
            Expanded(
              flex: 3,
              child: SizedBox(height: 260, child: _buildPhotoPanel()),
            ),
          ],
        ),'''

if new in source:
    print('AI listing photo browser is already expanded.')
elif old not in source:
    raise SystemExit('AI media layout marker not found; refusing an unsafe patch')
else:
    AI.write_text(source.replace(old, new, 1))
    print('Expanded AI listing photo browser to a 260px scrollable panel.')
