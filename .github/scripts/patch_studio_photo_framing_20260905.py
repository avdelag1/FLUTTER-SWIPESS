from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one anchor, found {count}")
    return text.replace(old, new, 1)


def replace_regex(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one regex match, found {count}")
    return updated


def patch_domain() -> None:
    p = Path('lib/src/features/studio/domain/cinematic_template.dart')
    s = p.read_text()

    s = replace_once(
        s,
        "enum StudioEasing { linear, easeIn, easeOut, easeInOut }\n\nclass StudioPoint {",
        "enum StudioEasing { linear, easeIn, easeOut, easeInOut }\n\n"
        "/// How one source photo is framed inside Studio's fixed 9:16 movie.\n"
        "/// [portrait] is the default full-bleed crop; [fit] preserves the entire photo.\n"
        "enum StudioPhotoFit { portrait, fit }\n\nclass StudioPoint {",
        'domain photo-fit enum',
    )

    s = replace_once(
        s,
        "  Map<String, dynamic> toRenderJson({\n"
        "    required int photoCount,\n"
        "    Map<int, StudioFocalPoint> focalPoints = const <int, StudioFocalPoint>{},\n"
        "  }) => <String, dynamic>{",
        "  Map<String, dynamic> toRenderJson({\n"
        "    required int photoCount,\n"
        "    Map<int, StudioFocalPoint> focalPoints = const <int, StudioFocalPoint>{},\n"
        "    Map<int, StudioPhotoFit> photoFits = const <int, StudioPhotoFit>{},\n"
        "  }) => <String, dynamic>{",
        'render-json signature',
    )

    s = replace_once(
        s,
        "          'image_index': i,\n"
        "          'focal': (focalPoints[i] ?? const StudioFocalPoint()).toJson(),\n",
        "          'image_index': i,\n"
        "          'focal': (focalPoints[i] ?? const StudioFocalPoint()).toJson(),\n"
        "          'fit': (photoFits[i] ?? StudioPhotoFit.portrait).name,\n",
        'render-json shot fit',
    )

    s = replace_once(
        s,
        "    required this.audioPresetId,\n"
        "    this.focalPoints = const <int, StudioFocalPoint>{},\n"
        "  });",
        "    required this.audioPresetId,\n"
        "    this.focalPoints = const <int, StudioFocalPoint>{},\n"
        "    this.photoFits = const <int, StudioPhotoFit>{},\n"
        "  });",
        'project constructor',
    )

    s = replace_once(
        s,
        "  final String audioPresetId;\n"
        "  final Map<int, StudioFocalPoint> focalPoints;\n",
        "  final String audioPresetId;\n"
        "  final Map<int, StudioFocalPoint> focalPoints;\n"
        "  final Map<int, StudioPhotoFit> photoFits;\n",
        'project field',
    )

    s = replace_once(
        s,
        "    String? audioPresetId,\n"
        "    Map<int, StudioFocalPoint>? focalPoints,\n"
        "  }) => StudioProject(",
        "    String? audioPresetId,\n"
        "    Map<int, StudioFocalPoint>? focalPoints,\n"
        "    Map<int, StudioPhotoFit>? photoFits,\n"
        "  }) => StudioProject(",
        'project copy signature',
    )

    s = replace_once(
        s,
        "    audioPresetId: audioPresetId ?? this.audioPresetId,\n"
        "    focalPoints: focalPoints ?? this.focalPoints,\n"
        "  );",
        "    audioPresetId: audioPresetId ?? this.audioPresetId,\n"
        "    focalPoints: focalPoints ?? this.focalPoints,\n"
        "    photoFits: photoFits ?? this.photoFits,\n"
        "  );",
        'project copy body',
    )

    s = replace_once(
        s,
        "    'focal_points': <String, dynamic>{\n"
        "      for (final entry in focalPoints.entries)\n"
        "        entry.key.toString(): entry.value.toJson(),\n"
        "    },\n"
        "  };",
        "    'focal_points': <String, dynamic>{\n"
        "      for (final entry in focalPoints.entries)\n"
        "        entry.key.toString(): entry.value.toJson(),\n"
        "    },\n"
        "    'photo_fits': <String, dynamic>{\n"
        "      for (final entry in photoFits.entries)\n"
        "        entry.key.toString(): entry.value.name,\n"
        "    },\n"
        "  };",
        'project json fit map',
    )

    s = replace_once(
        s,
        "    final focalRaw = json['focal_points'];\n"
        "    final focalPoints = <int, StudioFocalPoint>{};",
        "    final focalRaw = json['focal_points'];\n"
        "    final fitRaw = json['photo_fits'];\n"
        "    final focalPoints = <int, StudioFocalPoint>{};",
        'project fit raw',
    )

    anchor = """    if (focalRaw is Map) {
      for (final entry in focalRaw.entries) {
        final index = int.tryParse(entry.key.toString());
        if (index == null || entry.value is! Map) continue;
        focalPoints[index] = StudioFocalPoint.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }
    return StudioProject(
"""
    replacement = """    if (focalRaw is Map) {
      for (final entry in focalRaw.entries) {
        final index = int.tryParse(entry.key.toString());
        if (index == null || entry.value is! Map) continue;
        focalPoints[index] = StudioFocalPoint.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }
    final photoFits = <int, StudioPhotoFit>{};
    if (fitRaw is Map) {
      for (final entry in fitRaw.entries) {
        final index = int.tryParse(entry.key.toString());
        if (index == null) continue;
        photoFits[index] = entry.value.toString() == StudioPhotoFit.fit.name
            ? StudioPhotoFit.fit
            : StudioPhotoFit.portrait;
      }
    }
    return StudioProject(
"""
    s = replace_once(s, anchor, replacement, 'project parse fit map')

    s = replace_once(
        s,
        "      audioPresetId: json['audio_preset']?.toString() ?? 'clean_ambient',\n"
        "      focalPoints: focalPoints,\n"
        "    );",
        "      audioPresetId: json['audio_preset']?.toString() ?? 'clean_ambient',\n"
        "      focalPoints: focalPoints,\n"
        "      photoFits: photoFits,\n"
        "    );",
        'project parse result',
    )

    p.write_text(s)


def patch_composer() -> None:
    p = Path('lib/src/features/studio/presentation/screens/studio_composer_screen.dart')
    s = p.read_text()

    s = replace_once(
        s,
        "  late Map<int, StudioFocalPoint> _focalPoints;\n"
        "  int _selectedPhoto = 0;",
        "  late Map<int, StudioFocalPoint> _focalPoints;\n"
        "  late Map<int, StudioPhotoFit> _photoFits;\n"
        "  int _selectedPhoto = 0;",
        'composer photo fit state',
    )

    s = replace_once(
        s,
        "    _focalPoints = Map<int, StudioFocalPoint>.of(\n"
        "      initial?.focalPoints ?? const <int, StudioFocalPoint>{},\n"
        "    );\n",
        "    _focalPoints = Map<int, StudioFocalPoint>.of(\n"
        "      initial?.focalPoints ?? const <int, StudioFocalPoint>{},\n"
        "    );\n"
        "    _photoFits = Map<int, StudioPhotoFit>.of(\n"
        "      initial?.photoFits ?? const <int, StudioPhotoFit>{},\n"
        "    );\n",
        'composer initialize fits',
    )

    s = replace_once(
        s,
        "    audioPresetId: _audioPresetId,\n"
        "    focalPoints: _focalPoints,\n"
        "  );",
        "    audioPresetId: _audioPresetId,\n"
        "    focalPoints: _focalPoints,\n"
        "    photoFits: _photoFits,\n"
        "  );",
        'composer project fits',
    )

    s = replace_once(
        s,
        "  StudioFocalPoint get _activeFocal =>\n"
        "      _focalPoints[_selectedPhoto] ?? const StudioFocalPoint();\n\n"
        "  void _setFocal({double? x, double? y}) {",
        "  StudioFocalPoint get _activeFocal =>\n"
        "      _focalPoints[_selectedPhoto] ?? const StudioFocalPoint();\n\n"
        "  StudioPhotoFit get _activePhotoFit =>\n"
        "      _photoFits[_selectedPhoto] ?? StudioPhotoFit.portrait;\n\n"
        "  void _setPhotoFit(StudioPhotoFit fit) {\n"
        "    setState(() {\n"
        "      _renderedVideo = null;\n"
        "      _realVideoError = null;\n"
        "      _photoFits[_selectedPhoto] = fit;\n"
        "      _playing = true;\n"
        "    });\n"
        "  }\n\n"
        "  void _setFocal({double? x, double? y}) {",
        'composer active framing',
    )

    s = replace_once(
        s,
        "    final orderedFocals = <StudioFocalPoint>[\n"
        "      for (var i = 0; i < _photos.length; i++)\n"
        "        _focalPoints[i] ?? const StudioFocalPoint(),\n"
        "    ];\n"
        "    final movedPhoto = _photos.removeAt(oldIndex);\n"
        "    final movedFocal = orderedFocals.removeAt(oldIndex);\n"
        "    _photos.insert(newIndex, movedPhoto);\n"
        "    orderedFocals.insert(newIndex, movedFocal);",
        "    final orderedFocals = <StudioFocalPoint>[\n"
        "      for (var i = 0; i < _photos.length; i++)\n"
        "        _focalPoints[i] ?? const StudioFocalPoint(),\n"
        "    ];\n"
        "    final orderedFits = <StudioPhotoFit>[\n"
        "      for (var i = 0; i < _photos.length; i++)\n"
        "        _photoFits[i] ?? StudioPhotoFit.portrait,\n"
        "    ];\n"
        "    final movedPhoto = _photos.removeAt(oldIndex);\n"
        "    final movedFocal = orderedFocals.removeAt(oldIndex);\n"
        "    final movedFit = orderedFits.removeAt(oldIndex);\n"
        "    _photos.insert(newIndex, movedPhoto);\n"
        "    orderedFocals.insert(newIndex, movedFocal);\n"
        "    orderedFits.insert(newIndex, movedFit);",
        'composer reorder fit',
    )

    s = replace_once(
        s,
        "      _focalPoints = <int, StudioFocalPoint>{\n"
        "        for (var i = 0; i < orderedFocals.length; i++) i: orderedFocals[i],\n"
        "      };\n"
        "      _selectedPhoto = newIndex;",
        "      _focalPoints = <int, StudioFocalPoint>{\n"
        "        for (var i = 0; i < orderedFocals.length; i++) i: orderedFocals[i],\n"
        "      };\n"
        "      _photoFits = <int, StudioPhotoFit>{\n"
        "        for (var i = 0; i < orderedFits.length; i++) i: orderedFits[i],\n"
        "      };\n"
        "      _selectedPhoto = newIndex;",
        'composer rebuild fit order',
    )

    s = replace_once(
        s,
        "                    focalPoints: _focalPoints,\n"
        "                    playing: _playing,",
        "                    focalPoints: _focalPoints,\n"
        "                    photoFits: _photoFits,\n"
        "                    playing: _playing,",
        'composer preview fits',
    )

    s = replace_once(
        s,
        "Hold and drag to change the story order. Tap a photo to adjust its focus.",
        "Hold and drag to change the story order. Tap a photo to choose Portrait/Fit and adjust its focus.",
        'composer framing helper',
    )

    focus_function = r"  Widget _focusControls\(\) \{.*?\n  \}\n\n  Widget _templateCard"
    replacement = """  Widget _focusControls() {
    final focal = _activeFocal;
    final framing = _activePhotoFit;
    final portrait = framing == StudioPhotoFit.portrait;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF17171C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PHOTO ${_selectedPhoto + 1} FRAMING',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                selected: portrait,
                showCheckmark: false,
                onSelected: (_) => _setPhotoFit(StudioPhotoFit.portrait),
                avatar: Icon(
                  Icons.crop_portrait_rounded,
                  size: 18,
                  color: portrait ? Colors.white : const Color(0xFFB1B1BA),
                ),
                label: const Text('PORTRAIT'),
                backgroundColor: const Color(0xFF24242B),
                selectedColor: _pink,
                side: BorderSide(
                  color: portrait ? _pink : Colors.white.withValues(alpha: .08),
                ),
                labelStyle: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              ChoiceChip(
                selected: !portrait,
                showCheckmark: false,
                onSelected: (_) => _setPhotoFit(StudioPhotoFit.fit),
                avatar: Icon(
                  Icons.fit_screen_rounded,
                  size: 18,
                  color: !portrait ? Colors.white : const Color(0xFFB1B1BA),
                ),
                label: const Text('FIT'),
                backgroundColor: const Color(0xFF24242B),
                selectedColor: _pink,
                side: BorderSide(
                  color: !portrait ? _pink : Colors.white.withValues(alpha: .08),
                ),
                labelStyle: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            portrait
                ? 'Portrait fills the complete 9:16 video/card. Move the focus below to choose what stays visible when a landscape photo is cropped.'
                : 'Fit keeps the entire original photo visible. Wide photos can have black space above and below.',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF92929C),
              fontSize: 9.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (portrait) ...[
            const SizedBox(height: 12),
            Text(
              'FOCUS POINT',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFD0D0D6),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(height: 2),
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
          ] else ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF9B9BA5),
                  size: 17,
                ),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Focus controls return when Portrait is selected.',
                    style: TextStyle(
                      color: Color(0xFF9B9BA5),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _templateCard"""
    s = replace_regex(s, focus_function, replacement, 'composer framing UI')

    p.write_text(s)


def patch_preview() -> None:
    p = Path('lib/src/features/studio/presentation/widgets/cinematic_preview.dart')
    s = p.read_text()

    s = replace_once(
        s,
        "    this.focalPoints = const <int, StudioFocalPoint>{},\n"
        "    this.playing = true,",
        "    this.focalPoints = const <int, StudioFocalPoint>{},\n"
        "    this.photoFits = const <int, StudioPhotoFit>{},\n"
        "    this.playing = true,",
        'preview constructor fits',
    )

    s = replace_once(
        s,
        "  final Map<int, StudioFocalPoint> focalPoints;\n"
        "  final bool playing;",
        "  final Map<int, StudioFocalPoint> focalPoints;\n"
        "  final Map<int, StudioPhotoFit> photoFits;\n"
        "  final bool playing;",
        'preview field fits',
    )

    old = """    final focal = widget.focalPoints[index] ?? const StudioFocalPoint();
    final alignment = Alignment(
      focal.x.clamp(0.0, 1.0) * 2 - 1,
      focal.y.clamp(0.0, 1.0) * 2 - 1,
    );
    return Transform.translate(
      offset: Offset(
        frame.x * constraints.maxWidth,
        frame.y * constraints.maxHeight,
      ),
      child: Transform.scale(
        scale: frame.scale,
        child: SizedBox.expand(
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            alignment: alignment,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
"""
    new = """    final photoFit = widget.photoFits[index] ?? StudioPhotoFit.portrait;
    if (photoFit == StudioPhotoFit.fit) {
      return ColoredBox(
        color: Colors.black,
        child: SizedBox.expand(
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          ),
        ),
      );
    }

    final focal = widget.focalPoints[index] ?? const StudioFocalPoint();
    final alignment = Alignment(
      focal.x.clamp(0.0, 1.0) * 2 - 1,
      focal.y.clamp(0.0, 1.0) * 2 - 1,
    );
    return Transform.translate(
      offset: Offset(
        frame.x * constraints.maxWidth,
        frame.y * constraints.maxHeight,
      ),
      child: Transform.scale(
        scale: frame.scale,
        child: SizedBox.expand(
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            alignment: alignment,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
"""
    s = replace_once(s, old, new, 'preview fit rendering')

    p.write_text(s)


def patch_repository() -> None:
    p = Path('lib/src/features/studio/data/studio_render_repository.dart')
    s = p.read_text()
    s = replace_once(
        s,
        "        photoCount: imageUrls.length,\n"
        "        focalPoints: project.focalPoints,\n"
        "      ),",
        "        photoCount: imageUrls.length,\n"
        "        focalPoints: project.focalPoints,\n"
        "        photoFits: project.photoFits,\n"
        "      ),",
        'repository manifest fits',
    )
    p.write_text(s)


def patch_node_renderer() -> None:
    p = Path('api/studio-render-node.js')
    s = p.read_text()

    s = replace_once(
        s,
        "      focalY: clamp(focal.y ?? 0.5, 0, 1),\n"
        "      easing: String(shot.easing ?? 'easeInOut'),",
        "      focalY: clamp(focal.y ?? 0.5, 0, 1),\n"
        "      fit: String(shot.fit ?? 'portrait') === 'fit' ? 'fit' : 'portrait',\n"
        "      easing: String(shot.easing ?? 'easeInOut'),",
        'node sanitize fit',
    )

    old = """  const filter =
    `scale=${WORK_WIDTH}:${WORK_HEIGHT}:force_original_aspect_ratio=increase:` +
    `force_divisible_by=2:flags=lanczos,` +
    `crop=${WORK_WIDTH}:${WORK_HEIGHT}:'max(0,min(iw-${WORK_WIDTH},${cropX}))':` +
    `'max(0,min(ih-${WORK_HEIGHT},${cropY}))',` +
    `setsar=1,` +
    `zoompan=z='${zoom}':x='${stableX}':y='${stableY}':` +
    `d=${frameCount}:s=${WIDTH}x${HEIGHT}:fps=${FPS},` +
    `fps=${FPS},setsar=1,format=yuv420p`;
"""
    new = """  const portraitFilter =
    `scale=${WORK_WIDTH}:${WORK_HEIGHT}:force_original_aspect_ratio=increase:` +
    `force_divisible_by=2:flags=lanczos,` +
    `crop=${WORK_WIDTH}:${WORK_HEIGHT}:'max(0,min(iw-${WORK_WIDTH},${cropX}))':` +
    `'max(0,min(ih-${WORK_HEIGHT},${cropY}))',` +
    `setsar=1,` +
    `zoompan=z='${zoom}':x='${stableX}':y='${stableY}':` +
    `d=${frameCount}:s=${WIDTH}x${HEIGHT}:fps=${FPS},` +
    `fps=${FPS},setsar=1,format=yuv420p`;
  const fitFilter =
    `scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease:` +
    `force_divisible_by=2:flags=lanczos,` +
    `pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1,` +
    `zoompan=z='1':x='0':y='0':d=${frameCount}:` +
    `s=${WIDTH}x${HEIGHT}:fps=${FPS},` +
    `fps=${FPS},setsar=1,format=yuv420p`;
  const filter = shot.fit === 'fit' ? fitFilter : portraitFilter;
"""
    s = replace_once(s, old, new, 'node portrait/fit filter')
    p.write_text(s)


def patch_server_renderer() -> None:
    p = Path('api/studio-render.js')
    s = p.read_text()
    s = replace_once(
        s,
        "    focalY: finite(focal?.y, .5, 0, 1),\n"
        "  };",
        "    focalY: finite(focal?.y, .5, 0, 1),\n"
        "    fit: String(raw?.fit ?? 'portrait') === 'fit' ? 'fit' : 'portrait',\n"
        "  };",
        'server sanitize fit',
    )
    s = replace_once(
        s,
        "function buildShotFilter(shot) {\n"
        "  const frames = Math.max(2, Math.round(shot.duration * OUTPUT_FPS));\n"
        "  const t = `min(1,on/${Math.max(1, frames - 1)})`;",
        "function buildShotFilter(shot) {\n"
        "  const frames = Math.max(2, Math.round(shot.duration * OUTPUT_FPS));\n"
        "  if (shot.fit === 'fit') {\n"
        "    return (\n"
        "      `scale=${OUTPUT_WIDTH}:${OUTPUT_HEIGHT}:force_original_aspect_ratio=decrease,` +\n"
        "      `pad=${OUTPUT_WIDTH}:${OUTPUT_HEIGHT}:(ow-iw)/2:(oh-ih)/2:color=black,` +\n"
        "      `setsar=1,zoompan=z='1':x='0':y='0':d=${frames}:` +\n"
        "      `s=${OUTPUT_WIDTH}x${OUTPUT_HEIGHT}:fps=${OUTPUT_FPS},` +\n"
        "      `fps=${OUTPUT_FPS},setpts=PTS-STARTPTS,format=yuv420p`\n"
        "    );\n"
        "  }\n"
        "  const t = `min(1,on/${Math.max(1, frames - 1)})`;",
        'server fit filter',
    )
    p.write_text(s)


def patch_client_renderer() -> None:
    p = Path('api/studio-render-client.js')
    s = p.read_text()
    s = replace_once(
        s,
        "    focalY: finite(focal.y, 0.5, 0, 1),\n"
        "    transition,",
        "    focalY: finite(focal.y, 0.5, 0, 1),\n"
        "    fit: String(shot.fit ?? 'portrait') === 'fit' ? 'fit' : 'portrait',\n"
        "    transition,",
        'client sanitize fit',
    )

    s = replace_once(
        s,
        "    const shot = shots[i];\n"
        "    const frames = Math.max(2, Math.round(shot.duration * OUTPUT_FPS));\n"
        "    const denom = Math.max(1, frames - 1);",
        "    const shot = shots[i];\n"
        "    const frames = Math.max(2, Math.round(shot.duration * OUTPUT_FPS));\n"
        "    if (shot.fit === 'fit') {\n"
        "      filters.push(\n"
        "        `[${i}:v]scale=${OUTPUT_WIDTH}:${OUTPUT_HEIGHT}:force_original_aspect_ratio=decrease,` +\n"
        "          `pad=${OUTPUT_WIDTH}:${OUTPUT_HEIGHT}:(ow-iw)/2:(oh-ih)/2:color=black,` +\n"
        "          `setsar=1,trim=duration=${shot.duration.toFixed(3)},setpts=PTS-STARTPTS,` +\n"
        "          `fps=${OUTPUT_FPS},settb=AVTB,format=yuv420p[v${i}]`,\n"
        "      );\n"
        "      continue;\n"
        "    }\n"
        "    const denom = Math.max(1, frames - 1);",
        'client fit filter',
    )
    p.write_text(s)


def patch_tests() -> None:
    p = Path('test/studio_cinematic_template_test.dart')
    s = p.read_text()
    s = replace_once(
        s,
        "        focalPoints: const <int, StudioFocalPoint>{\n"
        "          0: StudioFocalPoint(x: -.2, y: 1.5),\n"
        "          2: StudioFocalPoint(x: .8, y: .1),\n"
        "        },\n"
        "      );",
        "        focalPoints: const <int, StudioFocalPoint>{\n"
        "          0: StudioFocalPoint(x: -.2, y: 1.5),\n"
        "          2: StudioFocalPoint(x: .8, y: .1),\n"
        "        },\n"
        "        photoFits: const <int, StudioPhotoFit>{\n"
        "          1: StudioPhotoFit.fit,\n"
        "        },\n"
        "      );",
        'test render fit input',
    )
    s = replace_once(
        s,
        "      expect((shots[2]['focal'] as Map)['x'], .8);\n"
        "      expect((shots[2]['focal'] as Map)['y'], .1);\n",
        "      expect((shots[2]['focal'] as Map)['x'], .8);\n"
        "      expect((shots[2]['focal'] as Map)['y'], .1);\n"
        "      expect(shots[0]['fit'], StudioPhotoFit.portrait.name);\n"
        "      expect(shots[1]['fit'], StudioPhotoFit.fit.name);\n"
        "      expect(shots[2]['fit'], StudioPhotoFit.portrait.name);\n",
        'test render fit output',
    )

    insertion = """

    test('Studio project keeps per-photo portrait/fit choices', () {
      const project = StudioProject(
        templateId: 'test-template',
        templateVersion: 1,
        category: StudioCategory.property,
        audioPresetId: 'clean_ambient',
        photoFits: <int, StudioPhotoFit>{
          0: StudioPhotoFit.portrait,
          2: StudioPhotoFit.fit,
        },
      );

      final restored = StudioProject.fromJson(project.toJson());
      expect(restored.photoFits[0], StudioPhotoFit.portrait);
      expect(restored.photoFits[2], StudioPhotoFit.fit);
      expect(restored.photoFits[1] ?? StudioPhotoFit.portrait, StudioPhotoFit.portrait);
    });
"""
    s = replace_once(
        s,
        "\n    test('category aliases map into the right Studio family', () {",
        insertion + "\n    test('category aliases map into the right Studio family', () {",
        'test project fit roundtrip',
    )
    p.write_text(s)


def validate() -> None:
    required = {
        'lib/src/features/studio/domain/cinematic_template.dart': [
            'enum StudioPhotoFit { portrait, fit }',
            "'photo_fits'",
            "'fit': (photoFits[i] ?? StudioPhotoFit.portrait).name",
        ],
        'lib/src/features/studio/presentation/screens/studio_composer_screen.dart': [
            "label: const Text('PORTRAIT')",
            "label: const Text('FIT')",
            'photoFits: _photoFits',
        ],
        'lib/src/features/studio/presentation/widgets/cinematic_preview.dart': [
            'StudioPhotoFit.fit',
            'fit: BoxFit.contain',
            'fit: BoxFit.cover',
        ],
        'api/studio-render-node.js': [
            "shot.fit === 'fit' ? fitFilter : portraitFilter",
            'force_original_aspect_ratio=decrease',
        ],
        'api/studio-render.js': ["shot.fit === 'fit'"],
        'api/studio-render-client.js': ["shot.fit === 'fit'"],
    }
    for path, needles in required.items():
        text = Path(path).read_text()
        for needle in needles:
            if needle not in text:
                raise SystemExit(f'{path}: missing validation token: {needle}')


if __name__ == '__main__':
    patch_domain()
    patch_composer()
    patch_preview()
    patch_repository()
    patch_node_renderer()
    patch_server_renderer()
    patch_client_renderer()
    patch_tests()
    validate()
    print('Studio photo framing patch applied successfully.')
