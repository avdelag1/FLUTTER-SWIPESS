from pathlib import Path

AI = Path('lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart')
VIDEO = Path('lib/src/features/camera/presentation/screens/video_cropper_screen.dart')

ai = AI.read_text()
video = VIDEO.read_text()

# --- Video editor: custom music immediately opens the dedicated trim flow. ---
video_import = "import 'package:flutter_swipes/src/features/camera/data/video_recut.dart';\n"
trim_import = "import 'package:flutter_swipes/src/features/add/presentation/screens/listing_audio_trim_screen.dart';\n"
if trim_import not in video:
    if video_import not in video:
        raise SystemExit('video import marker missing')
    video = video.replace(video_import, trim_import + video_import, 1)

old_preview = '''    widget.onBackgroundMusicFile?.call(file);
    await _setVideoAudio(false);
    try {
      await _soundtrackPreview.play(file: file, volume: .62);
    } catch (_) {}
'''
new_preview = '''    widget.onBackgroundMusicFile?.call(file);
    await _setVideoAudio(false);
    if (!mounted) return;
    await _soundtrackPreview.stop();
    await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ListingAudioTrimScreen(
          audioFile: file!,
          videoFile: widget.file,
          videoClipSeconds: _selection.length,
        ),
      ),
    );
'''
if 'ListingAudioTrimScreen(' not in video:
    if old_preview not in video:
        raise SystemExit('custom music preview marker missing')
    video = video.replace(old_preview, new_preview, 1)

# --- AI builder: retain the extraction result for visible compact summary chips. ---
state_marker = "  String? _status;\n  Timer? _micRestartTimer;\n"
if 'Map<String, dynamic> _aiPreview' not in ai:
    if state_marker not in ai:
        raise SystemExit('AI state marker missing')
    ai = ai.replace(
        state_marker,
        "  String? _status;\n  Map<String, dynamic> _aiPreview = <String, dynamic>{};\n  Timer? _micRestartTimer;\n",
        1,
    )

basics_set = '''      setState(() {
        if (_city.text.trim().isEmpty && city.isNotEmpty) _city.text = city;
        if (_price.text.trim().isEmpty && price.isNotEmpty) _price.text = price;
        _currency = currency;
      });
'''
if '_aiPreview = Map<String, dynamic>.of(parsed);' not in ai:
    basics_new = '''      setState(() {
        if (_city.text.trim().isEmpty && city.isNotEmpty) _city.text = city;
        if (_price.text.trim().isEmpty && price.isNotEmpty) _price.text = price;
        _currency = currency;
        _aiPreview = Map<String, dynamic>.of(parsed);
      });
'''
    if basics_set not in ai:
        raise SystemExit('basics setState marker missing')
    ai = ai.replace(basics_set, basics_new, 1)

create_marker = "      if (!mounted) return;\n\n      final detected = _parsedText(parsed, 'category').toLowerCase();\n"
if "setState(() => _aiPreview = Map<String, dynamic>.of(parsed));" not in ai:
    if create_marker not in ai:
        raise SystemExit('create parsed marker missing')
    ai = ai.replace(
        create_marker,
        "      if (!mounted) return;\n      setState(() => _aiPreview = Map<String, dynamic>.of(parsed));\n\n      final detected = _parsedText(parsed, 'category').toLowerCase();\n",
        1,
    )

# Broaden common manual-field aliases so natural speech such as "3 bedrooms"
# populates the same draft fields used by the manual listing flow.
ai = ai.replace(
    "          beds: _nullableText(_parsedText(parsed, 'beds'), draft.beds),\n",
    "          beds: _nullableText(\n            _firstParsedText(parsed, const ['beds', 'bedrooms', 'bedroom_count']),\n            draft.beds,\n          ),\n",
    1,
)
ai = ai.replace(
    "          baths: _nullableText(_parsedText(parsed, 'baths'), draft.baths),\n",
    "          baths: _nullableText(\n            _firstParsedText(parsed, const ['baths', 'bathrooms', 'bathroom_count']),\n            draft.baths,\n          ),\n",
    1,
)
ai = ai.replace(
    "          petFriendly: _parsedBool(parsed['pet_friendly']) || draft.petFriendly,\n",
    "          petFriendly: _parsedBool(parsed['pet_friendly']) ||\n              _parsedBool(parsed['pets_allowed']) ||\n              draft.petFriendly,\n",
    1,
)

amenities_marker = '''        if (originalDescription.toLowerCase().contains('air conditioning') ||
            originalDescription.toLowerCase().contains(' a/c') ||
            originalDescription.toLowerCase().contains(' ac '))
          'AC',
'''
if "contains('rooftop')" not in ai:
    if amenities_marker not in ai:
        raise SystemExit('amenities marker missing')
    ai = ai.replace(
        amenities_marker,
        amenities_marker + "        if (originalDescription.toLowerCase().contains('rooftop')) 'Rooftop',\n        if (originalDescription.toLowerCase().contains('patio')) 'Patio',\n        if (originalDescription.toLowerCase().contains('parking')) 'Parking',\n        if (originalDescription.toLowerCase().contains('gym')) 'Gym',\n",
        1,
    )

# Compact AI summary helpers. They intentionally summarize only the useful
# secondary fields instead of duplicating the full manual form.
helper_marker = "  List<String> _firstNonEmptyParsedList(\n"
if 'Widget _aiPreviewSummary()' not in ai:
    helpers = '''  List<String> _aiPreviewLabels() {
    final parsed = _aiPreview;
    if (parsed.isEmpty) return const <String>[];
    final labels = <String>[];

    void addValue(String label, String value) {
      final clean = value.trim();
      if (clean.isEmpty || clean.toLowerCase() == 'null') return;
      labels.add('$label: $clean');
    }

    addValue(
      'Type',
      _firstParsedText(parsed, const [
        'property_type',
        'vehicle_type',
        'motorcycle_type',
        'bicycle_type',
        'yacht_type',
        'service_category',
      ]),
    );
    addValue(
      'Beds',
      _firstParsedText(parsed, const ['beds', 'bedrooms', 'bedroom_count']),
    );
    addValue(
      'Baths',
      _firstParsedText(parsed, const ['baths', 'bathrooms', 'bathroom_count']),
    );
    addValue('Brand', _firstParsedText(parsed, const ['brand', 'make']));
    addValue('Model', _parsedText(parsed, 'model'));
    addValue('Year', _parsedText(parsed, 'year'));
    addValue('Condition', _parsedText(parsed, 'condition'));
    addValue('Pricing', _parsedText(parsed, 'pricing_unit'));

    if (_parsedBool(parsed['furnished'])) labels.add('Furnished');
    if (_parsedBool(parsed['pet_friendly']) || _parsedBool(parsed['pets_allowed'])) {
      labels.add('Pet friendly');
    }

    for (final amenity in _parsedList(parsed['amenities']).take(5)) {
      labels.add(amenity);
    }
    for (final feature in _parsedList(parsed['features']).take(4)) {
      labels.add(feature);
    }
    for (final skill in _parsedList(parsed['skills']).take(4)) {
      labels.add(skill);
    }
    for (final rule in _parsedList(parsed['rules']).take(3)) {
      labels.add(rule);
    }

    return labels.toSet().take(12).toList(growable: false);
  }

  Widget _aiPreviewSummary() {
    final labels = _aiPreviewLabels();
    if (labels.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .035),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: .06)),
        ),
        child: Text(
          'Enhance your description and the details AI understands — bedrooms, bathrooms, amenities, rules, features and more — will appear here.',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF8F8F98),
            fontSize: 9.5,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: _pink, size: 14),
            const SizedBox(width: 6),
            Text(
              'AI ALSO FILLED',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFD8D8DE),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .55,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: labels
              .map(
                (label) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: _pink.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _pink.withValues(alpha: .22)),
                  ),
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFF1F1F5),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

'''
    if helper_marker not in ai:
        raise SystemExit('AI helper marker missing')
    ai = ai.replace(helper_marker, helpers + helper_marker, 1)

# Verification is now introduced before media, so trust/document upload is
# available at the beginning without forcing users to hunt for it at the end.
early_media = '''                  const SizedBox(height: 18),
                  _mediaSection(photoLimit),
'''
if "_verificationCard(verificationDraft),\n                  const SizedBox(height: 18),\n                  _mediaSection" not in ai:
    if early_media not in ai:
        raise SystemExit('early media marker missing')
    ai = ai.replace(
        early_media,
        '''                  const SizedBox(height: 14),
                  _verificationCard(verificationDraft),
                  const SizedBox(height: 18),
                  _mediaSection(photoLimit),
''',
        1,
    )

# Replace the old end-of-page verification position with the compact AI chip
# summary directly below city/price.
late_verification = '''                    ],
                  ),
                  const SizedBox(height: 18),
                  _verificationCard(verificationDraft),
                  const SizedBox(height: 20),
'''
if late_verification in ai:
    ai = ai.replace(
        late_verification,
        '''                    ],
                  ),
                  const SizedBox(height: 10),
                  _aiPreviewSummary(),
                  const SizedBox(height: 20),
''',
        1,
    )

# Make "finish later" a lighter secondary action instead of another large
# competing full-width button.
old_draft_button = '''                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _saveDraft,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: .18)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      icon: const Icon(Icons.bookmark_add_rounded, size: 19),
                      label: Text(
                        'SAVE & FINISH LATER',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .3,
                        ),
                      ),
                    ),
                  ),
'''
new_draft_button = '''                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton.icon(
                      onPressed: _busy ? null : _saveDraft,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFD8D8DE),
                        backgroundColor: Colors.white.withValues(alpha: .055),
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: BorderSide(color: Colors.white.withValues(alpha: .08)),
                        ),
                      ),
                      icon: const Icon(Icons.bookmark_outline_rounded, size: 17),
                      label: Text(
                        'Finish later',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
'''
if old_draft_button in ai:
    ai = ai.replace(old_draft_button, new_draft_button, 1)

# Update the page intro to match the new order.
ai = ai.replace(
    "                    'Start with the media, describe it naturally, let AI fill the details, then publish.',\n",
    "                    'Add optional verification, choose your media, describe it naturally, and let AI fill the details.',\n",
    1,
)

AI.write_text(ai)
VIDEO.write_text(video)
