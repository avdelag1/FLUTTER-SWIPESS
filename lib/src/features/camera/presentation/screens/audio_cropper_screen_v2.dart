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

class AudioCropperScreenV2 extends StatefulWidget {
  const AudioCropperScreenV2({
    super.key,
    required this.file,
    this.videoFile,
    required this.maxClipSeconds,
  });

  final XFile file;
  final XFile? videoFile;
  final double maxClipSeconds;

  @override
  State<AudioCropperScreenV2> createState() => _AudioCropperScreenV2State();
}

enum _AudioDragMode { left, move, right }

class _AudioCropperScreenV2State extends State<AudioCropperScreenV2> {
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
  String? _error;
  _AudioDragMode _dragMode = _AudioDragMode.move;
  VideoTrimSelection? _dragOrigin;
  double _dragDx = 0;

  double get _maxWindow => widget.maxClipSeconds.clamp(1.0, 60.0).toDouble();

  @override
  void initState() {
    super.initState();
    _boot();
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
        final controller = (!kIsWeb && !path.startsWith('http') && !path.startsWith('blob:'))
            ? VideoPlayerController.file(File(path))
            : VideoPlayerController.networkUrl(Uri.parse(path));
        await controller.initialize();
        await controller.setVolume(0);
        await controller.setLooping(true);
        _video = controller;
      }

      await _audio.setSource(await _audioSource());
      var duration = await _audio.getDuration();
      if (duration == null || duration.inMilliseconds <= 0) {
        final completer = Completer<Duration>();
        late StreamSubscription<Duration> sub;
        sub = _audio.onDurationChanged.listen((d) {
          if (!completer.isCompleted && d.inMilliseconds > 0) completer.complete(d);
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
      var end = math.min(_maxWindow, _duration).toDouble();
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          final row = await Supabase.instance.client
              .from('pending_listing_audio_trim')
              .select('start_ms, end_ms')
              .eq('user_id', user.id)
              .maybeSingle();
          if (row != null) {
            start = (((row['start_ms'] as num?)?.toDouble() ?? 0) / 1000)
                .clamp(0.0, math.max(0.0, _duration - 0.2))
                .toDouble();
            final storedEnd = (row['end_ms'] as num?)?.toDouble();
            if (storedEnd != null) end = storedEnd / 1000;
          }
        } catch (_) {}
      }
      end = end.clamp(start + 0.2, math.min(_duration, start + _maxWindow)).toDouble();
      _selection = VideoTrimSelection(start: start, end: end, duration: _duration);

      _positionSub = _audio.onPositionChanged.listen((pos) async {
        if (!mounted) return;
        final sec = pos.inMilliseconds / 1000.0;
        setState(() => _position = sec);
        if (_playing && sec >= _selection.end - 0.03) {
          await _seekStart(restart: true);
        }
      });
      _stateSub = _audio.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _playing = state == PlayerState.playing);
      });
      if (!mounted) return;
      setState(() => _ready = true);
      await _seekStart(restart: true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _seekStart({bool restart = false}) async {
    await _audio.seek(Duration(milliseconds: (_selection.start * 1000).round()));
    _position = _selection.start;
    if (_video != null) {
      await _video!.seekTo(Duration.zero);
      if (restart) await _video!.play();
    }
    if (restart) await _audio.resume();
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _audio.pause();
      await _video?.pause();
    } else {
      if (_position < _selection.start || _position >= _selection.end - 0.03) {
        await _seekStart();
      }
      await _video?.play();
      await _audio.resume();
    }
  }

  void _applyPreset(double seconds) {
    final length = math.min(seconds, _maxWindow).toDouble();
    if (_duration + 0.01 < length) return;
    AppHaptics.selection();
    setState(() => _selection = _selection.preset(length));
    _seekStart(restart: _playing);
    _ensureVisible();
  }

  void _jump(double tappedSecond) {
    if (!_ready) return;
    final target = tappedSecond - _selection.length / 2;
    final next = _selection.moveTo(target);
    AppHaptics.selection();
    setState(() => _selection = next);
    _seekStart(restart: _playing);
    _ensureVisible();
  }

  void _dragStart(DragStartDetails details, double selectionWidth) {
    _dragOrigin = _selection;
    _dragDx = 0;
    final edgeZone = math.min(14.0, selectionWidth * .3);
    final x = details.localPosition.dx;
    _dragMode = x <= edgeZone
        ? _AudioDragMode.left
        : x >= selectionWidth - edgeZone
            ? _AudioDragMode.right
            : _AudioDragMode.move;
    AppHaptics.light();
  }

  void _dragUpdate(DragUpdateDetails details, double pixelsPerSecond) {
    final origin = _dragOrigin;
    if (origin == null || pixelsPerSecond <= 0) return;
    _dragDx += details.primaryDelta ?? 0;
    final delta = _dragDx / pixelsPerSecond;
    var next = switch (_dragMode) {
      _AudioDragMode.left => origin.resizeStartTo(origin.start + delta),
      _AudioDragMode.right => origin.resizeEndTo(origin.end + delta),
      _AudioDragMode.move => origin.moveTo(origin.start + delta),
    };
    if (next.length > _maxWindow) {
      next = _dragMode == _AudioDragMode.left
          ? VideoTrimSelection(start: next.end - _maxWindow, end: next.end, duration: _duration)
          : VideoTrimSelection(start: next.start, end: next.start + _maxWindow, duration: _duration);
    }
    setState(() => _selection = next);
    _seekStart(restart: _playing);
  }

  void _dragEnd(DragEndDetails _) {
    _dragOrigin = null;
    _dragDx = 0;
    AppHaptics.medium();
    _ensureVisible();
  }

  void _ensureVisible() {
    if (!_timeline.hasClients || _duration <= 60) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_timeline.hasClients || !mounted) return;
      final viewport = _timeline.position.viewportDimension;
      final px = viewport / 60;
      final left = _selection.start * px;
      final right = _selection.end * px;
      var target = _timeline.offset;
      if (left < target + 16) target = math.max(0.0, left - 16);
      if (right > target + viewport - 16) {
        target = math.min(_timeline.position.maxScrollExtent, right - viewport + 16);
      }
      if ((target - _timeline.offset).abs() > 1) {
        _timeline.animateTo(target, duration: const Duration(milliseconds: 180), curve: Curves.easeOutCubic);
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
      final start = (_selection.start * 1000).round().clamp(0, math.max(0, (_duration * 1000).round() - 1));
      final end = (_selection.end * 1000).round().clamp(start + 1, (_duration * 1000).round());
      await Supabase.instance.client.from('pending_listing_audio_trim').upsert({
        'user_id': user.id,
        'start_ms': start,
        'end_ms': end >= (_duration * 1000).round() ? null : end,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _message('Could not save the music cut. Try again.');
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
    _audio.dispose();
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
              child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white)),
            ),
            Expanded(child: Center(child: Text('Could not load this audio.\n$_error', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)))),
          ]),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.dashBg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(child: _preview()),
            if (!_ready)
              const Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            else
              _controls(),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 4),
        child: Row(children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white)),
          Expanded(child: Text('TRIM AUDIO', textAlign: TextAlign.center, style: AppTheme.displayItalic.copyWith(fontSize: 18))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(color: AppTheme.brandPrimary.withAlpha(28), borderRadius: BorderRadius.circular(999)),
            child: Text('VIDEO MUTED', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
          ),
        ]),
      );

  Widget _preview() {
    final controller = _video;
    if (controller == null || !controller.value.isInitialized) {
      return Center(child: Icon(Icons.graphic_eq_rounded, size: 64, color: Colors.white.withAlpha(90)));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 8),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: ColoredBox(
              color: Colors.black,
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _controls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      decoration: BoxDecoration(color: Colors.black.withAlpha(22), borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('AUDIO WAVEFORM · SAME TRIM FLOW', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        const SizedBox(height: 5),
        Text('Tap the waveform to jump · drag the middle to move · drag either edge to resize', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SizedBox(height: 82, child: _buildTimeline()),
        const SizedBox(height: 10),
        _presetRow(),
        const SizedBox(height: 8),
        Text('${_time(_selection.start)}  →  ${_time(_selection.end)}   ·   ${_selection.length.toStringAsFixed(_selection.length % 1 == 0 ? 0 : 1)}s', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _togglePlay,
              icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
              label: Text(_playing ? 'PAUSE' : 'PREVIEW'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(0, 48)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded),
              label: Text(_saving ? 'SAVING…' : 'SAVE AUDIO'),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.brandPrimary, foregroundColor: Colors.white, minimumSize: const Size(0, 48)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildTimeline() {
    return LayoutBuilder(builder: (context, constraints) {
      final viewport = math.max(1.0, constraints.maxWidth).toDouble();
      final visible = _duration <= 60 ? math.max(.1, _duration).toDouble() : 60.0;
      final px = viewport / visible;
      final total = math.max(viewport, _duration * px).toDouble();
      final left = _selection.start * px;
      final width = math.max(2.0, _selection.length * px).toDouble();
      final right = left + width;
      final timeline = SizedBox(
        width: total,
        height: 82,
        child: Stack(children: [
          Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(14), child: CustomPaint(painter: _WavePainter(duration: _duration, pixelsPerSecond: px)))),
          if (left > 0) Positioned(left: 0, top: 0, bottom: 0, width: left, child: ColoredBox(color: Colors.black.withAlpha(130))),
          if (right < total) Positioned(left: right, right: 0, top: 0, bottom: 0, child: ColoredBox(color: Colors.black.withAlpha(130))),
          Positioned(
            left: left,
            top: 0,
            bottom: 0,
            width: width,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (d) => _dragStart(d, width),
              onHorizontalDragUpdate: (d) => _dragUpdate(d, px),
              onHorizontalDragEnd: _dragEnd,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppTheme.brandPrimary.withAlpha(22), border: Border.all(color: AppTheme.brandPrimary, width: 3), borderRadius: BorderRadius.circular(12)),
                child: Stack(alignment: Alignment.center, children: [
                  Positioned(left: 4, top: 14, bottom: 14, child: _handle()),
                  Positioned(right: 4, top: 14, bottom: 14, child: _handle()),
                  if (width >= 36) const Icon(Icons.drag_indicator_rounded, color: Colors.white, size: 18),
                ]),
              ),
            ),
          ),
          Positioned(left: (_position.clamp(0.0, _duration) * px).clamp(0.0, math.max(0.0, total - 2)).toDouble(), top: 3, bottom: 3, width: 2, child: const ColoredBox(color: Colors.white)),
        ]),
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          controller: _timeline,
          scrollDirection: Axis.horizontal,
          physics: _duration > 60 ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTapDown: (d) => _jump(d.localPosition.dx / px), child: timeline),
        ),
      );
    });
  }

  Widget _presetRow() {
    const values = <double>[5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, i) {
          final value = values[i];
          final enabled = value <= _duration + .01 && value <= _maxWindow + .01;
          final active = (_selection.length - value).abs() < .05;
          return SizedBox(
            width: 68,
            child: GestureDetector(
              onTap: enabled ? () => _applyPreset(value) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: active ? AppTheme.brandPrimary : Colors.white.withAlpha(enabled ? 13 : 5), borderRadius: BorderRadius.circular(999), border: Border.all(color: active ? AppTheme.brandPrimary : Colors.white.withAlpha(enabled ? 38 : 14))),
                child: Text('${value.toInt()}s', style: GoogleFonts.plusJakartaSans(color: enabled ? Colors.white : Colors.white30, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _handle() => Container(width: 4, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)));

  String _time(double seconds) {
    final value = math.max(0, seconds.floor());
    return '${value ~/ 60}:${(value % 60).toString().padLeft(2, '0')}';
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter({required this.duration, required this.pixelsPerSecond});
  final double duration;
  final double pixelsPerSecond;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF22252B);
    canvas.drawRect(Offset.zero & size, bg);
    final wave = Paint()
      ..color = Colors.white.withAlpha(190)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final step = 4.0;
    for (double x = 2; x < size.width; x += step) {
      final index = (x / step).floor();
      final a = .25 + ((math.sin(index * .73) + 1) * .22) + ((math.sin(index * .19) + 1) * .12);
      final h = (size.height * a).clamp(8.0, size.height - 8).toDouble();
      canvas.drawLine(Offset(x, (size.height - h) / 2), Offset(x, (size.height + h) / 2), wave);
    }
    final label = TextPainter(textDirection: TextDirection.ltr);
    for (double sec = 0; sec < duration; sec += 5) {
      label.text = TextSpan(text: '${(sec ~/ 60)}:${(sec.round() % 60).toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.w700));
      label.layout();
      label.paint(canvas, Offset(sec * pixelsPerSecond + 4, size.height - 14));
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => oldDelegate.duration != duration || oldDelegate.pixelsPerSecond != pixelsPerSecond;
}
