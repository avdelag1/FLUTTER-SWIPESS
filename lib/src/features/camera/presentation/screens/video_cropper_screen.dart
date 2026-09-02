import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/camera/data/video_recut.dart';
import 'package:flutter_swipes/src/features/camera/domain/video_trim_selection.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

/// Full-screen video editor with a thumbnail filmstrip and a draggable,
/// five-second-snapped selection window.
class VideoCropperScreen extends StatefulWidget {
  const VideoCropperScreen({super.key, required this.file});

  final XFile file;

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
  String? _error;

  _TrimDragMode _dragMode = _TrimDragMode.move;
  VideoTrimSelection? _dragOrigin;
  double _dragDx = 0;

  @override
  void initState() {
    super.initState();
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
    _timelineScroll.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_processing || !_ready) return;
    AppHaptics.medium();
    if (_selection.length > VideoCropperScreen.maxSeconds + 0.05) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a clip up to 20 seconds.')),
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
          const SizedBox(
            width: 48,
            child: Icon(
              Icons.content_cut_rounded,
              color: AppTheme.brandPrimary,
            ),
          ),
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
              child: VideoPlayer(_player!),
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
            'Drag an edge to resize · drag the middle to move the whole clip',
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
            child: timeline,
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

  Widget _buildPresetRow() {
    const presets = [5.0, 10.0, 15.0, 20.0];
    return Row(
      children: [
        for (var i = 0; i < presets.length; i++) ...[
          if (i > 0) const SizedBox(width: 7),
          Expanded(child: _presetButton(presets[i])),
        ],
      ],
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
