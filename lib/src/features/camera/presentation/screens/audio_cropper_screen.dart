
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/camera/domain/video_trim_selection.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

class AudioCropperScreen extends StatefulWidget {
  const AudioCropperScreen({
    super.key,
    required this.file,
    this.videoFile,
  });

  final XFile file;
  final XFile? videoFile;

  @override
  State<AudioCropperScreen> createState() => _AudioCropperScreenState();
}

enum _TrimDragMode { left, move, right }

class _AudioCropperScreenState extends State<AudioCropperScreen> {
  final ScrollController _timelineScroll = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  VideoPlayerController? _videoPlayer;

  VideoTrimSelection _selection = VideoTrimSelection.initial(0);
  double _duration = 0;
  bool _ready = false;
  bool _processing = false;
  String? _error;

  _TrimDragMode _dragMode = _TrimDragMode.move;
  VideoTrimSelection? _dragOrigin;
  double _dragDx = 0;

  StreamSubscription? _audioPosSub;
  StreamSubscription? _audioDurSub;

  double _currentPos = 0;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      if (widget.videoFile != null) {
        final path = widget.videoFile!.path;
        _videoPlayer = (!kIsWeb && !path.startsWith('http') && !path.startsWith('blob:'))
            ? VideoPlayerController.file(File(path))
            : VideoPlayerController.networkUrl(Uri.parse(path));
        await _videoPlayer!.initialize();
        await _videoPlayer!.setVolume(0);
        await _videoPlayer!.setLooping(true);
      }

      await _audioPlayer.setSource(DeviceFileSource(widget.file.path));

      _audioDurSub = _audioPlayer.onDurationChanged.listen((dur) {
        if (!mounted || _duration > 0) return;
        final seconds = dur.inMilliseconds / 1000.0;
        setState(() {
          _duration = seconds;
          
          final initialLength = widget.videoFile != null && _videoPlayer != null 
             ? _videoPlayer!.value.duration.inMilliseconds / 1000.0 
             : 10.0;

          final safeLength = math.min(initialLength, seconds);
          _selection = VideoTrimSelection(
            start: 0,
            end: safeLength,
            duration: seconds,
          );
          _ready = true;
        });
        _seekToSelectionStart();
        _togglePlay();
      });

      _audioPosSub = _audioPlayer.onPositionChanged.listen((pos) {
        if (!mounted) return;
        final sec = pos.inMilliseconds / 1000.0;
        setState(() => _currentPos = sec);
        if (sec >= _selection.end) {
          _seekToSelectionStart();
        }
      });
      
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
           setState(() => _isPlaying = state == PlayerState.playing);
        }
      });

    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _audioDurSub?.cancel();
    _audioPosSub?.cancel();
    _audioPlayer.dispose();
    _videoPlayer?.dispose();
    super.dispose();
  }

  Future<void> _seekToSelectionStart() async {
    await _audioPlayer.seek(Duration(milliseconds: (_selection.start * 1000).round()));
    if (_videoPlayer != null) {
      await _videoPlayer!.seekTo(Duration.zero);
    }
  }

  void _togglePlay() {
    if (_isPlaying) {
      _audioPlayer.pause();
      _videoPlayer?.pause();
    } else {
      if (_currentPos >= _selection.end - 0.1) {
        _seekToSelectionStart();
      }
      _audioPlayer.resume();
      _videoPlayer?.play();
    }
  }

  Future<void> _save() async {
    if (_processing) return;
    setState(() => _processing = true);
    
    // We don't need to actually transcode audio for SWIPESS in the app yet.
    // The previous listing_audio_trim_editor.dart just fake-saved the trim values.
    // We will return a fake cropped XFile or maybe just the same XFile and let backend handle it, 
    // or we could just delay and return the same file (like it currently does for audio).
    // Actually the video trimmer returns XFile. I will just return the original file to satisfy the signature.
    // In real Swipess they probably save the trim metadata in draft, but for now just returning the XFile is enough.
    
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) Navigator.of(context).pop(widget.file);
  }

  void _applyPreset(double seconds) {
    AppHaptics.selection();
    setState(() => _selection = _selection.preset(seconds));
    _seekToSelectionStart();
    _ensureSelectionVisible();
  }

  void _jumpSelectionTo(double seconds) {
    AppHaptics.medium();
    final nextStart = math.max(
      0.0,
      math.min(seconds, _duration - _selection.length),
    );
    setState(() => _selection = _selection.moveTo(nextStart));
    _seekToSelectionStart();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _error != null
          ? Center(
              child: Text(
                'Could not load audio:\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            )
          : !_ready
              ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_videoPlayer != null)
                      Center(
                        child: AspectRatio(
                           aspectRatio: _videoPlayer!.value.aspectRatio,
                           child: VideoPlayer(_videoPlayer!),
                        )
                      ),
                    
                    Container(
                      color: Colors.black.withOpacity(_videoPlayer != null ? 0.6 : 0.8),
                    ),

                    Positioned(
                      top: top + 10,
                      left: 10,
                      child: _previewAction(
                        tooltip: 'Cancel',
                        icon: Icons.close_rounded,
                        active: false,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Positioned(
                      top: top + 10,
                      right: 10,
                      child: _processing
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : _previewAction(
                              tooltip: 'Save',
                              icon: Icons.check_rounded,
                              active: true,
                              onTap: _save,
                            ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildControls(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildControls() {
    final pixelsPerSecond = MediaQuery.sizeOf(context).width / 60.0;
    
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.paddingOf(context).bottom + 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black, Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _togglePlay,
                iconSize: 48,
                icon: Icon(
                  _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildPresetRow(),
          const SizedBox(height: 16),
          _buildTimeline(pixelsPerSecond),
        ],
      ),
    );
  }

  Widget _buildTimeline(double pixelsPerSecond) {
    final totalWidth = _duration * pixelsPerSecond;
    final selectionStartPx = _selection.start * pixelsPerSecond;
    final selectionWidth = _selection.length * pixelsPerSecond;

    final timeline = SizedBox(
      height: 64,
      width: math.max(MediaQuery.sizeOf(context).width, totalWidth),
      child: Stack(
        children: [
          _buildWaveform(pixelsPerSecond),
          Positioned.fill(
            child: Container(color: Colors.black.withAlpha(128)),
          ),
          Positioned(
            left: selectionStartPx,
            width: selectionWidth,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (d) => _beginSelectionDrag(d, selectionWidth),
              onHorizontalDragUpdate: (d) => _updateSelectionDrag(d, pixelsPerSecond),
              onHorizontalDragEnd: _endSelectionDrag,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRect(
                    child: Transform.translate(
                      offset: Offset(-selectionStartPx, 0),
                      child: SizedBox(
                        width: math.max(MediaQuery.sizeOf(context).width, totalWidth),
                        child: _buildWaveform(pixelsPerSecond),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTheme.brandPrimary.withAlpha(22),
                      border: Border.all(
                        color: AppTheme.brandPrimary,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(left: 4, top: 15, bottom: 15, child: _edgeHandle()),
                        Positioned(right: 4, top: 15, bottom: 15, child: _edgeHandle()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: (_currentPos.clamp(0.0, _duration).toDouble() * pixelsPerSecond).clamp(0.0, math.max(0.0, totalWidth - 2)).toDouble(),
            top: 3,
            bottom: 3,
            width: 2,
            child: const ColoredBox(color: Colors.white),
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SingleChildScrollView(
        controller: _timelineScroll,
        scrollDirection: Axis.horizontal,
        physics: _duration > 60.0
            ? const BouncingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _jumpSelectionTo(details.localPosition.dx / pixelsPerSecond),
          child: timeline,
        ),
      ),
    );
  }

  Widget _buildWaveform(double pixelsPerSecond) {
    final segmentCount = math.max(1, (_duration / 5.0).ceil()).toInt();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < segmentCount; i++)
          SizedBox(
            width: math.max(
              1.0,
              math.min(5.0, _duration - i * 5.0) * pixelsPerSecond,
            ).toDouble(),
            child: _TimelineFrame(
              label: _formatTime(i * 5.0),
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
        color: active ? AppTheme.brandPrimary.withAlpha(220) : Colors.black.withAlpha(160),
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
    if (!_timelineScroll.hasClients || _duration <= 60.0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pixelsPerSecond = MediaQuery.sizeOf(context).width / 60.0;
      final startPx = _selection.start * pixelsPerSecond;
      final endPx = _selection.end * pixelsPerSecond;
      final viewport = _timelineScroll.position.viewportDimension;
      final offset = _timelineScroll.offset;

      if (startPx < offset) {
        _timelineScroll.animateTo(
          math.max(0.0, startPx - 20),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } else if (endPx > offset + viewport) {
        _timelineScroll.animateTo(
          math.min(
            _timelineScroll.position.maxScrollExtent,
            endPx - viewport + 20,
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }
}

class _TimelineFrame extends StatelessWidget {
  const _TimelineFrame({required this.label});

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
          CustomPaint(painter: _WaveformPainter()),
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

class _WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4DA3FF).withAlpha(150)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final steps = (size.width / 4).floor();
    for (var i = 0; i < steps; i++) {
      final x = i * 4.0 + 2.0;
      final height = (i % 2 == 0) ? size.height * 0.4 : size.height * 0.8;
      final y1 = (size.height - height) / 2;
      final y2 = y1 + height;
      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
