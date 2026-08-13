import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/camera/presentation/screens/profile_camera_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/profile_providers.dart';
import 'package:google_fonts/google_fonts.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _cityController;
  bool _isSaving = false;
  bool _enhancing = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentProfileProvider).value;
    _nameController = TextEditingController(text: profile?.displayName ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
    _cityController = TextEditingController(text: profile?.city ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _enhanceBio() async {
    if (_enhancing) return;
    final raw = _bioController.text.trim();
    if (raw.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write a short bio first')),
      );
      return;
    }
    setState(() => _enhancing = true);
    HapticFeedback.lightImpact();
    final polished = await ref.read(aiEdgeRepositoryProvider).enhanceText(
          text: raw,
          type: 'profile',
        );
    if (!mounted) return;
    setState(() => _enhancing = false);
    if (polished == null || polished.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not enhance — try again')),
      );
      return;
    }
    setState(() => _bioController.text = polished);
  }

  Future<void> _saveProfile() async {
    setState(() { _isSaving = true; });
    try {
      final repo = ref.read(profileRepositoryProvider);
      await repo.updateProfile(
        displayName: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        city: _cityController.text.trim(),
      );
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isSaving = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    final avatarUrl = profile?.avatarUrl ??
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb';
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => context.pop(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'EDIT IDENTITY',
                  style: AppTheme.displayItalic.copyWith(fontSize: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundImage: NetworkImage(avatarUrl),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () async {
                      final url = await Navigator.of(context).push<String>(
                        MaterialPageRoute(
                          builder: (_) => const ProfileCameraScreen(
                            mode: ProfileCameraMode.selfie,
                          ),
                        ),
                      );
                      if (url != null) {
                        ref.invalidate(currentProfileProvider);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppTheme.brandPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'DISPLAY NAME',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          GlassTextField(
            controller: _nameController,
            hint: 'Display name',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 18),
          Text(
            'CITY',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          GlassTextField(
            controller: _cityController,
            hint: 'City',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'BIO',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _enhancing ? null : _enhanceBio,
                icon: _enhancing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.brandPrimary,
                        ),
                      )
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(
                  'AI ENHANCE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.transparent),
          ),
          const SizedBox(height: 28),
          BrandPrimaryButton(
            label: _isSaving ? 'Saving…' : 'Save profile',
            loading: _isSaving,
            onPressed: _isSaving ? null : _saveProfile,
          ),
        ],
      ),
    );
  }
}
