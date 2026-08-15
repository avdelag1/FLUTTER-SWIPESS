import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/camera/data/video_recut.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

/// Cap `VideoCropper` — 10s looping window, then confirm the clip.
class VideoCropperScreen extends StatefulWidget {
  const VideoCropperScreen({super.key, required this.file});

  final XFile file;

  static const maxSeconds = 10.0;

  @override
  State<VideoCropperScreen> createState() => _VideoCropperScreenState();
}

class _VideoCropperScreenState extends State<VideoCropperScreen> {
  VideoPlayerController? _player;
  double _duration = 0;
  double _start = 0;
  double _end = VideoCropperScreen.maxSeconds;
  bool _ready = false;
  bool _processing = false;
  String? _error;

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
        _end = dur < VideoCropperScreen.maxSeconds
            ? dur
            : VideoCropperScreen.maxSeconds;
        _ready = true;
      });
      await controller.play();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _onTick() {
    final p = _player;
    if (p == null || !p.value.isInitialized) return;
    final t = p.value.position.inMilliseconds / 1000.0;
    if (t >= _end - 0.05) {
      p.seekTo(Duration(milliseconds: (_start * 1000).round()));
    }
  }

  @override
  void dispose() {
    _player?.removeListener(_onTick);
    _player?.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_processing || !_ready) return;
    AppHaptics.medium();
    final window = _end - _start;
    if (window > VideoCropperScreen.maxSeconds + 0.05) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Slide the 10s window, then confirm the loop.'),
        ),
      );
      return;
    }
    setState(() => _processing = true);
    try {
      await _player?.pause();
      final cropped = await recutVideoWindow(
        source: widget.file,
        start: _start,
        end: _end,
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      '10s LOOP',
                      textAlign: TextAlign.center,
                      style: AppTheme.displayItalic.copyWith(fontSize: 18),
                    ),
                  ),
                  const Icon(
                    Icons.content_cut_rounded,
                    color: AppTheme.brandPrimary,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Text(
                        'Could not preview video',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                        ),
                      ),
                    )
                  : !_ready
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : AspectRatio(
                      aspectRatio: _player!.value.aspectRatio == 0
                          ? 16 / 9
                          : _player!.value.aspectRatio,
                      child: VideoPlayer(_player!),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: [
                  Text(
                    'Cap looping card · max ${VideoCropperScreen.maxSeconds.toInt()}s',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.brandPrimary,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      min: 0,
                      max: _duration <= 0 ? 1 : _duration,
                      value: _start.clamp(0, _duration <= 0 ? 1 : _duration),
                      onChanged: (v) {
                        final window = (_end - _start).clamp(
                          0.5,
                          VideoCropperScreen.maxSeconds,
                        );
                        setState(() {
                          _start = v;
                          _end = (_start + window).clamp(0, _duration);
                        });
                        _player?.seekTo(
                          Duration(milliseconds: (_start * 1000).round()),
                        );
                      },
                    ),
                  ),
                  Text(
                    '${_start.toStringAsFixed(1)}s – ${_end.toStringAsFixed(1)}s',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: (_ready && !_processing) ? _confirm : null,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        _processing ? 'PROCESSING…' : 'LOOP & SAVE',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
