// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Web/PWA listing preview that mirrors Admin Swipess: a native browser
/// <video> element plays the exact selected/uploaded source without routing
/// frames through Flutter's video_player texture/compositor.
class ListingVideoNativePreview extends StatefulWidget {
  const ListingVideoNativePreview({
    super.key,
    this.file,
    this.networkUrl,
    required this.muted,
    required this.height,
  });

  final XFile? file;
  final String? networkUrl;
  final bool muted;
  final double height;

  @override
  State<ListingVideoNativePreview> createState() =>
      _ListingVideoNativePreviewState();
}

class _ListingVideoNativePreviewState
    extends State<ListingVideoNativePreview> {
  late final String _viewType;
  late final html.VideoElement _video;

  String get _source => (widget.file?.path ?? widget.networkUrl ?? '').trim();

  @override
  void initState() {
    super.initState();
    _viewType =
        'swipess-listing-native-video-${identityHashCode(this)}-${DateTime.now().microsecondsSinceEpoch}';
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
  void didUpdateWidget(covariant ListingVideoNativePreview oldWidget) {
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
        child: ColoredBox(
          color: const Color(0xFF08090D),
          child: HtmlElementView(viewType: _viewType),
        ),
      ),
    );
  }
}
