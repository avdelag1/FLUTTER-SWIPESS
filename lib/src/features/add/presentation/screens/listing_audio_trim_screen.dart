import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/add/presentation/widgets/listing_audio_trim_editor.dart';
import 'package:flutter_swipes/src/features/add/presentation/widgets/listing_video_inline_preview.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full-screen soundtrack cutter shown immediately after a user chooses music.
/// The selected video stays visible and muted while the user chooses the exact
/// part of the song that should play with it.
class ListingAudioTrimScreen extends StatelessWidget {
  const ListingAudioTrimScreen({
    super.key,
    required this.audioFile,
    required this.videoFile,
    required this.videoClipSeconds,
  });

  final XFile audioFile;
  final XFile videoFile;
  final double videoClipSeconds;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(10, 6, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: Icon(Icons.arrow_back_ios_new_rounded),
                    color: Colors.white,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TRIM YOUR AUDIO',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.2,
                          ),
                        ),
                        Text(
                          'Choose the exact part that plays with your video',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.brandPrimary.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'VIDEO MUTED',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.brandPrimary,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(14, 4, 14, 24),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      height: 360,
                      child: ListingVideoInlinePreview(
                        file: videoFile,
                        muted: true,
                        height: 360,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.fromLTRB(12, 12, 12, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF17171C),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: .07)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.graphic_eq_rounded,
                                color: AppTheme.brandPrimary, size: 18),
                            SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                audioFile.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              '${videoClipSeconds.ceil().clamp(1, 60)}s video',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white54,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        FutureBuilder<Uint8List>(
                          future: audioFile.readAsBytes(),
                          builder: (context, snapshot) {
                            return SizedBox(
                              height: 76,
                              width: double.infinity,
                              child: CustomPaint(
                                painter: _WaveformPainter(snapshot.data),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  ListingAudioTrimEditor(
                    file: audioFile,
                    maxClipSeconds: videoClipSeconds.clamp(1, 60),
                    onSaved: (_, __) => Navigator.of(context).pop(true),
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

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter(this.bytes);

  final Uint8List? bytes;

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 72;
    final gap = 2.0;
    final barWidth = math.max(1.2, (size.width - gap * (bars - 1)) / bars);
    final centerY = size.height / 2;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .78)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    final source = bytes;
    for (var i = 0; i < bars; i++) {
      double normalized;
      if (source == null || source.isEmpty) {
        normalized = .18 + ((i * 37) % 53) / 100;
      } else {
        final start = (i * source.length / bars).floor();
        final end = math.min(source.length, ((i + 1) * source.length / bars).ceil());
        var energy = 0.0;
        var count = 0;
        for (var j = start; j < end; j += math.max(1, (end - start) ~/ 18)) {
          energy += (source[j] - 128).abs() / 128;
          count++;
        }
        normalized = count == 0 ? .2 : (energy / count).clamp(.08, 1.0);
      }
      final h = math.max(8.0, size.height * (.22 + normalized * .68));
      final x = i * (barWidth + gap) + barWidth / 2;
      canvas.drawLine(Offset(x, centerY - h / 2), Offset(x, centerY + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) => oldDelegate.bytes != bytes;
}
