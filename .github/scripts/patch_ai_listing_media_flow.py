from pathlib import Path

AI = Path('lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart')
PICKER = Path('lib/src/features/add/presentation/widgets/listing_video_soundtrack_picker.dart')

text = AI.read_text()

add_provider = "import 'package:flutter_swipes/src/features/add/presentation/providers/add_listing_provider.dart';\n"
if 'listing_draft_repository.dart' not in text:
    text = text.replace(
        add_provider,
        add_provider + "import 'package:flutter_swipes/src/features/add/data/listing_draft_repository.dart';\n",
        1,
    )

soundtrack = "import 'package:flutter_swipes/src/features/add/presentation/widgets/listing_video_soundtrack_picker.dart';\n"
if 'listing_video_inline_preview.dart' not in text:
    text = text.replace(
        soundtrack,
        soundtrack + "import 'package:flutter_swipes/src/features/add/presentation/widgets/listing_video_inline_preview.dart';\n",
        1,
    )

dispose_marker = "  @override\n  void dispose() {\n"
if 'Future<void> _saveDraft()' not in text:
    lifecycle = '''  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_restoreSavedDraft);
  }

  Future<void> _restoreSavedDraft() async {
    try {
      final saved = await ref.read(listingDraftRepositoryProvider).load('ai-new');
      if (!mounted || saved == null) return;
      final payload = saved.payload;
      final savedCategory = saved.category.toLowerCase();
      setState(() {
        if (const {'property', 'worker', 'motorcycle', 'bicycle', 'yacht'}.contains(savedCategory)) {
          _category = savedCategory;
        }
        _city.text = payload['city']?.toString() ?? '';
        _price.text = payload['price']?.toString() ?? '';
        _description.text = payload['description']?.toString() ?? '';
        final currency = (payload['currency']?.toString() ?? '').toUpperCase();
        if (currency == 'USD' || currency == 'MXN') _currency = currency;
        _videoAudioEnabled = payload['video_audio_enabled'] != false;
        _backgroundMusicPreset = payload['background_music_preset']?.toString();
        _backgroundMusicName = payload['background_music_name']?.toString();
        _photos
          ..clear()
          ..addAll(saved.photos);
        _video = saved.video;
        _backgroundMusic = saved.backgroundMusic;
      });
      _showMessage('Your saved listing draft is ready.');
    } catch (error) {
      debugPrint('[AiListingBuilder] draft restore skipped: $error');
    }
  }

  Future<void> _saveDraft() async {
    if (_busy) return;
    await _stopMic();
    if (!mounted) return;
    setState(() {
      _busy = true;
      _status = 'Saving your draft…';
    });
    try {
      final documents = List<XFile>.of(ref.read(addListingProvider).legalDocuments);
      await ref.read(listingDraftRepositoryProvider).save(
        draftKey: 'ai-new',
        kind: 'ai',
        category: _category,
        step: 0,
        payload: <String, dynamic>{
          'city': _city.text.trim(),
          'price': _price.text.trim(),
          'description': _description.text,
          'currency': _currency,
          'video_audio_enabled': _videoAudioEnabled,
          'background_music_preset': _backgroundMusicPreset,
          'background_music_name': _backgroundMusicName,
        },
        photos: _photos,
        video: _video,
        documents: documents,
        backgroundMusic: _backgroundMusic,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Draft saved ✓';
      });
      _showMessage('Saved. You can finish this listing later.');
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted) _closeBuilder();
    } catch (error) {
      debugPrint('[AiListingBuilder] draft save failed: $error');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
      });
      _showMessage('Could not save the draft right now. Nothing on this page was cleared.');
    }
  }

'''
    if dispose_marker not in text:
        raise SystemExit('dispose marker missing')
    text = text.replace(dispose_marker, lifecycle + dispose_marker, 1)

video_marker = "        if (_video != null) ...[\n          const SizedBox(height: 10),\n          Container(\n"
if 'ListingVideoInlinePreview(' not in text and video_marker in text:
    video_showcase = '''        if (_video != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 330,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 4,
                  child: ListingVideoInlinePreview(
                    file: _video,
                    muted: !_videoAudioEnabled,
                    height: 330,
                  ),
                ),
                if (_photos.isNotEmpty) ...[
                  const SizedBox(width: 9),
                  Expanded(
                    flex: 3,
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _photos.length > 4 ? 4 : _photos.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 7,
                        crossAxisSpacing: 7,
                        childAspectRatio: .72,
                      ),
                      itemBuilder: (context, index) => _PhotoTile(
                        file: _photos[index],
                        onRemove: _busy
                            ? null
                            : () => setState(() => _photos.removeAt(index)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
'''
    text = text.replace(video_marker, video_showcase, 1)

text = text.replace(
    "        if (_photos.isNotEmpty) ...[\n          const SizedBox(height: 10),\n          GridView.builder(\n",
    "        if (_photos.isNotEmpty && _video == null) ...[\n          const SizedBox(height: 10),\n          GridView.builder(\n",
    1,
)

if 'SAVE & FINISH LATER' not in text:
    info_marker = "                  const SizedBox(height: 8),\n                  Text(\n                    'AI fills what it can from your description. Review the fields, choose verification or skip it, then publish.',\n"
    draft_button = '''                  const SizedBox(height: 10),
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
                  const SizedBox(height: 8),
                  Text(
                    'AI fills what it can from your description. Review the fields, choose verification or skip it, then publish.',
'''
    if info_marker not in text:
        raise SystemExit('draft button marker missing')
    text = text.replace(info_marker, draft_button, 1)

success_marker = "      setState(() => _status = 'Listing published ✓');\n      await Future<void>.delayed(const Duration(milliseconds: 350));\n"
if "delete('ai-new')" not in text and success_marker in text:
    text = text.replace(
        success_marker,
        "      setState(() => _status = 'Listing published ✓');\n      try {\n        await ref.read(listingDraftRepositoryProvider).delete('ai-new');\n      } catch (_) {}\n      await Future<void>.delayed(const Duration(milliseconds: 350));\n",
        1,
    )

friendly_marker = "    if (lower.contains('session expired')) return message;\n"
if "lower.contains('storageexception')" not in text and friendly_marker in text:
    text = text.replace(
        friendly_marker,
        friendly_marker + "    if (lower.contains('storageexception') ||\n        lower.contains('row-level security') ||\n        lower.contains('statuscode: 403') ||\n        lower.contains('unauthorized')) {\n      return 'We could not upload that media right now. Your listing is still here — please try again.';\n    }\n",
        1,
    )

AI.write_text(text)

picker = PICKER.read_text()
picker = picker.replace("import 'package:flutter_swipes/src/features/add/presentation/widgets/listing_audio_trim_editor.dart';\n", '')
old_trim = '''          if (widget.customMusic != null)
            ListingAudioTrimEditor(
              file: widget.customMusic!,
              disabled: widget.disabled,
            ),
'''
picker = picker.replace(old_trim, '')
PICKER.write_text(picker)
