from pathlib import Path

path = Path('.github/patches/listing_media_ai_flow.py')
text = path.read_text()

# Repair the accidentally split Python string used to find the DESCRIPTION row.
lines = text.splitlines()
for i, line in enumerate(lines):
    if line.startswith('end_marker = "                  Row('):
        lines[i] = 'end_marker = "                  Row(\\n                    children: [\\n                      Expanded(child: _sectionTitle(\'DESCRIBE IT\')),\\n"'
        if i + 1 < len(lines) and lines[i + 1] == '"':
            del lines[i + 1]
        break
else:
    raise SystemExit('end_marker assignment not found')
text = '\n'.join(lines) + '\n'

# The source contains city/price more than once (extractor arguments + draft
# update). Replace the draft field cluster as one exact block instead of using
# ambiguous single-line replacements.
old = '''s = replace_once(s, "          city: typedCity,", "          city: finalCity,", "final ai city")
s = replace_once(s, "          price: typedPrice,", "          price: finalPrice,", "final ai price")
s = replace_once(s, "          currency: _currency,", "          currency: finalCurrency,", "final ai currency")
s = replace_once(s, "          photos: safePhotos,", "          photos: safePhotos,\\n          video: _video,", "ai video")
'''
new = '''s = replace_once(
    s,
    """          city: typedCity,
          country: country.isNotEmpty ? country : draft.country,
          neighborhood: neighborhood.isNotEmpty
              ? neighborhood
              : draft.neighborhood,
          description: description,
          title: title.isNotEmpty ? title : draft.title,
          price: typedPrice,
          currency: _currency,
          photos: safePhotos,
""",
    """          city: finalCity,
          country: country.isNotEmpty ? country : draft.country,
          neighborhood: neighborhood.isNotEmpty
              ? neighborhood
              : draft.neighborhood,
          description: description,
          title: title.isNotEmpty ? title : draft.title,
          price: finalPrice,
          currency: finalCurrency,
          photos: safePhotos,
          video: _video,
""",
    "ai final draft basics and video",
)
'''
if old not in text:
    raise SystemExit('ambiguous AI replacement block not found')
text = text.replace(old, new, 1)
path.write_text(text)
print('fixed listing patch script targeting')
