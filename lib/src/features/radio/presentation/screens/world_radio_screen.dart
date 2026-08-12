import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/radio/domain/radio_station.dart';
import 'package:flutter_swipes/src/features/radio/presentation/providers/radio_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class WorldRadioScreen extends ConsumerWidget {
  const WorldRadioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(radioControllerProvider);
    final cities = kRadioStations.map((s) => s.city).toSet().toList()..sort();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withAlpha(40)),
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('WORLD RADIO', style: AppTheme.displayItalic.copyWith(fontSize: 22)),
                        Text(
                          playback.current == null
                              ? 'Pick a station'
                              : '${playback.current!.name} · ${playback.playing ? 'Live' : 'Paused'}',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (playback.current != null)
                    IconButton(
                      onPressed: () => ref.read(radioControllerProvider.notifier).stop(),
                      icon: const Icon(Icons.stop_rounded, color: Colors.white70),
                    ),
                ],
              ),
            ),
            if (playback.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(playback.error!, style: const TextStyle(color: Colors.redAccent)),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  for (final city in cities) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Text(
                        city.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    for (final station in kRadioStations.where((s) => s.city == city))
                      _StationTile(
                        station: station,
                        active: playback.current?.id == station.id,
                        playing: playback.current?.id == station.id && playback.playing,
                        loading: playback.current?.id == station.id && playback.loading,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(radioControllerProvider.notifier).toggle(station);
                        },
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StationTile extends StatelessWidget {
  const _StationTile({
    required this.station,
    required this.active,
    required this.playing,
    required this.loading,
    required this.onTap,
  });

  final RadioStation station;
  final bool active;
  final bool playing;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: active ? AppTheme.brandPrimary.withAlpha(40) : Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? AppTheme.brandPrimary.withAlpha(120) : Colors.white.withAlpha(25),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      station.genre,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              else if (playing)
                const Icon(Icons.graphic_eq_rounded, color: AppTheme.brandPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
