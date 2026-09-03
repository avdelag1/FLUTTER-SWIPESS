import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Inline looping preview used by listing create/edit flows before publishing.
///
/// The preview is deliberately defensive because mobile browsers can reject
/// unmuted autoplay and some platform players occasionally miss a native loop
/// boundary. Web/PWA therefore starts muted, then lets the user enable sound
/// with an explicit tap. A manual end-of-file guard backs up setLooping(true),
/// so a selected clip keeps moving instead of freezing on its final frame.
class ListingVideoInlinePreview extends StatefulWidget {
  const ListingVideoInlinePreview({
    super.key,
    this.file,
    this.networkUrl,
    this.muted = false,
    this.height = 260,
  }) : assert(file != null || networkUrl != null);

  final XFile? file;
  final String? networkUrl;
  final bool muted;
  final double height;

  @override
  State<ListingVideoInlinePreview> createState() =>
      _ListingVideoInlinePreviewState();
}

class _ListingVideoInlinePreviewState extends State<ListingVideoInlinePreview>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Timer? _autoplayRetry;
  bool _ready = false;
  bool _userPaused = false;
  bool _sessionMuted = true;
  bool _loopRepairing = false;
  bool _lifecycleActive = true;
  bool? _lastPlaying;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionMuted = widget.muted || kIsWeb;
    unawaited(_open());
  }

  @override
  void didUpdateWidget(covariant ListingVideoInlinePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sourceChanged =
        oldWidget.file?.path != widget.file?.path ||
        oldWidget.networkUrl != widget.networkUrl;
    if (sourceChanged) {
      _disposeController();
      _userPaused = false;
      _sessionMuted = widget.muted || kIsWeb;
      unawaited(_open());
      return;
    }
    if (oldWidget.muted != widget.muted) {
      _sessionMuted = widget.muted;
      unawaited(_controller?.setVolume(_sessionMuted ? 0 : 1));
      if (mounted) setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.resumed) {
      _lifecycleActive = true;
      if (controller != null && _ready && !_userPaused) {
        unawaited(_resumePreview(controller));
      }
      return;
    }
    _lifecycleActive = false;
    if (controller != null && controller.value.isPlaying) {
      unawaited(controller.pause());
    }
  }

  Future<void> _open() async {
    _autoplayRetry?.cancel();
    setStateIfMounted(() {
      _ready = false;
      _error = null;
      _lastPlaying = null;
    });

    VideoPlayerController? controller;
    try {
      controller = _buildController();
      _controller = controller;
      await controller.initialize();
      if (!mounted || _controller != controller) {
        await controller.dispose();
        return;
      }

      controller.addListener(_onControllerTick);
      await controller.setLooping(true);
      await controller.setPlaybackSpeed(1);
      await controller.seekTo(Duration.zero);

      // Browser autoplay is most reliable while muted. The selected listing's
      // real audio preference is not changed; this only affects this preview.
      _sessionMuted = widget.muted || kIsWeb;
      await controller.setVolume(_sessionMuted ? 0 : 1);

      // Show the initialized first frame immediately instead of keeping a
      // spinner up while play() negotiates with the platform media session.
      if (mounted && _controller == controller) {
        setState(() {
          _ready = true;
          _error = null;
          _lastPlaying = controller!.value.isPlaying;
        });
      }

      await _resumePreview(controller);

      // A few Android/WebView and PWA combinations report play() success before
      // frames actually advance. One short retry fixes that without blocking UI.
      _autoplayRetry = Timer(const Duration(milliseconds: 320), () {
        final current = _controller;
        if (!mounted ||
            current == null ||
            current != controller ||
            _userPaused ||
            !_lifecycleActive ||
            current.value.isPlaying) {
          return;
        }
        unawaited(_resumePreview(current));
      });
    } catch (error) {
      if (controller != null && _controller == controller) {
        controller.removeListener(_onControllerTick);
      }
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  VideoPlayerController _buildController() {
    final file = widget.file;
    if (file != null) {
      if (kIsWeb) {
        return VideoPlayerController.networkUrl(Uri.parse(file.path));
      }
      return VideoPlayerController.file(File(file.path));
    }
    return VideoPlayerController.networkUrl(Uri.parse(widget.networkUrl!));
  }

  void _onControllerTick() {
    final controller = _controller;
    if (!mounted || controller == null || !controller.value.isInitialized) return;

    final value = controller.value;
    if (value.hasError && _error == null) {
      setState(() => _error = value.errorDescription ?? 'Video preview error');
      return;
    }

    if (_lastPlaying != value.isPlaying) {
      _lastPlaying = value.isPlaying;
      setState(() {});
    }

    if (_userPaused || !_lifecycleActive || _loopRepairing) return;
    final duration = value.duration;
    if (duration <= const Duration(milliseconds: 250)) return;
    final remaining = duration - value.position;
    if (remaining <= const Duration(milliseconds: 120)) {
      unawaited(_repairLoop(controller));
    }
  }

  Future<void> _repairLoop(VideoPlayerController controller) async {
    if (_loopRepairing || _controller != controller || _userPaused) return;
    _loopRepairing = true;
    try {
      await controller.seekTo(Duration.zero);
      if (_lifecycleActive && !_userPaused) {
        await controller.play();
      }
    } catch (_) {
      // Native setLooping remains the primary path; this is only a fallback.
    } finally {
      _loopRepairing = false;
    }
  }

  Future<void> _resumePreview(VideoPlayerController controller) async {
    if (_controller != controller ||
        !controller.value.isInitialized ||
        _userPaused ||
        !_lifecycleActive) {
      return;
    }
    try {
      final duration = controller.value.duration;
      if (duration > Duration.zero &&
          controller.value.position >= duration - const Duration(milliseconds: 120)) {
        await controller.seekTo(Duration.zero);
      }
      await controller.setVolume(_sessionMuted ? 0 : 1);
      await controller.play();
    } catch (_) {
      // Keep the initialized frame visible. A user tap on play is a guaranteed
      // media gesture on restrictive browsers and can resume from here.
    }
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !_ready) return;
    if (controller.value.isPlaying) {
      _userPaused = true;
      await controller.pause();
    } else {
      _userPaused = false;
      await _resumePreview(controller);
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleSound() async {
    final controller = _controller;
    if (controller == null || !_ready || widget.muted) return;
    _sessionMuted = !_sessionMuted;
    try {
      await controller.setVolume(_sessionMuted ? 0 : 1);
      if (!_userPaused && !controller.value.isPlaying) {
        await controller.play();
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  void _disposeController() {
    _autoplayRetry?.cancel();
    _autoplayRetry = null;
    final controller = _controller;
    _controller = null;
    _ready = false;
    _loopRepairing = false;
    _lastPlaying = null;
    if (controller != null) {
      controller.removeListener(_onControllerTick);
      unawaited(controller.dispose());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: double.infinity,
        height: widget.height,
        child: ColoredBox(
          color: const Color(0xFF08090D),
          child: _error != null
              ? Center(
                  child: Icon(
                    Icons.video_file_rounded,
                    color: Colors.white38,
                    size: 40,
                  ),
                )
              : !_ready || controller == null
              ? Center(child: CircularProgressIndicator(strokeWidth: 2))
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _togglePlayback,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: controller.value.size.width,
                          height: controller.value.size.height,
                          child: VideoPlayer(controller),
                        ),
                      ),
                      const IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Color(0x08000000),
                                Color(0x42000000),
                              ],
                              stops: [.56, .76, 1],
                            ),
                          ),
                        ),
                      ),
                      if (!widget.muted)
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: _PreviewControl(
                            onTap: _toggleSound,
                            icon: _sessionMuted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                          ),
                        ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: _PreviewControl(
                          onTap: _togglePlayback,
                          icon: controller.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          dimmed: controller.value.isPlaying,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _PreviewControl extends StatelessWidget {
  const _PreviewControl({
    required this.onTap,
    required this.icon,
    this.dimmed = false,
  });

  final Future<void> Function() onTap;
  final IconData icon;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(onTap()),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        opacity: dimmed ? .72 : 1,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(150),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(32)),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
