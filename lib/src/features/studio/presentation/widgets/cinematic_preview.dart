import 'dart:async';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/studio/domain/cinematic_template.dart';
import 'package:flutter_swipes/src/features/swipes/domain/listing_soundtrack.dart';

class CinematicPreview extends StatefulWidget {
  const CinematicPreview({
    super.key,
    required this.photos,
    required this.template,
    this.focalPoints = const <int, StudioFocalPoint>{},
    this.photoFits = const <int, StudioPhotoFit>{},
    this.playing = true,
    this.playAudio = true,
    this.borderRadius = 24,
  });

  final List<XFile> photos;
  final CinematicTemplate template;
  final Map<int, StudioFocalPoint> focalPoints;
  final Map<int, StudioPhotoFit> photoFits;
  final bool playing;
  final bool playAudio;
  final double borderRadius;

  @override
  State<CinematicPreview> createState() => _CinematicPreviewState();
}

class _CinematicPreviewState extends State<CinematicPreview>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock;
  final ListingSoundtrackPlayer _soundtrack = ListingSoundtrackPlayer();
  final Map<int, Uint8List> _bytes = <int, Uint8List>{};
  final Set<int> _loading = <int>{};
  int _lastCurrent = -1;
  int _lastNext = -1;
  bool _appActive = true;

  double get _durationSeconds =>
      widget.template.totalDurationFor(widget.photos.length).clamp(.1, 90);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = AnimationController(vsync: this, duration: _duration)
      ..addListener(_onTick);
    _syncPlayback(restart: true);
    _preload(0);
    _preload(widget.photos.length > 1 ? 1 : 0);
  }

  Duration get _duration => Duration(
    milliseconds: (_durationSeconds * 1000).round().clamp(100, 90000),
  );

  @override
  void didUpdateWidget(CinematicPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final structureChanged =
        oldWidget.template.id != widget.template.id ||
        oldWidget.template.version != widget.template.version ||
        oldWidget.photos.length != widget.photos.length;
    if (structureChanged) {
      _clock
        ..stop()
        ..duration = _duration
        ..value = 0;
      _bytes.clear();
      _loading.clear();
      _lastCurrent = -1;
      _lastNext = -1;
      _preload(0);
      _preload(widget.photos.length > 1 ? 1 : 0);
    }
    if (structureChanged ||
        oldWidget.playing != widget.playing ||
        oldWidget.playAudio != widget.playAudio ||
        oldWidget.template.audioPresetId != widget.template.audioPresetId) {
      _syncPlayback(restart: structureChanged);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (_appActive) {
      _syncPlayback(restart: false);
    } else {
      _clock.stop();
      unawaited(_soundtrack.stop());
    }
  }

  void _syncPlayback({required bool restart}) {
    final shouldPlay = _appActive && widget.playing && widget.photos.isNotEmpty;
    if (!shouldPlay) {
      _clock.stop();
      unawaited(_soundtrack.stop());
      return;
    }
    if (restart) _clock.value = 0;
    _clock.repeat();
    if (widget.playAudio) {
      unawaited(
        _soundtrack.play(presetId: widget.template.audioPresetId, volume: .5),
      );
    } else {
      unawaited(_soundtrack.stop());
    }
  }

  void _onTick() {
    if (widget.photos.isEmpty) return;
    final state = widget.template.resolveAtSeconds(
      _clock.value * _durationSeconds,
      widget.photos.length,
    );
    if (state.imageIndex != _lastCurrent || state.nextImageIndex != _lastNext) {
      _lastCurrent = state.imageIndex;
      _lastNext = state.nextImageIndex;
      _preload(state.imageIndex);
      _preload(state.nextImageIndex);
      _trimCache(state.imageIndex, state.nextImageIndex);
    }
  }

  Future<void> _preload(int index) async {
    if (!mounted ||
        index < 0 ||
        index >= widget.photos.length ||
        _bytes.containsKey(index) ||
        _loading.contains(index)) {
      return;
    }
    _loading.add(index);
    try {
      final bytes = await widget.photos[index].readAsBytes();
      if (!mounted || bytes.isEmpty) return;
      setState(() => _bytes[index] = bytes);
    } catch (_) {
      // The preview can keep animating its other frames if one selected image
      // becomes temporarily unavailable (for example an iCloud-backed file).
    } finally {
      _loading.remove(index);
    }
  }

  void _trimCache(int current, int next) {
    if (_bytes.length <= 3) return;
    final keep = <int>{current, next, (current - 1) % widget.photos.length};
    _bytes.removeWhere((key, _) => !keep.contains(key));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock
      ..removeListener(_onTick)
      ..dispose();
    unawaited(_soundtrack.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return AspectRatio(
        aspectRatio: 9 / 16,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF15151A),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: const Center(
            child: Icon(
              Icons.photo_library_outlined,
              color: Color(0xFF777780),
              size: 42,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            final frame = widget.template.resolveAtSeconds(
              _clock.value * _durationSeconds,
              widget.photos.length,
            );
            return LayoutBuilder(
              builder: (context, constraints) => _TransitionFrame(
                current: _imageFor(frame.imageIndex, frame, constraints),
                next: _imageFor(
                  frame.nextImageIndex,
                  _nextFrame(frame),
                  constraints,
                ),
                transition: frame.transition,
                progress: frame.transitionProgress,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
              ),
            );
          },
        ),
      ),
    );
  }

  StudioFrameState _nextFrame(StudioFrameState current) {
    final shots = widget.template.shotsFor(widget.photos.length);
    if (shots.isEmpty) return current;
    final shot = shots[current.nextImageIndex % shots.length];
    return StudioFrameState(
      imageIndex: current.nextImageIndex,
      nextImageIndex: (current.nextImageIndex + 1) % shots.length,
      shotProgress: 0,
      transitionProgress: 0,
      scale: shot.startScale,
      x: shot.startPosition.x,
      y: shot.startPosition.y,
      transition: shot.transition,
    );
  }

  Widget _imageFor(
    int index,
    StudioFrameState frame,
    BoxConstraints constraints,
  ) {
    final bytes = _bytes[index];
    if (bytes == null) {
      _preload(index);
      return const ColoredBox(
        color: Color(0xFF111114),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final photoFit = widget.photoFits[index] ?? StudioPhotoFit.portrait;
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
  }
}

class _TransitionFrame extends StatelessWidget {
  const _TransitionFrame({
    required this.current,
    required this.next,
    required this.transition,
    required this.progress,
    required this.width,
    required this.height,
  });

  final Widget current;
  final Widget next;
  final StudioTransition transition;
  final double progress;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeInOut.transform(progress.clamp(0.0, 1.0));
    if (t <= 0) return current;

    switch (transition) {
      case StudioTransition.crossFade:
        return Stack(
          fit: StackFit.expand,
          children: [
            current,
            Opacity(opacity: t, child: next),
          ],
        );
      case StudioTransition.hardCut:
        return t < .5 ? current : next;
      case StudioTransition.pushLeft:
        return Stack(
          fit: StackFit.expand,
          children: [
            Transform.translate(offset: Offset(-width * t, 0), child: current),
            Transform.translate(
              offset: Offset(width * (1 - t), 0),
              child: next,
            ),
          ],
        );
      case StudioTransition.pushUp:
        return Stack(
          fit: StackFit.expand,
          children: [
            Transform.translate(offset: Offset(0, -height * t), child: current),
            Transform.translate(
              offset: Offset(0, height * (1 - t)),
              child: next,
            ),
          ],
        );
      case StudioTransition.splitVertical:
        return _split(next, current, t, vertical: true);
      case StudioTransition.splitHorizontal:
        return _split(next, current, t, vertical: false);
    }
  }

  Widget _split(Widget under, Widget over, double t, {required bool vertical}) {
    final travel = vertical ? width * .52 * t : height * .52 * t;
    final firstOffset = vertical ? Offset(-travel, 0) : Offset(0, -travel);
    final secondOffset = vertical ? Offset(travel, 0) : Offset(0, travel);
    return Stack(
      fit: StackFit.expand,
      children: [
        under,
        Transform.translate(
          offset: firstOffset,
          child: ClipRect(
            clipper: _HalfClipper(vertical: vertical, first: true),
            child: over,
          ),
        ),
        Transform.translate(
          offset: secondOffset,
          child: ClipRect(
            clipper: _HalfClipper(vertical: vertical, first: false),
            child: over,
          ),
        ),
      ],
    );
  }
}

class _HalfClipper extends CustomClipper<Rect> {
  const _HalfClipper({required this.vertical, required this.first});

  final bool vertical;
  final bool first;

  @override
  Rect getClip(Size size) {
    if (vertical) {
      return first
          ? Rect.fromLTWH(0, 0, size.width / 2, size.height)
          : Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height);
    }
    return first
        ? Rect.fromLTWH(0, 0, size.width, size.height / 2)
        : Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2);
  }

  @override
  bool shouldReclip(covariant _HalfClipper oldClipper) =>
      oldClipper.vertical != vertical || oldClipper.first != first;
}
