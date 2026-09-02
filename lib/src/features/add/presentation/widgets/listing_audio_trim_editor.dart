import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ListingAudioTrimEditor extends StatefulWidget {
  const ListingAudioTrimEditor({
    super.key,
    required this.file,
    this.disabled = false,
  });

  final XFile file;
  final bool disabled;

  @override
  State<ListingAudioTrimEditor> createState() =>
      _ListingAudioTrimEditorState();
}

class _ListingAudioTrimEditorState extends State<ListingAudioTrimEditor> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _positionSub;

  int _durationMs = 60000;
  double _start = 0;
  double _end = 30000;
  bool _playing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _durationSub = _player.onDurationChanged.listen((duration) {
      if (!mounted || duration.inMilliseconds <= 0) return;
      setState(() {
        _durationMs = duration.inMilliseconds;
        _start = _start.clamp(0, (_durationMs - 1000).toDouble());
        _end = _end.clamp(_start + 1000, _durationMs.toDouble());
      });
    });
    _positionSub = _player.onPositionChanged.listen((position) async {
      if (!_playing || position.inMilliseconds < _end.round()) return;
      await _player.pause();
      if (mounted) setState(() => _playing = false);
    });
    unawaited(_load());
  }

  Future<Source> _source() async {
    if (!kIsWeb && widget.file.path.isNotEmpty) {
      return DeviceFileSource(widget.file.path);
    }
    return BytesSource(await widget.file.readAsBytes());
  }

  Future<void> _load() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final row = await Supabase.instance.client
            .from('pending_listing_audio_trim')
            .select('start_ms, end_ms')
            .eq('user_id', user.id)
            .maybeSingle();
        if (row != null) {
          _start = ((row['start_ms'] as num?)?.toInt() ?? 0).toDouble();
          final end = (row['end_ms'] as num?)?.toInt();
          if (end != null) _end = end.toDouble();
        }
      }
      await _player.setSource(await _source());
      final duration = await _player.getDuration();
      if (!mounted || duration == null || duration.inMilliseconds <= 0) return;
      setState(() {
        _durationMs = duration.inMilliseconds;
        _start = _start.clamp(0, (_durationMs - 1000).toDouble());
        _end = _end.clamp(_start + 1000, _durationMs.toDouble());
      });
    } catch (_) {}
  }

  Future<bool> _save({bool showMessage = false}) async {
    if (_saving) return false;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to save your music cut.')),
        );
      }
      return false;
    }

    final start = _start.round().clamp(0, _durationMs - 1);
    final end = _end.round().clamp(start + 1, _durationMs);
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('pending_listing_audio_trim').upsert({
        'user_id': user.id,
        'start_ms': start,
        'end_ms': end >= _durationMs ? null : end,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Music cut saved.')),
        );
      }
      return true;
    } catch (_) {
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the music cut. Try again.'),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _quickLength(int seconds) {
    final wanted = seconds * 1000.0;
    setState(() {
      _end = (_start + wanted).clamp(_start + 1000, _durationMs.toDouble());
    });
    unawaited(_save());
  }

  Future<void> _preview() async {
    if (widget.disabled) return;
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    try {
      await _player.setSource(await _source());
      await _player.seek(Duration(milliseconds: _start.round()));
      await _player.resume();
      if (mounted) setState(() => _playing = true);
    } catch (_) {}
  }

  String _time(double ms) {
    final seconds = (ms / 1000).floor();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final max = _durationMs.toDouble().clamp(1000, double.infinity);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.content_cut_rounded,
                color: AppTheme.brandPrimary,
                size: 17,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'TRIM YOUR MUSIC',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${_time(_start)} – ${_time(_end)}',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Pick exactly which part of your song plays. The original file stays untouched.',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 8.5,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          RangeSlider(
            min: 0,
            max: max,
            values: RangeValues(
              _start.clamp(0, max - 1),
              _end.clamp(_start + 1, max),
            ),
            onChanged: widget.disabled
                ? null
                : (values) {
                    if (values.end - values.start < 1000) return;
                    setState(() {
                      _start = values.start;
                      _end = values.end;
                    });
                  },
            onChangeEnd: widget.disabled ? null : (_) => unawaited(_save()),
          ),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [5, 10, 15, 20, 30, 45, 60]
                .map(
                  (seconds) => ActionChip(
                    label: Text('${seconds}s'),
                    onPressed: widget.disabled
                        ? null
                        : () => _quickLength(seconds),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.disabled ? null : _preview,
                  icon: Icon(
                    _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(_playing ? 'PAUSE' : 'PREVIEW CUT'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: widget.disabled || _saving
                    ? null
                    : () => unawaited(_save(showMessage: true)),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_saving ? 'SAVING' : 'SAVE CUT'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
