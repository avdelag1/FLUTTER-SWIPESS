import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/vap_id_card.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/vap_id_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/vap_id_photo_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full route-level editor for the Virtual ID opened from the navigation-bar
/// PEARL card. Keeping the editor inside the router avoids stacking a Material
/// bottom sheet behind the root PEARL overlay on web.
class VapIdEditScreen extends ConsumerStatefulWidget {
  const VapIdEditScreen({super.key});

  @override
  ConsumerState<VapIdEditScreen> createState() => _VapIdEditScreenState();
}

class _VapIdEditScreenState extends ConsumerState<VapIdEditScreen> {
  final _name = TextEditingController();
  final _occupation = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController();
  final _bio = TextEditingController();
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _occupation.dispose();
    _city.dispose();
    _country.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _seed(VapIdCard card) {
    if (_seeded) return;
    _seeded = true;
    _name.text = card.name ?? '';
    _occupation.text = card.occupation ?? '';
    _city.text = card.city ?? '';
    _country.text = card.country ?? '';
    _bio.text = card.bio ?? '';
  }

  Future<void> _save(VapIdCard card) async {
    if (_saving) return;
    setState(() => _saving = true);
    AppHaptics.medium();
    try {
      final latest = ref.read(vapIdProvider).value ?? card;
      await ref
          .read(vapIdProvider.notifier)
          .save(
            latest.copyWith(
              name: _name.text.trim(),
              occupation: _occupation.text.trim(),
              city: _city.text.trim(),
              country: _country.text.trim(),
              bio: _bio.text.trim(),
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Virtual ID updated')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(vapIdProvider);
    final userId = ref.watch(currentUserProvider)?.id ?? 'resident';
    final ink = MatteSurface.ink(context);

    return Scaffold(
      backgroundColor: MatteSurface.canvas(context),
      body: AmbientPageBackground(
        fill: true,
        child: SafeArea(
          child: async.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: () => ref.read(vapIdProvider.notifier).refresh(),
                child: const Text('Could not load Virtual ID — retry'),
              ),
            ),
            data: (card) {
              final data = card ?? VapIdCard(userId: userId);
              _seed(data);
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 44),
                children: [
                  Row(
                    children: [
                      const CapBackButton(
                        fallbackPath: AppPaths.clientDashboard,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PEARL / VIRTUAL ID',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.8,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'EDIT YOUR ID',
                              style: AppTheme.displayItalic.copyWith(
                                color: ink,
                                fontSize: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Documents',
                        onPressed: () => context.push(AppPaths.documents),
                        icon: const Icon(
                          Icons.folder_copy_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'IDENTITY PHOTO',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  VapIdPhotoPicker(card: data),
                  const SizedBox(height: 22),
                  Text(
                    'CARD INFORMATION',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassTextField(controller: _name, hint: 'Name'),
                  const SizedBox(height: 10),
                  GlassTextField(controller: _occupation, hint: 'Occupation'),
                  const SizedBox(height: 10),
                  GlassTextField(controller: _city, hint: 'City'),
                  const SizedBox(height: 10),
                  GlassTextField(controller: _country, hint: 'Country'),
                  const SizedBox(height: 10),
                  GlassTextField(controller: _bio, hint: 'Bio', maxLines: 3),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : () => _save(data),
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(_saving ? 'SAVING…' : 'SAVE VIRTUAL ID'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(AppPaths.documents),
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('UPLOAD / MANAGE DOCUMENTS'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your ID photo is separate from your normal profile photo. Documents remain private and are used only for verification.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: MatteSurface.muted(context),
                      fontSize: 11,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
