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
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

/// Selects which moment of an uploaded song is paired with the already
/// selected video window. The video window is authoritative and never changes
/// from this screen.
class AudioCropperScreenV2 extends StatefulWidget {
  const AudioCropperScreenV2({
    super.key,
    required this.file,
    this.videoFile,
    required this.maxClipSeconds,
    this.videoStartSeconds = 0,
    this.videoEndSeconds,
    this.portraitCrop = false,
    this.cropX = .5,
  });

  final XFile file;
  final XFile? videoFile;
  final double maxClipSeconds;
  final double videoStartSeconds;
  final double? videoEndSeconds;
  final bool portraitCrop;
  final double cropX;

  @override
  State<AudioCropperScreenV2> createState() => _AudioCropperScreenV2State();
}

class _AudioCropperScreenV2State extends State<AudioCropperScreenV2> {
  static const _audioAccent = Color(0xFF8B5CF6);
  static const _playAccent = Color(0xFF3B82F6);
  static const _saveAccent = Color(0xFF22C55E);

  final AudioPlayer _audio = AudioPlayer();
  final ScrollController _timeline = ScrollController();
  VideoPlayerController? _video;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;

  VideoTrimSelection _selection = VideoTrimSelection.initial(0);
  double _duration = 0;
  double _position = 0;
  bool _ready = false;
  bool _playing = false;
  bool _saving = false;
  bool _dragging = false;
  bool _resumeAfterDrag = false;
  String? _error;
  double _dragStartX = 0;
  double _dragStartSecond = 0;

  double get _videoStart => math.max(0.0, widget.videoStartSeconds);
  double get _videoWindow => widget.maxClipSeconds.clamp(1.0, 60.0).toDouble();
  double get _videoEnd => widget.videoEndSeconds ?? (_videoStart + _videoWindow);
  double get _audioWindow => math.min(_videoWindow, _duration).toDouble();

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<Source> _audioSource() async {
    if (!kIsWeb && widget.file.path.isNotEmpty) {
      return DeviceFileSource(widget.file.path);
    }
    return BytesSource(await widget.file.readAsBytes());
  }

  Future<void> _boot() async {
    try {
      if (widget.videoFile != null) {
        final path = widget.videoFile!.path;
        final controller =
            (!kIsWeb && !path.startsWith('http') && !path.startsWith('blob:'))
                ? VideoPlayerController.file(File(path))
                : VideoPlayerController.networkUrl(Uri.parse(path));
        await controller.initialize();
        await controller.setVolume(0);
        controller.addListener(_videoTick);
        _video = controller;
      }

      await _audio.setSource(await _audioSource());
      var duration = await _audio.getDuration();
      if (duration == null || duration.inMilliseconds <= 0) {
        final completer = Completer<Duration>();
        late StreamSubscription<Duration> sub;
        sub = _audio.onDurationChanged.listen((value) {
          if (!completer.isCompleted && value.inMilliseconds > 0) {
            completer.complete(value);
          }
        });
        try {
          duration = await completer.future.timeout(const Duration(seconds: 8));
        } finally {
          await sub.cancel();
        }
      }
      if (duration == null || duration.inMilliseconds <= 0) {
        throw StateError('Could not read this audio file.');
      }

      _duration = duration.inMilliseconds / 1000.0;
      var start = 0.0;
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          final row = await Supabase.instance.client
              .from('pending_listing_audio_trim')
              .select('start_ms')
              .eq('user_id', user.id)
              .maybeSingle();
          if (row != null) {
            start = (((row['start_ms'] as num?)?.toDouble() ?? 0) / 1000)
                .clamp(0.0, math.max(0.0, _duration - _audioWindow))
                .toDouble();
          }
        } catch (_) {}
      }
      _selection = _windowAt(start);

      _positionSub = _audio.onPositionChanged.listen((position) {
        if (!mounted) return;
        final seconds = position.inMilliseconds / 1000.0;
        setState(() => _position = seconds);
        if (_playing && !_dragging && seconds >= _selection.end - .03) {
          unawaited(_syncToSelection(resume: true));
        }
      });
      _stateSub = _audio.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _playing = state == PlayerState.playing);
      });

      if (!mounted) return;
      setState(() => _ready = true);
      await _syncToSelection(resume: true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _videoTick() {
    final video = _video;
    if (video == null || !video.value.isInitialized || _dragging) return;
    final pos = video.value.position.inMilliseconds / 1000.0;
    if (pos >= _videoEnd - .04 || pos < _videoStart - .04) {
      unawaited(video.seekTo(_d(_videoStart)));
    }
  }

  Duration _d(double seconds) => Duration(milliseconds: (seconds * 1000).round());

  VideoTrimSelection _windowAt(double rawStart) {
    if (_duration <= 0) return VideoTrimSelection.initial(0);
    final length = _audioWindow;
    final maxStart = math.max(0.0, _duration - length).toDouble();
    final start = rawStart.clamp(0.0, maxStart).toDouble();
    return VideoTrimSelection(
      start: start,
      end: math.min(_duration, start + length).toDouble(),
      duration: _duration,
    );
  }

  Future<void> _syncToSelection({required bool resume}) async {
    await _audio.pause();
    await _video?.pause();
    await _audio.seek(_d(_selection.start));
    _position = _selection.start;
    if (_video != null) await _video!.seekTo(_d(_videoStart));
    if (resume) {
      await _video?.play();
      await _audio.resume();
    }
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _audio.pause();
      await _video?.pause();
      return;
    }
    final video = _video;
    final videoPos = video?.value.position.inMilliseconds.toDouble() ?? 0;
    final videoOutsideCut = video != null &&
        (videoPos < _videoStart * 1000 || videoPos >= (_videoEnd - .03) * 1000);
    if (_position < _selection.start ||
        _position >= _selection.end - .03 ||
        videoOutsideCut) {
      await _syncToSelection(resume: true);
      return;
    }
    await _video?.play();
    await _audio.resume();
  }

  void _jump(double tappedSecond) {
    if (!_ready) return;
    final next = _windowAt(tappedSecond - _audioWindow / 2);
    final wasPlaying = _playing;
    AppHaptics.selection();
    setState(() => _selection = next);
    unawaited(_syncToSelection(resume: wasPlaying));
    _ensureVisible();
  }

  void _dragStart(DragStartDetails details, double pixelsPerSecond) {
    if (!_ready || pixelsPerSecond <= 0) return;
    _dragging = true;
    _resumeAfterDrag = _playing;
    _dragStartX = details.globalPosition.dx;
    _dragStartSecond = _selection.start;
    unawaited(_audio.pause());
    unawaited(_video?.pause());
    AppHaptics.light();
  }

  void _dragUpdate(DragUpdateDetails details, double pixelsPerSecond) {
    if (!_dragging || pixelsPerSecond <= 0) return;
    final delta = (details.globalPosition.dx - _dragStartX) / pixelsPerSecond;
    final next = _windowAt(_dragStartSecond + delta);
    if (next.start == _selection.start) return;
    setState(() {
      _selection = next;
      _position = next.start;
    });
  }

  void _dragEnd(DragEndDetails _) {
    if (!_dragging) return;
    _dragging = false;
    final resume = _resumeAfterDrag;
    _resumeAfterDrag = false;
    AppHaptics.medium();
    unawaited(_syncToSelection(resume: resume));
    _ensureVisible();
  }

  void _ensureVisible() {
    if (!_timeline.hasClients || _duration <= 60) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_timeline.hasClients || !mounted) return;
      final viewport = _timeline.position.viewportDimension;
      final pixelsPerSecond = viewport / 60;
      final left = _selection.start * pixelsPerSecond;
      final right = _selection.end * pixelsPerSecond;
      var target = _timeline.offset;
      if (left < target + 16) target = math.max(0.0, left - 16).toDouble();
      if (right > target + viewport - 16) {
        target = math
            .min(_timeline.position.maxScrollExtent, right - viewport + 16)
            .toDouble();
      }
      if ((target - _timeline.offset).abs() > 1) {
        _timeline.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _message('Sign in to save your music cut.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _audio.pause();
      await _video?.pause();
      final totalMs = (_duration * 1000).round();
      final start = (_selection.start * 1000)
          .round()
          .clamp(0, math.max(0, totalMs - 1));
      final end = (_selection.end * 1000).round().clamp(start + 1, totalMs);
      await Supabase.instance.client.from('pending_listing_audio_trim').upsert({
        'user_id': user.id,
        'start_ms': start,
        'end_ms': end >= totalMs ? null : end,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _message('Could not save the music position. Try again.');
      }
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    unawaited(_audio.dispose());
    _video?.removeListener(_videoTick);
    _video?.dispose();
    _timeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppTheme.dashBg,
        body: SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
            const Spacer(),
            Text('Could not load this audio.', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Choose the song again and retry.', style: GoogleFonts.plusJakartaSans(color: Colors.white54)),
            const Spacer(),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.dashBg,
      body: SafeArea(
        child: Column(children: [
          _header(),
          Expanded(child: _preview()),
          if (!_ready)
            const Padding(
              padding: EdgeInsets.all(28),
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          else
            _controls(),
        ]),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 4),
        child: Row(children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
          Expanded(
            child: Text('TRIM AUDIO', textAlign: TextAlign.center, style: AppTheme.displayItalic.copyWith(fontSize: 18)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: _audioAccent.withAlpha(34),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _audioAccent.withAlpha(120)),
            ),
            child: Text('VIDEO MUTED', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
          ),
        ]),
      );

  Widget _preview() {
    final controller = _video;
    if (controller == null || !controller.value.isInitialized) {
      return Center(child: Icon(Icons.graphic_eq_rounded, size: 64, color: Colors.white.withAlpha(90)));
    }
    final sourceAspect = controller.value.aspectRatio == 0 ? 16 / 9 : controller.value.aspectRatio;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.portraitCrop ? 54 : 18, vertical: 8),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: widget.portraitCrop ? 9 / 16 : sourceAspect,
            child: ColoredBox(
              color: Colors.black,
              child: widget.portraitCrop
                  ? FittedBox(
                      fit: BoxFit.cover,
                      alignment: Alignment(widget.cropX * 2 - 1, 0),
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: controller.value.size.width,
                        height: controller.value.size.height,
                        child: VideoPlayer(controller),
                      ),
                    )
                  : VideoPlayer(controller),
            ),
          ),
        ),
      ),
    );
  }

  Widget _controls() {
    final videoSeconds = _videoWindow;
    final audioSeconds = _audioWindow;
    final audioIsShorter = audioSeconds + .05 < videoSeconds;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(22),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.lock_rounded, color: _audioAccent, size: 15),
          const SizedBox(width: 6),
          Text(
            '${_pretty(videoSeconds)}s AUDIO WINDOW · LOCKED TO VIDEO CUT ${_time(_videoStart)} → ${_time(_videoEnd)}',
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .5),
          ),
        ]),
        const SizedBox(height: 5),
        Text(
          audioIsShorter
              ? 'Move the soundtrack moment. It repeats to cover the full selected video cut.'
              : 'Move only the soundtrack. Preview always starts from the exact video cut you selected.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 9.5, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        SizedBox(height: 82, child: _buildTimeline()),
        const SizedBox(height: 9),
        Text(
          'SONG ${_time(_selection.start)} → ${_time(_selection.end)}  ·  VIDEO ${_pretty(videoSeconds)}s',
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _togglePlay,
              icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: _playAccent),
              label: Text(_playing ? 'PAUSE' : 'PREVIEW CUT + MUSIC'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF334155)),
                backgroundColor: const Color(0xFF111827),
                minimumSize: const Size(0, 48),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded),
              label: Text(_saving ? 'SAVING…' : 'SAVE AUDIO'),
              style: FilledButton.styleFrom(backgroundColor: _saveAccent, foregroundColor: Colors.white, minimumSize: const Size(0, 48)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildTimeline() {
    return LayoutBuilder(builder: (context, constraints) {
      final viewportWidth = math.max(1.0, constraints.maxWidth).toDouble();
      final visibleSeconds = _duration <= 60 ? math.max(.1, _duration).toDouble() : 60.0;
      final pixelsPerSecond = viewportWidth / visibleSeconds;
      final totalWidth = math.max(viewportWidth, _duration * pixelsPerSecond).toDouble();
      final left = _selection.start * pixelsPerSecond;
      final width = math.max(8.0, _selection.length * pixelsPerSecond).toDouble();
      final right = left + width;

      final timeline = SizedBox(
        width: totalWidth,
        height: 82,
        child: Stack(children: [
          Positioned.fill(child: _waveform(totalWidth)),
          if (left > 0)
            Positioned(left: 0, top: 0, bottom: 0, width: left, child: ColoredBox(color: Colors.black.withAlpha(118))),
          if (right < totalWidth)
            Positioned(left: right, right: 0, top: 0, bottom: 0, child: ColoredBox(color: Colors.black.withAlpha(118))),
          Positioned(
            left: left,
            top: 0,
            bottom: 0,
            width: width,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (details) => _dragStart(details, pixelsPerSecond),
              onHorizontalDragUpdate: (details) => _dragUpdate(details, pixelsPerSecond),
              onHorizontalDragEnd: _dragEnd,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _audioAccent.withAlpha(28),
                  border: Border.all(color: _audioAccent, width: 3),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: _audioAccent.withAlpha(55), blurRadius: 14, spreadRadius: -4)],
                ),
                child: const Stack(alignment: Alignment.center, children: [
                  Positioned(left: 5, top: 16, bottom: 16, child: _LockedEdge()),
                  Positioned(right: 5, top: 16, bottom: 16, child: _LockedEdge()),
                  Icon(Icons.drag_indicator_rounded, color: Colors.white, size: 18),
                ]),
              ),
            ),
          ),
          Positioned(
            left: (_position.clamp(0.0, _duration) * pixelsPerSecond)
                .clamp(0.0, math.max(0.0, totalWidth - 2))
                .toDouble(),
            top: 3,
            bottom: 3,
            width: 2,
            child: const ColoredBox(color: Colors.white),
          ),
        ]),
      );

      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          controller: _timeline,
          scrollDirection: Axis.horizontal,
          physics: _duration > 60 ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _jump(details.localPosition.dx / pixelsPerSecond),
            child: timeline,
          ),
        ),
      );
    });
  }

  Widget _waveform(double width) => CustomPaint(size: Size(width, 82), painter: const _WaveformPainter());

  String _time(double seconds) {
    final value = math.max(0, seconds.floor());
    return '${value ~/ 60}:${(value % 60).toString().padLeft(2, '0')}';
  }

  String _pretty(double seconds) => seconds.toStringAsFixed(seconds % 1 == 0 ? 0 : 1);
}

class _LockedEdge extends StatelessWidget {
  const _LockedEdge();

  @override
  Widget build(BuildContext context) {
    return Container(width: 4, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)));
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(145)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final count = math.max(1, (size.width / 7).floor());
    for (var i = 0; i < count; i++) {
      final x = i * 7.0 + 3.5;
      final wave = (math.sin(i * .73) + math.sin(i * .21) * .55 + 1.55) / 3.1;
      final height = 18 + wave * 54;
      final top = (size.height - height) / 2;
      canvas.drawLine(Offset(x, top), Offset(x, top + height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
