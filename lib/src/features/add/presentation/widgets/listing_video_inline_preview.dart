import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Inline looping preview used by listing create/edit flows before publishing.
/// Keeps the selected video visible and alive instead of reducing it to a file
/// name after the trim screen closes.
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

class _ListingVideoInlinePreviewState extends State<ListingVideoInlinePreview> {
  VideoPlayerController? _controller;
  bool _ready = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(covariant ListingVideoInlinePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sourceChanged =
        oldWidget.file?.path != widget.file?.path ||
        oldWidget.networkUrl != widget.networkUrl;
    if (sourceChanged) {
      _disposeController();
      _open();
      return;
    }
    if (oldWidget.muted != widget.muted) {
      _controller?.setVolume(widget.muted ? 0 : 1);
    }
  }

  Future<void> _open() async {
    setStateIfMounted(() {
      _ready = false;
      _error = null;
    });
    try {
      final controller = _buildController();
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(widget.muted ? 0 : 1);
      await controller.play();
      if (!mounted || _controller != controller) return;
      setState(() => _ready = true);
    } catch (error) {
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

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !_ready) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    controller?.dispose();
  }

  @override
  void dispose() {
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
              ? const Center(
                  child: Icon(
                    Icons.video_file_rounded,
                    color: Colors.white38,
                    size: 40,
                  ),
                )
              : !_ready || controller == null
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
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
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 160),
                          opacity: controller.value.isPlaying ? .72 : 1,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(150),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              controller.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
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
