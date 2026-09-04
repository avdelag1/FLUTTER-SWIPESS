// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Browser/PWA preview intentionally mirrors Admin Swipess: the exact selected
/// file (or already-uploaded public URL) is handed to a native HTML <video>
/// element. No Flutter video_player texture, canvas export or MediaRecorder sits
/// between the user's source file and what they see during listing creation.
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
  late final String _viewType;
  late final html.VideoElement _video;

  String get _source => (widget.file?.path ?? widget.networkUrl ?? '').trim();

  @override
  void initState() {
    super.initState();
    _viewType =
        'swipess-listing-upload-video-${identityHashCode(this)}-${DateTime.now().microsecondsSinceEpoch}';
    _video = html.VideoElement()
      ..controls = true
      ..loop = true
      ..autoplay = false
      ..preload = 'auto'
      ..muted = widget.muted;
    _video
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true');
    _video.style
      ..width = '100%'
      ..height = '100%'
      ..display = 'block'
      ..objectFit = 'cover'
      ..backgroundColor = '#08090D';
    _applySource();
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _video,
    );
  }

  void _applySource() {
    final source = _source;
    if (source.isEmpty) return;
    if (_video.src != source) {
      _video.src = source;
      _video.load();
    }
  }

  @override
  void didUpdateWidget(covariant ListingVideoInlinePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _video.muted = widget.muted;
    if (oldWidget.file?.path != widget.file?.path ||
        oldWidget.networkUrl != widget.networkUrl) {
      _applySource();
    }
  }

  @override
  void dispose() {
    try {
      _video.pause();
      _video.removeAttribute('src');
      _video.load();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: double.infinity,
        height: widget.height,
        child: const ColoredBox(
          color: Color(0xFF08090D),
          child: _NativeViewPlaceholder(),
        ),
      ),
    );
  }
}

class _NativeViewPlaceholder extends StatelessWidget {
  const _NativeViewPlaceholder();

  @override
  Widget build(BuildContext context) {
    final state = context
        .findAncestorStateOfType<_ListingVideoInlinePreviewState>();
    if (state == null) return const SizedBox.expand();
    return HtmlElementView(viewType: state._viewType);
  }
}
