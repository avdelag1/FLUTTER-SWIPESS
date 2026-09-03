import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/camera/data/video_recut_v2.dart';
import 'package:flutter_swipes/src/features/camera/domain/video_trim_selection.dart';
import 'package:flutter_swipes/src/features/camera/presentation/screens/audio_cropper_screen_v2.dart';
import 'package:flutter_swipes/src/features/swipes/domain/listing_soundtrack.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

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

  static const maxSeconds = VideoTrimSelection.maxSeconds;

  @override
  State<VideoCropperScreen> createState() => _VideoCropperScreenState();
}

enum _TrimDragMode { left, move, right }

class _VideoCropperScreenState extends State<VideoCropperScreen> {
  static const _fitAccent = AppTheme.brandAccent2;
  static const _portraitAccent = Color(0xFF8B5CF6);
  static const _saveAccent = Color(0xFF22C55E);
  static const _musicAccent = AppTheme.brandAccent2;

  final ScrollController _timeline = ScrollController();
  final ListingSoundtrackPlayer _soundtrack = ListingSoundtrackPlayer();
  final AudioPlayer _uploadedMusic = AudioPlayer();

  VideoPlayerController? _player;
  VideoTrimSelection _selection = VideoTrimSelection.initial(0);
  List<Uint8List?> _thumbs = const [];
  double _duration = 0;
  bool _ready = false;
  bool _processing = false;
  bool _videoAudioEnabled = true;
  bool _portraitCrop = true;
  double _cropX = .5;
  String? _error;
  XFile? _music;
  String? _musicPreset;
  String? _musicName;
  double _musicStart = 0;
  double? _musicEnd;
  double? _musicDuration;
  bool _musicPrepared = false;
  bool _loopSyncing = false;
  _TrimDragMode _dragMode = _TrimDragMode.move;
  VideoTrimSelection? _dragOrigin;
  double _dragDx = 0;
  double? _cropDragOrigin;

  @override
  void initState() {
    super.initState();
    _videoAudioEnabled = widget.videoAudioEnabled;
    _music = widget.backgroundMusic;
    _musicPreset = widget.backgroundMusicPreset;
    _musicName = widget.backgroundMusicName;
    unawaited(_boot());
  }

  Future<void> _boot() async {
    try {
      final path = widget.file.path;
      final controller = (!kIsWeb && !path.startsWith('http') && !path.startsWith('blob:'))
          ? VideoPlayerController.file(File(path))
          : VideoPlayerController.networkUrl(Uri.parse(path));
      await controller.initialize();
      final duration = controller.value.duration.inMilliseconds / 1000.0;
      controller.addListener(_tick);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _player = controller;
        _duration = duration;
        _selection = VideoTrimSelection.initial(duration);
        _ready = true;
      });
      await controller.setVolume(_videoAudioEnabled ? 1 : 0);
      await controller.seekTo(_d(_selection.start));
      await controller.play();
      unawaited(_loadThumbs());
      if (_music != null && _musicPreset == null) {
        await _loadSavedMusicTrim();
        await _seekStart();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _loadThumbs() async {
    if (_duration <= 0) return;
    final count = math.max(1, math.min(24, (_duration / 5).ceil())).toInt();
    if (!mounted) return;
    final thumbs = List<Uint8List?>.filled(count, null);
    setState(() => _thumbs = List<Uint8List?>.from(thumbs));

    for (var start = 0; start < count; start += 4) {
      if (!mounted) return;
      final end = math.min(count, start + 4);
      await Future.wait<void>([
        for (var i = start; i < end; i++)
          () async {
            try {
              final sample = count == 1
                  ? _duration / 2
                  : (_duration * i / (count - 1)).clamp(
                      0.0,
                      math.max(0.0, _duration - .05),
                    );
              thumbs[i] = await VideoThumbnail.thumbnailData(
                video: widget.file.path,
                imageFormat: ImageFormat.JPEG,
                maxWidth: 144,
                quality: 34,
                timeMs: (sample * 1000).round(),
              );
            } catch (_) {}
          }(),
      ]);
      if (mounted) setState(() => _thumbs = List<Uint8List?>.from(thumbs));
    }
  }

  void _tick() {
    final player = _player;
    if (player == null || !player.value.isInitialized || _loopSyncing) return;
    final pos = player.value.position.inMilliseconds / 1000.0;
    if (pos >= _selection.end - .04 || pos < _selection.start - .04) {
      unawaited(_syncSelectionPlayback(resume: true));
    }
  }

  Duration _d(double seconds) => Duration(milliseconds: (seconds * 1000).round());

  Future<void> _syncSelectionPlayback({required bool resume}) async {
    if (_loopSyncing) return;
    final player = _player;
    if (player == null) return;
    _loopSyncing = true;
    try {
      await player.pause();
      await _uploadedMusic.pause();
      await player.seekTo(_d(_selection.start));
      if (_music != null && _musicPreset == null && _musicEnd != null) {
        await _restartUploadedMusic(resume: false);
      }
      if (resume) {
        await player.play();
        if (_music != null && _musicPreset == null && _musicEnd != null) {
          await _uploadedMusic.resume();
        }
      }
    } finally {
      _loopSyncing = false;
    }
  }

  Future<void> _seekStart() => _syncSelectionPlayback(resume: true);

  void _normalizeMusicWindow() {
    if (_music == null || _musicPreset != null) return;
    final maxEnd = _musicDuration ?? double.infinity;
    _musicEnd = math.min(maxEnd, _musicStart + _selection.length).toDouble();
  }

  Future<Source> _uploadedMusicSource() async {
    final file = _music;
    if (file == null) throw StateError('No uploaded soundtrack.');
    if (!kIsWeb && file.path.isNotEmpty) return DeviceFileSource(file.path);
    return BytesSource(await file.readAsBytes());
  }

  Future<void> _prepareUploadedMusic() async {
    if (_music == null || _musicPreset != null || _musicPrepared) return;
    await _uploadedMusic.stop();
    await _uploadedMusic.setSource(await _uploadedMusicSource());
    final duration = await _uploadedMusic.getDuration();
    _musicDuration = duration == null ? null : duration.inMilliseconds / 1000.0;
    _musicPrepared = true;
    _normalizeMusicWindow();
  }

  Future<void> _restartUploadedMusic({required bool resume}) async {
    if (_music == null || _musicPreset != null) return;
    await _prepareUploadedMusic();
    await _uploadedMusic.pause();
    await _uploadedMusic.seek(_d(_musicStart));
    if (resume) await _uploadedMusic.resume();
  }

  Future<void> _loadSavedMusicTrim() async {
    if (_music == null || _musicPreset != null) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final row = await Supabase.instance.client
            .from('pending_listing_audio_trim')
            .select('start_ms, end_ms')
            .eq('user_id', user.id)
            .maybeSingle();
        if (row != null) {
          _musicStart = ((row['start_ms'] as num?)?.toDouble() ?? 0) / 1000.0;
          final end = (row['end_ms'] as num?)?.toDouble();
          _musicEnd = end == null ? null : end / 1000.0;
        }
      } catch (_) {}
    }
    _musicPrepared = false;
    try {
      await _prepareUploadedMusic();
    } catch (_) {
      _normalizeMusicWindow();
    }
    if (_musicEnd == null || (_musicEnd! - _musicStart - _selection.length).abs() > .08) {
      _normalizeMusicWindow();
    }
    if (mounted) setState(() {});
  }

  void _preset(double seconds) {
    if (seconds > _duration + .01) return;
    AppHaptics.selection();
    setState(() {
      _selection = _selection.preset(seconds);
      _normalizeMusicWindow();
    });
    unawaited(_seekStart());
    _ensureVisible();
  }

  void _jump(double second) {
    final next = _selection.moveTo(second - _selection.length / 2);
    AppHaptics.selection();
    setState(() => _selection = next);
    unawaited(_seekStart());
    _ensureVisible();
  }

  void _dragStart(DragStartDetails details, double width) {
    _dragOrigin = _selection;
    _dragDx = 0;
    final edge = math.min(14.0, width * .3);
    final x = details.localPosition.dx;
    _dragMode = x <= edge
        ? _TrimDragMode.left
        : x >= width - edge
            ? _TrimDragMode.right
            : _TrimDragMode.move;
    AppHaptics.light();
  }

  void _dragUpdate(DragUpdateDetails details, double px) {
    final origin = _dragOrigin;
    if (origin == null || px <= 0) return;
    _dragDx += details.primaryDelta ?? 0;
    final delta = _dragDx / px;
    final next = switch (_dragMode) {
      _TrimDragMode.left => origin.resizeStartTo(origin.start + delta),
      _TrimDragMode.right => origin.resizeEndTo(origin.end + delta),
      _TrimDragMode.move => origin.moveTo(origin.start + delta),
    };
    setState(() {
      _selection = next;
      _normalizeMusicWindow();
    });
  }

  void _dragEnd(DragEndDetails _) {
    _dragOrigin = null;
    _dragDx = 0;
    AppHaptics.medium();
    unawaited(_seekStart());
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

  Future<void> _setOriginalAudio(bool enabled) async {
    setState(() => _videoAudioEnabled = enabled);
    await _player?.setVolume(enabled ? 1 : 0);
    widget.onVideoAudioChanged?.call(enabled);
  }

  Future<void> _pickMusic() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'aac', 'wav', 'ogg'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final picked = result.files.first;
    if (picked.size > 15 * 1024 * 1024) {
      _message('Music file must be under 15MB.');
      return;
    }

    XFile? file;
    if (picked.bytes != null) {
      file = XFile.fromData(picked.bytes!, name: picked.name, length: picked.size);
    } else if (picked.path != null && picked.path!.isNotEmpty) {
      file = XFile(picked.path!, name: picked.name);
    }
    if (file == null) return;

    await _uploadedMusic.stop();
    setState(() {
      _music = file;
      _musicPreset = null;
      _musicName = file!.name;
      _musicStart = 0;
      _musicEnd = null;
      _musicDuration = null;
      _musicPrepared = false;
    });
    widget.onBackgroundMusicFile?.call(file);
    await _setOriginalAudio(false);
    await _soundtrack.stop();
    if (!mounted) return;

    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AudioCropperScreenV2(
          file: file!,
          videoFile: widget.file,
          maxClipSeconds: _selection.length,
          videoStartSeconds: _selection.start,
          videoEndSeconds: _selection.end,
          portraitCrop: _portraitCrop,
          cropX: _cropX,
        ),
      ),
    );
    if (saved == true && mounted) {
      await _loadSavedMusicTrim();
      await _seekStart();
      _message('Music is locked to this exact video cut.');
    }
  }

  Future<void> _selectPreset(ListingSoundtrackPreset preset) async {
    await _uploadedMusic.stop();
    setState(() {
      _music = null;
      _musicPreset = preset.id;
      _musicName = preset.label;
      _musicStart = 0;
      _musicEnd = null;
      _musicDuration = null;
      _musicPrepared = false;
    });
    widget.onBackgroundMusicPreset?.call(preset.id, preset.label);
    await _setOriginalAudio(false);
    try {
      await _soundtrack.play(presetId: preset.id, volume: .58);
    } catch (_) {}
  }

  Future<void> _clearMusic() async {
    await _soundtrack.stop();
    await _uploadedMusic.stop();
    setState(() {
      _music = null;
      _musicPreset = null;
      _musicName = null;
      _musicStart = 0;
      _musicEnd = null;
      _musicDuration = null;
      _musicPrepared = false;
    });
    widget.onBackgroundMusicClear?.call();
  }

  Future<void> _audioSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111318),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.library_music_rounded, color: _musicAccent),
              const SizedBox(width: 8),
              Expanded(child: Text('AUDIO & MUSIC', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900))),
              IconButton(onPressed: () => Navigator.pop(sheet), icon: const Icon(Icons.close_rounded, color: Colors.white70)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheet);
                    unawaited(_pickMusic());
                  },
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('UPLOAD MY MUSIC'),
                  style: FilledButton.styleFrom(backgroundColor: _musicAccent, foregroundColor: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _setOriginalAudio(!_videoAudioEnabled),
                icon: Icon(_videoAudioEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded),
                label: Text(_videoAudioEnabled ? 'ORIGINAL ON' : 'MUTED'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              ),
            ]),
            const SizedBox(height: 14),
            Text('SWIPESS AUDIO · 10 BUILT-IN SOUNDS', style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: listingSoundtrackPresets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final p = listingSoundtrackPresets[i];
                  final active = _musicPreset == p.id;
                  return InkWell(
                    onTap: () => _selectPreset(p),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 118,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: active ? _portraitAccent.withAlpha(36) : Colors.white.withAlpha(10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: active ? _portraitAccent : Colors.white24),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.emoji, style: const TextStyle(fontSize: 20)),
                        const Spacer(),
                        Text(p.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  );
                },
              ),
            ),
            if ((_musicName ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.music_note_rounded, color: _music != null ? _musicAccent : _portraitAccent, size: 18),
                const SizedBox(width: 7),
                Expanded(child: Text(_musicName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
                TextButton(onPressed: _clearMusic, child: const Text('REMOVE')),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    if (!_ready || _processing) return;
    setState(() => _processing = true);
    try {
      if (_music != null && _musicPreset == null) await _loadSavedMusicTrim();
      await _player?.pause();
      await _soundtrack.stop();
      await _uploadedMusic.pause();
      final output = await recutVideoWindowV2(
        source: widget.file,
        start: _selection.start,
        end: _selection.end,
        portraitCrop: _portraitCrop,
        cropX: _cropX,
        backgroundMusic: _music,
        musicStart: _musicStart,
        musicEnd: _musicEnd,
        includeOriginalAudio: _videoAudioEnabled,
      );
      if (mounted) Navigator.pop(context, output);
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        _message('Could not save this cut yet. Please retry — your video and music trim are still selected.');
        unawaited(_seekStart());
      }
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    _player?.removeListener(_tick);
    _player?.dispose();
    _soundtrack.dispose();
    unawaited(_uploadedMusic.dispose());
    _timeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(children: [
          _header(),
          Expanded(child: _preview()),
          _controls(),
        ]),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 4),
        child: Row(children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white)),
          Expanded(child: Text('TRIM VIDEO', textAlign: TextAlign.center, style: AppTheme.displayItalic.copyWith(fontSize: 18))),
          const SizedBox(width: 48),
        ]),
      );

  Widget _preview() {
    if (_error != null) return Center(child: Text('Could not preview video', style: GoogleFonts.plusJakartaSans(color: Colors.white)));
    if (!_ready || _player == null) return const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
    final player = _player!;
    final sourceAspect = player.value.aspectRatio == 0 ? 16 / 9 : player.value.aspectRatio;

    final video = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: _portraitCrop ? 9 / 16 : sourceAspect,
        child: ColoredBox(
          color: Colors.black,
          child: Stack(fit: StackFit.expand, children: [
            if (_portraitCrop)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => _cropDragOrigin = _cropX,
                onHorizontalDragUpdate: (details) {
                  final width = math.max(120.0, MediaQuery.sizeOf(context).width);
                  final base = _cropDragOrigin ?? _cropX;
                  final delta = (details.primaryDelta ?? 0) / width;
                  setState(() {
                    _cropX = (base - delta).clamp(0.0, 1.0).toDouble();
                    _cropDragOrigin = _cropX;
                  });
                },
                onHorizontalDragEnd: (_) => _cropDragOrigin = null,
                child: FittedBox(
                  fit: BoxFit.cover,
                  alignment: Alignment(_cropX * 2 - 1, 0),
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(width: player.value.size.width, height: player.value.size.height, child: VideoPlayer(player)),
                ),
              )
            else
              VideoPlayer(player),
            Positioned(
              right: 10,
              bottom: 10,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _action(
                  icon: _videoAudioEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  active: !_videoAudioEnabled,
                  activeColor: _fitAccent,
                  onTap: () => _setOriginalAudio(!_videoAudioEnabled),
                ),
                const SizedBox(width: 7),
                _action(
                  icon: Icons.library_music_rounded,
                  active: (_musicName ?? '').isNotEmpty,
                  activeColor: _music != null ? _musicAccent : _portraitAccent,
                  onTap: _audioSheet,
                ),
              ]),
            ),
            if (_portraitCrop)
              Positioned(
                left: 10,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: Colors.black.withAlpha(150), borderRadius: BorderRadius.circular(999)),
                  child: Text('DRAG VIDEO ↔', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                ),
              ),
          ]),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _portraitCrop ? 74 : 18, vertical: 4),
      child: Center(child: video),
    );
  }

  Widget _controls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      decoration: BoxDecoration(color: Colors.black.withAlpha(22), borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: _modeButton('FIT', !_portraitCrop, _fitAccent, () => setState(() => _portraitCrop = false))),
          const SizedBox(width: 8),
          Expanded(child: _modeButton('PORTRAIT 9:16', _portraitCrop, _portraitAccent, () => setState(() => _portraitCrop = true))),
        ]),
        if (_portraitCrop) ...[
          const SizedBox(height: 7),
          Row(children: [
            Text('FRAME', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
            Expanded(
              child: Slider(
                value: _cropX,
                onChanged: (v) => setState(() => _cropX = v),
                activeColor: _portraitAccent,
                inactiveColor: Colors.white24,
              ),
            ),
            Text('LEFT / RIGHT', style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.w700)),
          ]),
        ],
        const SizedBox(height: 6),
        Text('FILMSTRIP · 5 SECOND SNAP', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
        const SizedBox(height: 4),
        Text('Tap to jump · drag the middle to move · drag edges to resize', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(height: 82, child: _timelineWidget()),
        const SizedBox(height: 8),
        _presets(),
        const SizedBox(height: 8),
        Text('${_time(_selection.start)}  →  ${_time(_selection.end)}   ·   ${_selection.length.toStringAsFixed(_selection.length % 1 == 0 ? 0 : 1)}s', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
        if (_music != null && _musicEnd != null) ...[
          const SizedBox(height: 5),
          Text(
            'MUSIC ${_time(_musicStart)} → ${_time(_musicEnd!)}  ·  LOCKED TO VIDEO',
            style: GoogleFonts.plusJakartaSans(color: _musicAccent, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .35),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed: _ready && !_processing ? _confirm : null,
            icon: _processing
                ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded),
            label: Text(_processing ? 'SAVING VIDEO + AUDIO…' : 'SAVE VIDEO', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900)),
            style: FilledButton.styleFrom(backgroundColor: _saveAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
          ),
        ),
      ]),
    );
  }

  Widget _modeButton(String text, bool active, Color accent, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? accent : Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? accent : Colors.white24),
          ),
          child: Text(text, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
        ),
      );

  Widget _timelineWidget() {
    if (!_ready || _duration <= 0) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, c) {
      final viewport = math.max(1.0, c.maxWidth).toDouble();
      final visible = _duration <= 60 ? math.max(.1, _duration).toDouble() : 60.0;
      final px = viewport / visible;
      final total = math.max(viewport, _duration * px).toDouble();
      final left = _selection.start * px;
      final width = math.max(2.0, _selection.length * px).toDouble();
      final right = left + width;
      final accent = _portraitCrop ? _portraitAccent : _fitAccent;
      final timeline = SizedBox(
        width: total,
        height: 82,
        child: Stack(children: [
          Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(14), child: _filmstrip(px))),
          if (left > 0) Positioned(left: 0, top: 0, bottom: 0, width: left, child: ColoredBox(color: Colors.black.withAlpha(132))),
          if (right < total) Positioned(left: right, right: 0, top: 0, bottom: 0, child: ColoredBox(color: Colors.black.withAlpha(132))),
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
                decoration: BoxDecoration(color: accent.withAlpha(24), border: Border.all(color: accent, width: 3), borderRadius: BorderRadius.circular(12)),
                child: Stack(alignment: Alignment.center, children: [
                  Positioned(left: 4, top: 14, bottom: 14, child: _handle()),
                  Positioned(right: 4, top: 14, bottom: 14, child: _handle()),
                  if (width >= 36) const Icon(Icons.drag_indicator_rounded, color: Colors.white, size: 18),
                ]),
              ),
            ),
          ),
          if (_player != null)
            AnimatedBuilder(
              animation: _player!,
              builder: (_, __) {
                final p = _player!.value.position.inMilliseconds / 1000.0;
                return Positioned(
                  left: (p.clamp(0.0, _duration) * px).clamp(0.0, math.max(0.0, total - 2)).toDouble(),
                  top: 3,
                  bottom: 3,
                  width: 2,
                  child: const ColoredBox(color: Colors.white),
                );
              },
            ),
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

  Widget _filmstrip(double px) {
    final count = math.max(1, (_duration / 5).ceil()).toInt();
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < count; i++)
        SizedBox(
          width: math.max(1.0, math.min(5.0, _duration - i * 5) * px).toDouble(),
          child: Stack(fit: StackFit.expand, children: [
            if (i < _thumbs.length && _thumbs[i] != null)
              Image.memory(_thumbs[i]!, fit: BoxFit.cover, gaplessPlayback: true)
            else
              const ColoredBox(color: Color(0xFF22252B)),
            Positioned(left: 4, bottom: 3, child: Text(_time(i * 5.0), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700))),
          ]),
        ),
    ]);
  }

  Widget _presets() {
    const values = <double>[5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, i) {
          final v = values[i];
          final enabled = v <= _duration + .01;
          final active = (_selection.length - v).abs() < .05;
          final accent = _portraitCrop ? _portraitAccent : _fitAccent;
          return SizedBox(
            width: 68,
            child: GestureDetector(
              onTap: enabled ? () => _preset(v) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? accent : Colors.white.withAlpha(enabled ? 13 : 5),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: active ? accent : Colors.white.withAlpha(enabled ? 38 : 14)),
                ),
                child: Text('${v.toInt()}s', style: GoogleFonts.plusJakartaSans(color: enabled ? Colors.white : Colors.white30, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _handle() => Container(width: 4, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)));

  Widget _action({required IconData icon, required bool active, required Color activeColor, required VoidCallback onTap}) => Material(
        color: active ? activeColor.withAlpha(225) : Colors.black.withAlpha(160),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 42, height: 42, child: Icon(icon, color: Colors.white, size: 21)),
        ),
      );

  String _time(double seconds) {
    final v = math.max(0, seconds.floor());
    return '${v ~/ 60}:${(v % 60).toString().padLeft(2, '0')}';
  }
}
