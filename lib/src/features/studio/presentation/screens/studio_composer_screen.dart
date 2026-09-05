import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/add/presentation/widgets/listing_video_inline_preview.dart';
import 'package:flutter_swipes/src/features/studio/data/cinematic_catalog.dart';
import 'package:flutter_swipes/src/features/studio/domain/cinematic_template.dart';
import 'package:flutter_swipes/src/features/studio/presentation/widgets/cinematic_preview.dart';
import 'package:flutter_swipes/src/features/swipes/domain/listing_soundtrack.dart';
import 'package:google_fonts/google_fonts.dart';

class StudioComposerResult {
  const StudioComposerResult({required this.project, required this.photos});

  final StudioProject project;
  final List<XFile> photos;
}

class StudioRenderedVideo {
  const StudioRenderedVideo({
    required this.videoUrl,
    this.posterUrl,
    required this.durationSeconds,
  });

  final String videoUrl;
  final String? posterUrl;
  final double durationSeconds;
}

typedef StudioRealVideoRenderer = Future<StudioRenderedVideo> Function(
  StudioComposerResult result,
);

class StudioComposerScreen extends StatefulWidget {
  const StudioComposerScreen({
    super.key,
    required this.photos,
    required this.listingCategory,
    this.initialProject,
    this.onCreateRealVideo,
  });

  final List<XFile> photos;
  final String listingCategory;
  final StudioProject? initialProject;
  final StudioRealVideoRenderer? onCreateRealVideo;

  @override
  State<StudioComposerScreen> createState() => _StudioComposerScreenState();
}

class _StudioComposerScreenState extends State<StudioComposerScreen> {
  static const _pink = Color(0xFFFF2D6F);
  late final StudioCategory _category;
  late final List<CinematicTemplate> _templates;
  late List<XFile> _photos;
  late String _templateId;
  late String _audioPresetId;
  late Map<int, StudioFocalPoint> _focalPoints;
  int _selectedPhoto = 0;
  bool _playing = true;
  bool _renderingRealVideo = false;
  String? _realVideoError;
  StudioRenderedVideo? _renderedVideo;

  @override
  void initState() {
    super.initState();
    _category = studioCategoryFromName(widget.listingCategory);
    _templates = CinematicCatalog.templatesFor(_category);
    _photos = widget.photos.take(6).toList(growable: true);
    final initial = widget.initialProject;
    final initialTemplate = initial == null
        ? _templates.first
        : CinematicCatalog.byId(initial.templateId);
    _templateId = _templates.any((item) => item.id == initialTemplate.id)
        ? initialTemplate.id
        : _templates.first.id;
    _audioPresetId = initial?.audioPresetId ?? _selectedTemplate.audioPresetId;
    _focalPoints = Map<int, StudioFocalPoint>.of(
      initial?.focalPoints ?? const <int, StudioFocalPoint>{},
    );
  }

  CinematicTemplate get _selectedTemplate => _templates.firstWhere(
    (item) => item.id == _templateId,
    orElse: () => _templates.first,
  );

  CinematicTemplate get _previewTemplate {
    final base = _selectedTemplate;
    return CinematicTemplate(
      id: base.id,
      version: base.version,
      name: base.name,
      category: base.category,
      description: base.description,
      audioPresetId: _audioPresetId,
      width: base.width,
      height: base.height,
      fps: base.fps,
      shotPattern: base.shotPattern,
    );
  }

  StudioProject get _project => StudioProject(
    templateId: _selectedTemplate.id,
    templateVersion: _selectedTemplate.version,
    category: _category,
    audioPresetId: _audioPresetId,
    focalPoints: _focalPoints,
  );

  StudioFocalPoint get _activeFocal =>
      _focalPoints[_selectedPhoto] ?? const StudioFocalPoint();

  void _setFocal({double? x, double? y}) {
    final current = _activeFocal;
    setState(() {
      _renderedVideo = null;
      _realVideoError = null;
      _focalPoints[_selectedPhoto] = StudioFocalPoint(
        x: x ?? current.x,
        y: y ?? current.y,
      );
    });
  }

  void _selectTemplate(CinematicTemplate template) {
    setState(() {
      _renderedVideo = null;
      _realVideoError = null;
      _templateId = template.id;
      _audioPresetId = template.audioPresetId;
      _playing = true;
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex ||
        oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= _photos.length ||
        newIndex >= _photos.length) {
      return;
    }

    final orderedFocals = <StudioFocalPoint>[
      for (var i = 0; i < _photos.length; i++)
        _focalPoints[i] ?? const StudioFocalPoint(),
    ];
    final movedPhoto = _photos.removeAt(oldIndex);
    final movedFocal = orderedFocals.removeAt(oldIndex);
    _photos.insert(newIndex, movedPhoto);
    orderedFocals.insert(newIndex, movedFocal);

    setState(() {
      _renderedVideo = null;
      _realVideoError = null;
      _focalPoints = <int, StudioFocalPoint>{
        for (var i = 0; i < orderedFocals.length; i++) i: orderedFocals[i],
      };
      _selectedPhoto = newIndex;
    });
  }

  Future<void> _createRealVideo() async {
    if (_renderingRealVideo) return;
    final renderer = widget.onCreateRealVideo;
    if (renderer == null) {
      setState(() {
        _realVideoError =
            'Studio renderer is not connected. Close Studio, reopen it and try again.';
      });
      return;
    }

    setState(() {
      _renderingRealVideo = true;
      _realVideoError = null;
      _renderedVideo = null;
      _playing = false;
    });

    try {
      final rendered = await renderer(
        StudioComposerResult(
          project: _project,
          photos: List<XFile>.unmodifiable(_photos),
        ),
      );
      if (!mounted) return;
      if (rendered.videoUrl.trim().isEmpty) {
        throw Exception('Renderer returned an empty MP4 URL.');
      }
      setState(() {
        _renderingRealVideo = false;
        _renderedVideo = rendered;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _renderingRealVideo = false;
        _realVideoError = error
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('ClientException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canUse = _photos.length >= 3 && _photos.length <= 6;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'SWIPESS STUDIO',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _playing ? 'Pause preview' : 'Play preview',
            onPressed: canUse
                ? () => setState(() => _playing = !_playing)
                : null,
            icon: Icon(
              _playing
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Text(
              'TURN PHOTOS INTO MOTION',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: -.8,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Choose 3–6 photos and a style. The preview below is only a live effect preview. Tap CREATE REAL VIDEO and Swipess will render the actual MP4, then show it in a real video player before you publish the listing.',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF9B9BA5),
                fontSize: 11.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (_renderedVideo != null)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: Container(
                    height: 520,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFF34D399),
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ListingVideoInlinePreview(
                          networkUrl: _renderedVideo!.videoUrl,
                          muted: false,
                          height: 520,
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          right: 12,
                          child: IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: .72),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    color: Color(0xFF34D399),
                                    size: 18,
                                  ),
                                  SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      'REAL MP4 CREATED · PLAY IT BEFORE USING',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (!canUse)
              _notice(
                icon: Icons.photo_library_outlined,
                text: _photos.length < 3
                    ? 'Add at least 3 photos to use Studio.'
                    : 'Studio uses a maximum of 6 photos.',
              )
            else
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: CinematicPreview(
                    key: ValueKey(
                      '${_templateId}_${_audioPresetId}_${_photos.length}',
                    ),
                    photos: _photos,
                    template: _previewTemplate,
                    focalPoints: _focalPoints,
                    playing: _playing,
                    playAudio: true,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            _sectionTitle('PHOTO ORDER'),
            const SizedBox(height: 9),
            SizedBox(
              height: 88,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                itemCount: _photos.length,
                onReorder: _reorder,
                itemBuilder: (context, index) =>
                    ReorderableDelayedDragStartListener(
                      key: ValueKey('${_photos[index].name}-$index'),
                      index: index,
                      child: _PhotoThumb(
                        file: _photos[index],
                        index: index,
                        selected: index == _selectedPhoto,
                        onTap: () => setState(() => _selectedPhoto = index),
                      ),
                    ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Hold and drag to change the story order. Tap a photo to adjust its focus.',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF777780),
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_photos.isNotEmpty) ...[
              const SizedBox(height: 16),
              _focusControls(),
            ],
            const SizedBox(height: 22),
            _sectionTitle('VIDEO STYLE'),
            const SizedBox(height: 9),
            ..._templates.map(_templateCard),
            const SizedBox(height: 20),
            _sectionTitle('SOUND'),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: listingSoundtrackPresets
                  .map((preset) => _soundChip(preset))
                  .toList(growable: false),
            ),
            const SizedBox(height: 22),
            if (_renderingRealVideo)
              _notice(
                icon: Icons.hourglass_top_rounded,
                text:
                    'Rendering the real MP4 now. Keep Studio open — the listing cannot publish until the video exists.',
              ),
            if (_realVideoError != null) ...[
              _notice(
                icon: Icons.error_outline_rounded,
                text: _realVideoError!,
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: !canUse || _renderingRealVideo
                    ? null
                    : _renderedVideo == null
                    ? _createRealVideo
                    : () => Navigator.of(context).pop(
                        StudioComposerResult(
                          project: _project,
                          photos: List<XFile>.unmodifiable(_photos),
                        ),
                      ),
                style: FilledButton.styleFrom(
                  backgroundColor: _renderedVideo == null
                      ? _pink
                      : const Color(0xFF16A34A),
                  disabledBackgroundColor: _pink.withValues(alpha: .35),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: _renderingRealVideo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _renderedVideo == null
                            ? Icons.movie_creation_rounded
                            : Icons.check_circle_rounded,
                      ),
                label: Text(
                  _renderingRealVideo
                      ? 'RENDERING REAL MP4…'
                      : _renderedVideo == null
                      ? 'CREATE REAL VIDEO'
                      : 'USE THIS REAL VIDEO',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .35,
                  ),
                ),
              ),
            ),
            if (_renderedVideo != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() {
                  _renderedVideo = null;
                  _realVideoError = null;
                  _playing = true;
                }),
                icon: const Icon(Icons.tune_rounded),
                label: const Text('EDIT STYLE AND RENDER AGAIN'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _notice({required IconData icon, required String text}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF17171C),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: .08)),
    ),
    child: Row(
      children: [
        Icon(icon, color: _pink),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _focusControls() {
    final focal = _activeFocal;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF17171C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PHOTO ${_selectedPhoto + 1} FOCUS',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.swap_horiz_rounded,
                color: Color(0xFF9B9BA5),
                size: 18,
              ),
              Expanded(
                child: Slider(
                  value: focal.x,
                  min: 0,
                  max: 1,
                  activeColor: _pink,
                  onChanged: (value) => _setFocal(x: value),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(
                Icons.swap_vert_rounded,
                color: Color(0xFF9B9BA5),
                size: 18,
              ),
              Expanded(
                child: Slider(
                  value: focal.y,
                  min: 0,
                  max: 1,
                  activeColor: _pink,
                  onChanged: (value) => _setFocal(y: value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _templateCard(CinematicTemplate template) {
    final selected = template.id == _templateId;
    final soundtrack = listingSoundtrackPresetById(template.audioPresetId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _selectTemplate(template),
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: selected
                ? _pink.withValues(alpha: .14)
                : const Color(0xFF17171C),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected ? _pink : Colors.white.withValues(alpha: .07),
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected ? _pink : const Color(0xFF24242B),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  _styleIcon(template),
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      template.description,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF9999A3),
                        fontSize: 9.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (soundtrack != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${soundtrack.emoji} ${soundtrack.label}',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFC9C9D0),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: _pink,
                  size: 21,
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _styleIcon(CinematicTemplate template) {
    final transition = template.shotPattern.first.transition;
    return switch (transition) {
      StudioTransition.splitVertical || StudioTransition.splitHorizontal =>
        Icons.vertical_split_rounded,
      StudioTransition.hardCut => Icons.flash_on_rounded,
      StudioTransition.pushLeft || StudioTransition.pushUp =>
        Icons.compare_arrows_rounded,
      StudioTransition.crossFade => Icons.blur_on_rounded,
    };
  }

  Widget _soundChip(ListingSoundtrackPreset preset) {
    final selected = _audioPresetId == preset.id;
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() {
        _renderedVideo = null;
        _realVideoError = null;
        _audioPresetId = preset.id;
        _playing = true;
      }),
      backgroundColor: const Color(0xFF17171C),
      selectedColor: _pink,
      side: BorderSide(
        color: selected ? _pink : Colors.white.withValues(alpha: .08),
      ),
      avatar: Text(preset.emoji),
      label: Text(preset.label),
      labelStyle: GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: GoogleFonts.plusJakartaSans(
      color: const Color(0xFF9B9BA5),
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.1,
    ),
  );
}

class _PhotoThumb extends StatefulWidget {
  const _PhotoThumb({
    required this.file,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final XFile file;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PhotoThumb> createState() => _PhotoThumbState();
}

class _PhotoThumbState extends State<_PhotoThumb> {
  late final Future<Uint8List> _bytes = widget.file.readAsBytes();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 68,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.selected
                ? const Color(0xFFFF2D6F)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<Uint8List>(
                future: _bytes,
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  if (data == null || data.isEmpty) {
                    return const ColoredBox(color: Color(0xFF202027));
                  }
                  return Image.memory(
                    data,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                  );
                },
              ),
              Positioned(
                top: 5,
                left: 5,
                child: Container(
                  width: 21,
                  height: 21,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .7),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${widget.index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
