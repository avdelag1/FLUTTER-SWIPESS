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
    this.maxClipSeconds,
    this.onSaved,
  });

  final XFile file;
  final bool disabled;

  /// Limits the selected soundtrack window to the visible video loop length.
  final double? maxClipSeconds;

  /// Called only after the user explicitly taps SAVE AUDIO.
  final void Function(int startMs, int? endMs)? onSaved;

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

  int? get _maxClipMs {
    final seconds = widget.maxClipSeconds;
    if (seconds == null || seconds <= 0) return null;
    return (seconds * 1000).round().clamp(1000, 60000);
  }

  @override
  void initState() {
    super.initState();
    _durationSub = _player.onDurationChanged.listen((duration) {
      if (!mounted || duration.inMilliseconds <= 0) return;
      setState(() {
        _durationMs = duration.inMilliseconds;
        _normalizeSelection();
      });
    });
    _positionSub = _player.onPositionChanged.listen((position) async {
      if (!_playing || position.inMilliseconds < _end.round()) return;
      await _player.pause();
      if (mounted) setState(() => _playing = false);
    });
    unawaited(_load());
  }

  void _normalizeSelection() {
    _start = _start.clamp(0.0, (_durationMs - 1000).toDouble()).toDouble();
    final limit = _maxClipMs;
    final maxEnd = limit == null
        ? _durationMs.toDouble()
        : (_start + limit)
              .clamp(_start + 1000.0, _durationMs.toDouble())
              .toDouble();
    _end = _end.clamp(_start + 1000.0, maxEnd).toDouble();
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
        _normalizeSelection();
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
        widget.onSaved?.call(start, end >= _durationMs ? null : end);
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
    final maxAllowed = _maxClipMs;
    final wanted = seconds * 1000.0;
    final effective = maxAllowed == null
        ? wanted
        : wanted.clamp(1000.0, maxAllowed.toDouble()).toDouble();
    setState(() {
      _end = (_start + effective)
          .clamp(_start + 1000.0, _durationMs.toDouble())
          .toDouble();
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
    final double max = _durationMs
        .toDouble()
        .clamp(1000.0, double.infinity)
        .toDouble();
    final double startValue = _start.clamp(0.0, max - 1.0).toDouble();
    final double endValue = _end.clamp(startValue + 1.0, max).toDouble();
    final maxClip = _maxClipMs;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1E24), Color(0xFF131318)],
        ),
        borderRadius: BorderRadius.circular(20),
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
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'SELECT THE AUDIO MOMENT',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .25,
                  ),
                ),
              ),
              Text(
                '${_time(_start)} – ${_time(_end)}',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            maxClip == null
                ? 'Drag the window to choose exactly which part of your song plays.'
                : 'Your soundtrack cut is limited to the ${(_maxClipMs! / 1000).ceil()}s video loop. The original video audio stays muted.',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 9,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          RangeSlider(
            min: 0.0,
            max: max,
            values: RangeValues(startValue, endValue),
            onChanged: widget.disabled
                ? null
                : (values) {
                    if (values.end - values.start < 1000.0) return;
                    var start = values.start;
                    var end = values.end;
                    if (maxClip != null && end - start > maxClip) {
                      if ((start - _start).abs() > (end - _end).abs()) {
                        start = end - maxClip;
                      } else {
                        end = start + maxClip;
                      }
                    }
                    setState(() {
                      _start = start.clamp(0.0, max - 1.0).toDouble();
                      _end = end.clamp(_start + 1000.0, max).toDouble();
                    });
                  },
            onChangeEnd: widget.disabled ? null : (_) => unawaited(_save()),
          ),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60]
                .map(
                  (seconds) => ActionChip(
                    label: Text('${seconds}s'),
                    onPressed:
                        widget.disabled ||
                            (maxClip != null && seconds * 1000 > maxClip)
                        ? null
                        : () => _quickLength(seconds),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.disabled ? null : _preview,
                  icon: Icon(
                    _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(_playing ? 'PAUSE' : 'PREVIEW WITH VIDEO'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: .16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: widget.disabled || _saving
                    ? null
                    : () => unawaited(_save(showMessage: true)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                  foregroundColor: Colors.white,
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_saving ? 'SAVING' : 'SAVE AUDIO'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
