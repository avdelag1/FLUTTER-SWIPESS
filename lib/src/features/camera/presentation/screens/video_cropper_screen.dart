import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/add/presentation/screens/listing_audio_trim_screen.dart';
import 'package:flutter_swipes/src/features/camera/data/video_recut.dart';
import 'package:flutter_swipes/src/features/camera/domain/video_trim_selection.dart';
import 'package:flutter_swipes/src/features/swipes/domain/listing_soundtrack.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

/// Full-screen video editor with a thumbnail filmstrip and a draggable,
/// five-second-snapped selection window.
class VideoCropperScreen extends StatefulWidget {
  const VideoCropperScreen({
    super.key,
    required this.file,
    this.videoAudioEnabled = true,
    this.backgroundMusic,
    this.backgroundMusicPreset,
    this.backgroundMusicName,
    this.onVideoAudioChanged,
    this.onBackgroundMusicFile,
    this.onBackgroundMusicPreset,
    this.onBackgroundMusicClear,
  });

  final XFile file;
  final bool videoAudioEnabled;
  final XFile? backgroundMusic;
  final String? backgroundMusicPreset;
  final String? backgroundMusicName;
  final ValueChanged<bool>? onVideoAudioChanged;
  final ValueChanged<XFile>? onBackgroundMusicFile;
  final void Function(String id, String label)? onBackgroundMusicPreset;
  final VoidCallback? onBackgroundMusicClear;

  static const maxSeconds = VideoTrimSelection.maxSeconds;
  static const timelineViewportSeconds = 60.0;

  @override
  State<VideoCropperScreen> createState() => _VideoCropperScreenState();
}

enum _TrimDragMode { left, move, right }

class _VideoCropperScreenState extends State<VideoCropperScreen> {
  final ScrollController _timelineScroll = ScrollController();

  VideoPlayerController? _player;
  VideoTrimSelection _selection = VideoTrimSelection.initial(0);
  List<Uint8List?> _thumbnails = const [];
  double _duration = 0;
  bool _ready = false;
  bool _processing = false;
  bool _videoAudioEnabled = true;
  XFile? _backgroundMusic;
  String? _backgroundMusicPreset;
  String? _backgroundMusicName;
  final ListingSoundtrackPlayer _soundtrackPreview = ListingSoundtrackPlayer();
  String? _error;

  _TrimDragMode _dragMode = _TrimDragMode.move;
  VideoTrimSelection? _dragOrigin;
  double _dragDx = 0;

  @override
  void initState() {
    super.initState();
    _videoAudioEnabled = widget.videoAudioEnabled;
    _backgroundMusic = widget.backgroundMusic;
    _backgroundMusicPreset = widget.backgroundMusicPreset;
    _backgroundMusicName = widget.backgroundMusicName;
    _boot();
  }

  Future<void> _boot() async {
    try {
      final path = widget.file.path;
      final controller =
          (!kIsWeb && !path.startsWith('http') && !path.startsWith('blob:'))
          ? VideoPlayerController.file(File(path))
          : VideoPlayerController.networkUrl(Uri.parse(path));
      await controller.initialize();
      final dur = controller.value.duration.inMilliseconds / 1000.0;
      controller.addListener(_onTick);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _player = controller;
        _duration = dur;
        _selection = VideoTrimSelection.initial(dur);
        _ready = true;
      });
      await controller.setVolume(_videoAudioEnabled ? 1 : 0);
      await controller.seekTo(_toDuration(_selection.start));
      await controller.play();
      _loadThumbnails();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _loadThumbnails() async {
    if (_duration <= 0) return;
    final frameCount = math
        .max(
          1,
          math.min(120, (_duration / VideoTrimSelection.stepSeconds).ceil()),
        )
        .toInt();
    if (!mounted) return;
    setState(() => _thumbnails = List<Uint8List?>.filled(frameCount, null));

    for (var i = 0; i < frameCount; i++) {
      if (!mounted) return;
      final sampleSecond = math.min(
        math.max(0, _duration - 0.05),
        i * VideoTrimSelection.stepSeconds + VideoTrimSelection.stepSeconds / 2,
      );
      try {
        final bytes = await VideoThumbnail.thumbnailData(
          video: widget.file.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 160,
          quality: 38,
          timeMs: (sampleSecond * 1000).round(),
        );
        if (!mounted || i >= _thumbnails.length) return;
        setState(() => _thumbnails[i] = bytes);
      } catch (_) {
        // The timeline still works if a platform cannot sample a frame.
      }
    }
  }

  void _onTick() {
    final player = _player;
    if (player == null || !player.value.isInitialized) return;
    final position = player.value.position.inMilliseconds / 1000.0;
    if (position >= _selection.end - 0.05 ||
        position < _selection.start - 0.05) {
      player.seekTo(_toDuration(_selection.start));
    }
  }

  Duration _toDuration(double seconds) =>
      Duration(milliseconds: (seconds * 1000).round());

  Future<void> _seekToSelectionStart() async {
    final player = _player;
    if (player == null || !player.value.isInitialized) return;
    await player.seekTo(_toDuration(_selection.start));
    if (!player.value.isPlaying) await player.play();
  }

  void _applyPreset(double seconds) {
    if (_duration + 0.01 < seconds) return;
    AppHaptics.light();
    setState(() => _selection = _selection.preset(seconds));
    _seekToSelectionStart();
    _ensureSelectionVisible();
  }

  void _jumpSelectionTo(double tappedSecond) {
    if (!_ready || _duration <= 0) return;
    final targetStart = tappedSecond - (_selection.length / 2);
    final next = _selection.moveTo(targetStart);
    if (next.start == _selection.start && next.end == _selection.end) return;
    AppHaptics.selection();
    setState(() => _selection = next);
    _seekToSelectionStart();
    _ensureSelectionVisible();
  }

  Future<void> _setVideoAudio(bool enabled) async {
    if (_videoAudioEnabled == enabled) return;
    AppHaptics.light();
    setState(() => _videoAudioEnabled = enabled);
    await _player?.setVolume(enabled ? 1 : 0);
    widget.onVideoAudioChanged?.call(enabled);
  }

  Future<void> _pickOwnMusic() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'aac', 'wav', 'ogg'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final picked = result.files.first;
    if (picked.size > 15 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Music file must be under 15MB.')),
      );
      return;
    }
    XFile? file;
    if (picked.bytes != null) {
      file = XFile.fromData(
        picked.bytes!,
        name: picked.name,
        length: picked.size,
      );
    } else if (picked.path != null && picked.path!.isNotEmpty) {
      file = XFile(picked.path!, name: picked.name);
    }
    if (file == null || !mounted) return;
    setState(() {
      _backgroundMusic = file;
      _backgroundMusicPreset = null;
      _backgroundMusicName = file!.name;
    });
    widget.onBackgroundMusicFile?.call(file);
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
  }

  Future<void> _selectBuiltInMusic(ListingSoundtrackPreset preset) async {
    setState(() {
      _backgroundMusic = null;
      _backgroundMusicPreset = preset.id;
      _backgroundMusicName = preset.label;
    });
    widget.onBackgroundMusicPreset?.call(preset.id, preset.label);
    await _setVideoAudio(false);
    try {
      await _soundtrackPreview.play(presetId: preset.id, volume: .58);
    } catch (_) {}
  }

  Future<void> _clearMusic() async {
    await _soundtrackPreview.stop();
    if (!mounted) return;
    setState(() {
      _backgroundMusic = null;
      _backgroundMusicPreset = null;
      _backgroundMusicName = null;
    });
    widget.onBackgroundMusicClear?.call();
  }

  Future<void> _showAudioSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.library_music_rounded, color: AppTheme.brandPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AUDIO & MUSIC',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _pickOwnMusic();
                        },
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('UPLOAD MY MUSIC'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.brandPrimary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _setVideoAudio(!_videoAudioEnabled),
                      icon: Icon(
                        _videoAudioEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                      ),
                      label: Text(_videoAudioEnabled ? 'ORIGINAL ON' : 'MUTED'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'SWIPESS AUDIO · 10 BUILT-IN SOUNDS',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: listingSoundtrackPresets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final preset = listingSoundtrackPresets[index];
                      final selected = _backgroundMusicPreset == preset.id;
                      return InkWell(
                        onTap: () => _selectBuiltInMusic(preset),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 118,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.brandPrimary.withAlpha(36)
                                : Colors.white.withAlpha(10),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? AppTheme.brandPrimary : Colors.white24,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(preset.emoji, style: const TextStyle(fontSize: 20)),
                              const Spacer(),
                              Text(
                                preset.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if ((_backgroundMusicName ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.music_note_rounded, color: Color(0xFF34D399), size: 18),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          _backgroundMusicName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _clearMusic,
                        child: const Text('REMOVE'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _beginSelectionDrag(DragStartDetails details, double selectionWidth) {
    _dragOrigin = _selection;
    _dragDx = 0;
    final edgeZone = math.min(14.0, selectionWidth * 0.30);
    final x = details.localPosition.dx;
    _dragMode = x <= edgeZone
        ? _TrimDragMode.left
        : x >= selectionWidth - edgeZone
        ? _TrimDragMode.right
        : _TrimDragMode.move;
    AppHaptics.light();
  }

  void _updateSelectionDrag(DragUpdateDetails details, double pixelsPerSecond) {
    final origin = _dragOrigin;
    if (origin == null || pixelsPerSecond <= 0) return;
    _dragDx += details.primaryDelta ?? 0;
    final secondsDelta = _dragDx / pixelsPerSecond;
    final next = switch (_dragMode) {
      _TrimDragMode.left => origin.resizeStartTo(origin.start + secondsDelta),
      _TrimDragMode.right => origin.resizeEndTo(origin.end + secondsDelta),
      _TrimDragMode.move => origin.moveTo(origin.start + secondsDelta),
    };
    if (next.start == _selection.start && next.end == _selection.end) return;
    setState(() => _selection = next);
    _seekToSelectionStart();
  }

  void _endSelectionDrag(DragEndDetails _) {
    _dragOrigin = null;
    _dragDx = 0;
    AppHaptics.medium();
    _ensureSelectionVisible();
  }

  void _ensureSelectionVisible() {
    if (!_timelineScroll.hasClients ||
        _duration <= VideoCropperScreen.timelineViewportSeconds) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_timelineScroll.hasClients || !mounted) return;
      final viewport = _timelineScroll.position.viewportDimension;
      if (viewport <= 0) return;
      final pixelsPerSecond =
          viewport / VideoCropperScreen.timelineViewportSeconds;
      final left = _selection.start * pixelsPerSecond;
      final right = _selection.end * pixelsPerSecond;
      final current = _timelineScroll.offset;
      var target = current;
      if (left < current + 20) {
        target = math.max(0.0, left - 20).toDouble();
      } else if (right > current + viewport - 20) {
        target = math
            .min(
              _timelineScroll.position.maxScrollExtent,
              right - viewport + 20,
            )
            .toDouble();
      }
      if ((target - current).abs() > 1) {
        _timelineScroll.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _player?.removeListener(_onTick);
    _player?.dispose();
    _soundtrackPreview.dispose();
    _timelineScroll.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_processing || !_ready) return;
    AppHaptics.medium();
    if (_selection.length > VideoCropperScreen.maxSeconds + 0.05) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a clip up to 60 seconds.')),
      );
      return;
    }
    setState(() => _processing = true);
    try {
      await _player?.pause();
      final cropped = await recutVideoWindow(
        source: widget.file,
        start: _selection.start,
        end: _selection.end,
      );
      if (!mounted) return;
      Navigator.pop(context, cropped);
    } catch (_) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not recut video — try a shorter clip.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.dashBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildEditorHeader(),
            Expanded(child: _buildPreview()),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close editor',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
          Expanded(
            child: Text(
              'TRIM VIDEO',
              textAlign: TextAlign.center,
              style: AppTheme.displayItalic.copyWith(fontSize: 18),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_error != null) {
      return Center(
        child: Text(
          'Could not preview video',
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
        ),
      );
    }
    if (!_ready) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      );
    }
    final aspect = _player!.value.aspectRatio == 0
        ? 16 / 9
        : _player!.value.aspectRatio;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: aspect,
            child: ColoredBox(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoPlayer(_player!),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _previewAction(
                          tooltip: _videoAudioEnabled ? 'Mute original video' : 'Turn original video sound on',
                          icon: _videoAudioEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                          active: !_videoAudioEnabled,
                          onTap: () => _setVideoAudio(!_videoAudioEnabled),
                        ),
                        const SizedBox(width: 7),
                        _previewAction(
                          tooltip: 'Audio and music',
                          icon: Icons.library_music_rounded,
                          active: (_backgroundMusicName ?? '').isNotEmpty,
                          onTap: _showAudioSheet,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(22),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'FILMSTRIP · 5 SECOND SNAP',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Tap the filmstrip to jump the whole clip · drag the middle for fine movement · drag edges to resize',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(height: 82, child: _buildTimeline()),
          const SizedBox(height: 10),
          _buildPresetRow(),
          const SizedBox(height: 10),
          Text(
            '${_formatTime(_selection.start)}  →  ${_formatTime(_selection.end)}   ·   ${_selection.length.toStringAsFixed(_selection.length % 1 == 0 ? 0 : 1)}s',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: (_ready && !_processing) ? _confirm : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.brandPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              icon: _processing
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 20),
              label: Text(
                _processing ? 'PROCESSING…' : 'SAVE VIDEO',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    if (!_ready || _duration <= 0) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(14),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = math.max(1.0, constraints.maxWidth).toDouble();
        final visibleSeconds =
            _duration <= VideoCropperScreen.timelineViewportSeconds
            ? math.max(0.1, _duration).toDouble()
            : VideoCropperScreen.timelineViewportSeconds;
        final pixelsPerSecond = viewportWidth / visibleSeconds;
        final totalWidth = math
            .max(viewportWidth, _duration * pixelsPerSecond)
            .toDouble();
        final selectionLeft = _selection.start * pixelsPerSecond;
        final selectionWidth = math
            .max(1.0, _selection.length * pixelsPerSecond)
            .toDouble();
        final selectionRight = selectionLeft + selectionWidth;

        final timeline = SizedBox(
          width: totalWidth,
          height: 82,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _buildFilmstrip(pixelsPerSecond),
                ),
              ),
              if (selectionLeft > 0)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: selectionLeft,
                  child: ColoredBox(color: Colors.black.withAlpha(132)),
                ),
              if (selectionRight < totalWidth)
                Positioned(
                  left: selectionRight,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: ColoredBox(color: Colors.black.withAlpha(132)),
                ),
              Positioned(
                left: selectionLeft,
                top: 0,
                width: selectionWidth,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (details) =>
                      _beginSelectionDrag(details, selectionWidth),
                  onHorizontalDragUpdate: (details) =>
                      _updateSelectionDrag(details, pixelsPerSecond),
                  onHorizontalDragEnd: _endSelectionDrag,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTheme.brandPrimary.withAlpha(22),
                      border: Border.all(
                        color: AppTheme.brandPrimary,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.brandPrimary.withAlpha(52),
                          blurRadius: 12,
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 4,
                          top: 15,
                          bottom: 15,
                          child: _edgeHandle(),
                        ),
                        Positioned(
                          right: 4,
                          top: 15,
                          bottom: 15,
                          child: _edgeHandle(),
                        ),
                        if (selectionWidth >= 36)
                          const Icon(
                            Icons.drag_indicator_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_player != null)
                AnimatedBuilder(
                  animation: _player!,
                  builder: (context, _) {
                    final position =
                        _player!.value.position.inMilliseconds / 1000.0;
                    final x =
                        position.clamp(0.0, _duration).toDouble() *
                        pixelsPerSecond;
                    return Positioned(
                      left: x
                          .clamp(0.0, math.max(0.0, totalWidth - 2))
                          .toDouble(),
                      top: 3,
                      bottom: 3,
                      width: 2,
                      child: const ColoredBox(color: Colors.white),
                    );
                  },
                ),
            ],
          ),
        );

        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SingleChildScrollView(
            controller: _timelineScroll,
            scrollDirection: Axis.horizontal,
            physics: _duration > VideoCropperScreen.timelineViewportSeconds
                ? const BouncingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  _jumpSelectionTo(details.localPosition.dx / pixelsPerSecond),
              child: timeline,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilmstrip(double pixelsPerSecond) {
    final segmentCount = math
        .max(1, (_duration / VideoTrimSelection.stepSeconds).ceil())
        .toInt();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < segmentCount; i++)
          SizedBox(
            width: math
                .max(
                  1.0,
                  math.min(
                        VideoTrimSelection.stepSeconds,
                        _duration - i * VideoTrimSelection.stepSeconds,
                      ) *
                      pixelsPerSecond,
                )
                .toDouble(),
            child: _TimelineFrame(
              bytes: i < _thumbnails.length ? _thumbnails[i] : null,
              label: _formatTime(i * VideoTrimSelection.stepSeconds),
            ),
          ),
      ],
    );
  }

  Widget _edgeHandle() {
    return Container(
      width: 4,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _previewAction({
    required String tooltip,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? AppTheme.brandPrimary.withAlpha(220)
            : Colors.black.withAlpha(160),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: Colors.white, size: 21),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetRow() {
    const presets = [
      5.0, 10.0, 15.0, 20.0, 25.0, 30.0,
      35.0, 40.0, 45.0, 50.0, 55.0, 60.0,
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: presets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, index) => SizedBox(
          width: 68,
          child: _presetButton(presets[index]),
        ),
      ),
    );
  }

  Widget _presetButton(double seconds) {
    final enabled = _duration + 0.01 >= seconds;
    final active = (_selection.length - seconds).abs() < 0.05;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => _applyPreset(seconds) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? AppTheme.brandPrimary
              : Colors.white.withAlpha(enabled ? 13 : 5),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? AppTheme.brandPrimary
                : Colors.white.withAlpha(enabled ? 38 : 14),
          ),
        ),
        child: Text(
          '${seconds.toInt()}s',
          style: GoogleFonts.plusJakartaSans(
            color: enabled ? Colors.white : Colors.white30,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  String _formatTime(double seconds) {
    final value = math.max(0, seconds.round()).toInt();
    final minutes = value ~/ 60;
    final rest = value % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }
}

class _TimelineFrame extends StatelessWidget {
  const _TimelineFrame({required this.bytes, required this.label});

  final Uint8List? bytes;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF22252B),
        border: Border(
          right: BorderSide(color: Colors.black.withAlpha(90), width: 1),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (bytes != null)
            Image.memory(bytes!, fit: BoxFit.cover, gaplessPlayback: true)
          else
            const Center(
              child: Icon(
                Icons.movie_outlined,
                color: Colors.white24,
                size: 18,
              ),
            ),
          Positioned(
            left: 4,
            bottom: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(118),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
