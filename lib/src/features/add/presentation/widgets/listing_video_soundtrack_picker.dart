import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/camera/presentation/screens/audio_cropper_screen.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/swipes/domain/listing_soundtrack.dart';
import 'package:google_fonts/google_fonts.dart';

class ListingVideoSoundtrackPicker extends StatefulWidget {
  const ListingVideoSoundtrackPicker({
    super.key,
    required this.customMusic,
    required this.presetId,
    required this.soundtrackName,
    required this.onCustomPicked,
    required this.onPresetSelected,
    required this.onClear,
    this.videoFile,
    this.disabled = false,
  });

  final XFile? customMusic;
  final String? presetId;
  final String? soundtrackName;
  final XFile? videoFile;
  final ValueChanged<XFile> onCustomPicked;
  final void Function(String id, String label) onPresetSelected;
  final VoidCallback onClear;
  final bool disabled;

  @override
  State<ListingVideoSoundtrackPicker> createState() =>
      _ListingVideoSoundtrackPickerState();
}

class _ListingVideoSoundtrackPickerState
    extends State<ListingVideoSoundtrackPicker> {
  final ListingSoundtrackPlayer _preview = ListingSoundtrackPlayer();
  String? _previewing;

  @override
  void dispose() {
    unawaited(_preview.dispose());
    super.dispose();
  }

  Future<void> _pickOwnAudio() async {
    if (widget.disabled) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'aac', 'wav', 'ogg'],
      allowMultiple: false,
      withData: true,
    );
    final picked = result?.files.singleOrNull;
    if (picked == null || !mounted) return;
    if (picked.size > 15 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Music file must be under 15MB.')),
      );
      return;
    }

    final XFile file;
    if (picked.bytes != null) {
      file = XFile.fromData(
        picked.bytes!,
        name: picked.name,
        mimeType: _audioMimeType(picked.name),
        length: picked.size,
      );
    } else if (picked.path != null && picked.path!.isNotEmpty) {
      file = XFile(
        picked.path!,
        name: picked.name,
        mimeType: _audioMimeType(picked.name),
      );
    } else {
      return;
    }

    final cropped = await Navigator.of(context, rootNavigator: true).push<XFile>(
      MaterialPageRoute(
        builder: (_) => AudioCropperScreen(file: file, videoFile: widget.videoFile),
      ),
    );
    if (cropped != null && mounted) {
      widget.onCustomPicked(cropped);
    }
  }

  Future<void> _selectPreset(ListingSoundtrackPreset preset) async {
    if (widget.disabled) return;
    widget.onPresetSelected(preset.id, preset.label);
    setState(() => _previewing = 'preset:${preset.id}');
    try {
      await _preview.play(presetId: preset.id, volume: .58);
    } catch (_) {}
  }

  Future<void> _clear() async {
    await _preview.stop();
    if (!mounted) return;
    setState(() => _previewing = null);
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
    final selectedName = widget.soundtrackName?.trim();
    final hasSelection =
        widget.customMusic != null ||
        (widget.presetId?.trim().isNotEmpty ?? false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.library_music_rounded,
                color: AppTheme.brandPrimary,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ADD SOUNDTRACK',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: widget.disabled ? null : _pickOwnAudio,
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: const Text('YOUR MUSIC'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  textStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'Tap a Swipess sound to select + preview it. Choosing music mutes the original video by default; you can turn the original sound back on anytime.',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white60,
              fontSize: 9.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: listingSoundtrackPresets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final preset = listingSoundtrackPresets[index];
                final selected = widget.presetId == preset.id;
                final previewing = _previewing == 'preset:${preset.id}';
                return InkWell(
                  onTap: widget.disabled ? null : () => _selectPreset(preset),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 116,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.brandPrimary.withValues(alpha: .18)
                          : Colors.white.withValues(alpha: .045),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? AppTheme.brandPrimary
                            : Colors.white.withValues(alpha: .08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              preset.emoji,
                              style: const TextStyle(fontSize: 17),
                            ),
                            const Spacer(),
                            Icon(
                              previewing
                                  ? Icons.graphic_eq_rounded
                                  : selected
                                  ? Icons.check_circle_rounded
                                  : Icons.play_circle_outline_rounded,
                              size: 16,
                              color: selected
                                  ? AppTheme.brandPrimary
                                  : Colors.white54,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preset.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preset.bestFor,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 7.5,
                            height: 1.18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (hasSelection) ...[
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
              decoration: BoxDecoration(
                color: const Color(0x1410B981),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.music_note_rounded,
                    color: Color(0xFF34D399),
                    size: 16,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      selectedName != null && selectedName.isNotEmpty
                          ? selectedName
                          : widget.customMusic?.name ?? 'Soundtrack selected',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove soundtrack',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.disabled ? null : _clear,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white60,
                      size: 17,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Upload only music you own or have permission to use. Built-in Swipess sounds are original procedural loops.',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white38,
              fontSize: 8.5,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _audioMimeType(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.m4a')) return 'audio/mp4';
  if (lower.endsWith('.aac')) return 'audio/aac';
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.ogg')) return 'audio/ogg';
  return 'audio/mpeg';
}
