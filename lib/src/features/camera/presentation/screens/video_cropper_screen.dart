import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/camera/presentation/screens/video_cropper_screen_v2.dart'
    as editor;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

/// Shared listing-video entry point used by both Manual Upload and AI Upload.
///
/// A clip that is 60 seconds or shorter can bypass editing completely. In that
/// path we return the exact selected [XFile] so there is no trim, crop, canvas
/// render, frame-rate conversion, or other client-side video rewrite.
class VideoCropperScreen extends StatefulWidget {
  const VideoCropperScreen({
    super.key,
    required this.file,
    this.videoAudioEnabled = true,
    this.backgroundMusic,
    this.backgroundMusicPreset,
    this.backgroundMusicName,
    this.onVideoAudioChanged,
    this.onBackgroundMusicFile,
    this.onBackgroundMusicPreset,
    this.onBackgroundMusicClear,
  });

  final XFile file;
  final bool videoAudioEnabled;
  final XFile? backgroundMusic;
  final String? backgroundMusicPreset;
  final String? backgroundMusicName;
  final ValueChanged<bool>? onVideoAudioChanged;
  final ValueChanged<XFile>? onBackgroundMusicFile;
  final void Function(String id, String label)? onBackgroundMusicPreset;
  final VoidCallback? onBackgroundMusicClear;

  static const double maxSeconds = 60;

  @override
  State<VideoCropperScreen> createState() => _VideoCropperScreenState();
}

class _VideoCropperScreenState extends State<VideoCropperScreen> {
  VideoPlayerController? _probe;
  double? _durationSeconds;
  String? _error;
  bool _openingEditor = false;

  @override
  void initState() {
    super.initState();
    _loadDuration();
  }

  Future<void> _loadDuration() async {
    try {
      final path = widget.file.path;
      final controller = !kIsWeb &&
              !path.startsWith('http') &&
              !path.startsWith('blob:')
          ? VideoPlayerController.file(File(path))
          : VideoPlayerController.networkUrl(Uri.parse(path));
      _probe = controller;
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _durationSeconds =
            controller.value.duration.inMilliseconds / 1000.0;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  bool get _canKeepFull {
    final duration = _durationSeconds;
    return duration != null &&
        duration > 0 &&
        duration <= VideoCropperScreen.maxSeconds + .05;
  }

  String get _durationLabel {
    final duration = _durationSeconds;
    if (duration == null || duration <= 0) return 'Checking duration…';
    final total = duration.round();
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _keepFullVideo() {
    if (!_canKeepFull) return;
    Navigator.of(context).pop<XFile>(widget.file);
  }

  Future<void> _openEditor() async {
    if (_openingEditor) return;
    setState(() => _openingEditor = true);
    final result = await Navigator.of(context, rootNavigator: true).push<XFile>(
      MaterialPageRoute(
        builder: (_) => editor.VideoCropperScreen(
          file: widget.file,
          videoAudioEnabled: widget.videoAudioEnabled,
          backgroundMusic: widget.backgroundMusic,
          backgroundMusicPreset: widget.backgroundMusicPreset,
          backgroundMusicName: widget.backgroundMusicName,
          onVideoAudioChanged: widget.onVideoAudioChanged,
          onBackgroundMusicFile: widget.onBackgroundMusicFile,
          onBackgroundMusicPreset: widget.onBackgroundMusicPreset,
          onBackgroundMusicClear: widget.onBackgroundMusicClear,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _openingEditor = false);
    if (result != null) Navigator.of(context).pop<XFile>(result);
  }

  @override
  void dispose() {
    _probe?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canKeepFull = _canKeepFull;
    final checking = _durationSeconds == null && _error == null;
    final ink = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: ink),
                  ),
                  Expanded(
                    child: Text(
                      'VIDEO',
                      textAlign: TextAlign.center,
                      style: AppTheme.displayItalic.copyWith(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'KEEP IT ORIGINAL OR EDIT IT',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$_durationLabel · videos up to 1 minute can stay completely untouched',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: ink.withAlpha(150),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 26),
              _ChoiceCard(
                icon: Icons.play_circle_fill_rounded,
                title: 'KEEP FULL VIDEO',
                subtitle: canKeepFull
                    ? 'Original file · no crop · no trim · no re-render'
                    : checking
                        ? 'Checking video length…'
                        : 'Available for videos 60 seconds or shorter',
                accent: AppTheme.brandPrimary,
                enabled: canKeepFull,
                onTap: _keepFullVideo,
              ),
              const SizedBox(height: 14),
              _ChoiceCard(
                icon: Icons.tune_rounded,
                title: 'EDIT / TRIM VIDEO',
                subtitle: 'Only use this when you actually want to cut, crop, mute, or add music',
                accent: AppTheme.brandAccent2,
                enabled: !checking && !_openingEditor,
                busy: _openingEditor,
                onTap: _openEditor,
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Could not read the duration automatically. You can still open the editor.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: ink.withAlpha(150),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                'Swipess does not need to crop a normal video just to display it in a portrait card. The card handles the visual fit separately.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: ink.withAlpha(115),
                  fontSize: 10,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.enabled,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final bool enabled;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: enabled ? accent.withAlpha(18) : ink.withAlpha(7),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: enabled ? accent.withAlpha(145) : ink.withAlpha(18),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: enabled ? accent.withAlpha(35) : ink.withAlpha(8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: busy
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accent,
                        ),
                      )
                    : Icon(
                        icon,
                        color: enabled ? accent : ink.withAlpha(70),
                        size: 27,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        color: enabled ? ink : ink.withAlpha(90),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        color: ink.withAlpha(enabled ? 150 : 80),
                        fontSize: 10,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: enabled ? ink.withAlpha(150) : ink.withAlpha(55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
