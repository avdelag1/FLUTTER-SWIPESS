import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/vap_id_card.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/vap_id_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

/// Dedicated identity-photo editor for the Virtual ID/PEARL card.
///
/// This photo is stored separately from the normal profile avatar.
class VapIdPhotoPicker extends ConsumerStatefulWidget {
  const VapIdPhotoPicker({super.key, required this.card});

  final VapIdCard card;

  @override
  ConsumerState<VapIdPhotoPicker> createState() => _VapIdPhotoPickerState();
}

class _VapIdPhotoPickerState extends ConsumerState<VapIdPhotoPicker> {
  bool _uploading = false;
  String? _error;

  Future<void> _chooseSource() async {
    AppHaptics.selection();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      backgroundColor: const Color(0xFF15171D),
      barrierColor: Colors.black.withAlpha(190),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'VIRTUAL ID PHOTO',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Use a clear photo for your ID card. This does not change your profile picture.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              _SourceButton(
                icon: Icons.photo_camera_rounded,
                title: 'TAKE PHOTO',
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              const SizedBox(height: 10),
              _SourceButton(
                icon: Icons.photo_library_rounded,
                title: 'CHOOSE FROM LIBRARY',
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;
    await _pickAndUpload(source);
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked == null || !mounted) return;

      setState(() {
        _uploading = true;
        _error = null;
      });
      AppHaptics.medium();
      await ref.read(vapIdProvider.notifier).setIdPhoto(picked);
      if (!mounted) return;
      setState(() => _uploading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = 'Could not update ID photo. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(vapIdProvider).value ?? widget.card;
    final photo = live.displayPhotoUrl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 64,
              height: 78,
              color: const Color(0xFF20232B),
              child: photo == null
                  ? const Icon(
                      Icons.badge_outlined,
                      color: Colors.white,
                      size: 28,
                    )
                  : Image.network(
                      photo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.badge_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ID PHOTO',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Separate from your profile photo',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: FilledButton.icon(
                    onPressed: _uploading ? null : _chooseSource,
                    icon: _uploading
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.camera_alt_rounded, size: 16),
                    label: Text(_uploading ? 'UPLOADING…' : 'CHANGE ID PHOTO'),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    _error!,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.redAccent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF20232B),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 21),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
