import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/camera/presentation/screens/profile_camera_screen.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_profiles_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/profile_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _cityController;
  late final TextEditingController _roommateBudgetController;
  bool _isSaving = false;
  bool _enhancing = false;
  bool _roommateAvailable = false;
  bool _loadingRoommatePrefs = true;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentProfileProvider).value;
    _nameController = TextEditingController(text: profile?.name ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
    _cityController = TextEditingController(text: profile?.city ?? '');
    _roommateBudgetController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(chromeVisibilityProvider.notifier).hide();
      _loadRoommatePreferences();
    });
  }

  Future<void> _loadRoommatePreferences() async {
    final prefs = await ref
        .read(profileRepositoryProvider)
        .fetchRoommatePreferences();
    if (!mounted) return;
    setState(() {
      _roommateAvailable = prefs.available;
      _roommateBudgetController.text = prefs.monthlyBudget == null
          ? ''
          : prefs.monthlyBudget!.toStringAsFixed(0);
      _loadingRoommatePrefs = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _roommateBudgetController.dispose();
    ref.read(chromeVisibilityProvider.notifier).show();
    super.dispose();
  }

  Future<void> _enhanceBio() async {
    if (_enhancing) return;
    final raw = _bioController.text.trim();
    if (raw.length < 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Write a short bio first')));
      return;
    }
    setState(() => _enhancing = true);
    AppHaptics.light();
    try {
      final polished = await ref
          .read(aiEdgeRepositoryProvider)
          .enhanceText(text: raw, type: 'profile');
      if (!mounted) return;
      setState(() => _enhancing = false);
      if (polished == null || polished.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI could not enhance — please try again')),
        );
        return;
      }
      _bioController.text = polished;
      AppHaptics.medium();
    } catch (_) {
      if (!mounted) return;
      setState(() => _enhancing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI enhance failed — check your connection and try again')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;
    final parsedBudget = double.tryParse(
      _roommateBudgetController.text.trim().replaceAll(',', ''),
    );
    if (_roommateAvailable &&
        _roommateBudgetController.text.trim().isNotEmpty &&
        (parsedBudget == null || parsedBudget < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid monthly roommate budget')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      await repo.updateProfile(
        displayName: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        city: _cityController.text.trim(),
      );
      await repo.updateRoommatePreferences(
        available: _roommateAvailable,
        monthlyBudget: parsedBudget,
      );
      ref.invalidate(currentProfileProvider);
      ref.invalidate(mapProfilesProvider);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    final avatarUrl = profile?.avatarUrl;

    return Scaffold(
      backgroundColor: AppTheme.dashBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: Colors.black.withAlpha(170),
              elevation: 0,
              automaticallyImplyLeading: false,
              leading: IconButton(
                tooltip: 'Back',
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => context.pop(),
              ),
              title: Text(
                'EDIT IDENTITY',
                style: AppTheme.displayItalic.copyWith(fontSize: 18),
              ),
              actions: [
                if (_isSaving)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppTheme.brandPrimary,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else
                  TextButton(
                    onPressed: _saveProfile,
                    child: Text(
                      'Save',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.brandPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: Colors.white10,
                      backgroundImage: avatarUrl == null
                          ? null
                          : NetworkImage(avatarUrl),
                      child: avatarUrl == null
                          ? const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 46,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Material(
                        color: AppTheme.brandPrimary,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Change profile photo',
                          onPressed: () async {
                            final url = await Navigator.of(context)
                                .push<String>(
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
                          icon: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const _Label('DISPLAY NAME'),
              const SizedBox(height: 8),
              GlassTextField(
                controller: _nameController,
                hint: 'Display name',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 18),
              const _Label('CITY'),
              const SizedBox(height: 8),
              GlassTextField(
                controller: _cityController,
                hint: 'City',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const _Label('BIO'),
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
                        : const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: const Text('AI ENHANCE'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GlassTextField(
                controller: _bioController,
                hint: 'Bio',
                icon: Icons.notes_rounded,
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(8),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withAlpha(32)),
                ),
                child: _loadingRoommatePrefs
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.brandPrimary,
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.bedroom_parent_outlined,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ROOMMATE MODE',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: .8,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Turn this on only when you want to appear in roommate discovery.',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: _roommateAvailable,
                                onChanged: (value) {
                                  AppHaptics.selection();
                                  setState(() => _roommateAvailable = value);
                                },
                              ),
                            ],
                          ),
                          if (_roommateAvailable) ...[
                            const SizedBox(height: 16),
                            const _Label('MONTHLY BUDGET'),
                            const SizedBox(height: 8),
                            GlassTextField(
                              controller: _roommateBudgetController,
                              hint: 'Example: 1200',
                              icon: Icons.payments_outlined,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 28),
              BrandPrimaryButton(
                label: _isSaving ? 'Saving…' : 'Save profile',
                loading: _isSaving,
                onPressed: _isSaving ? null : _saveProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.4,
      ),
    );
  }
}
