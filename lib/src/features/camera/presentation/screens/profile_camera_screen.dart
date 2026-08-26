import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ProfileCameraMode { selfie, owner }

/// Cap ClientSelfieCamera / OwnerProfileCamera — capture + upload avatar.
class ProfileCameraScreen extends StatefulWidget {
  const ProfileCameraScreen({super.key, this.mode = ProfileCameraMode.selfie});

  final ProfileCameraMode mode;

  @override
  State<ProfileCameraScreen> createState() => _ProfileCameraScreenState();
}

class _ProfileCameraScreenState extends State<ProfileCameraScreen> {
  XFile? _shot;
  bool _busy = false;
  String? _error;

  Future<void> _capture() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    AppHaptics.medium();
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        preferredCameraDevice: widget.mode == ProfileCameraMode.selfie
            ? CameraDevice.front
            : CameraDevice.rear,
      );
      if (file != null) setState(() => _shot = file);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _gallery() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (file != null) setState(() => _shot = file);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    final shot = _shot;
    if (shot == null || _busy) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _error = 'Sign in required');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await shot.readAsBytes();
      final path = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage
          .from('profile-images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      final url = Supabase.instance.client.storage
          .from('profile-images')
          .getPublicUrl(path);

      // Best-effort Cap tables.
      try {
        await Supabase.instance.client.from('profiles').upsert({
          'user_id': user.id,
          'avatar_url': url,
        });
      } catch (_) {}
      try {
        await Supabase.instance.client
            .from('client_profiles')
            .update({
              'profile_images': [url],
            })
            .eq('user_id', user.id);
      } catch (_) {}
      try {
        await Supabase.instance.client
            .from('owner_profiles')
            .update({
              'profile_images': [url],
            })
            .eq('user_id', user.id);
      } catch (_) {}
      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'avatar_url': url}),
        );
      } catch (_) {}

      if (!mounted) return;
      Navigator.pop(context, url);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.mode == ProfileCameraMode.selfie
        ? 'SELFIE CAMERA'
        : 'OWNER CAMERA';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTheme.displayItalic.copyWith(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF16161C),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white24),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _shot == null
                        ? const Center(
                            child: Icon(
                              Icons.person_rounded,
                              color: Colors.white24,
                              size: 72,
                            ),
                          )
                        : FutureBuilder(
                            future: _shot!.readAsBytes(),
                            builder: (context, snap) {
                              if (!snap.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                );
                              }
                              return Image.memory(
                                snap.data!,
                                fit: BoxFit.cover,
                              );
                            },
                          ),
                  ),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFF87171)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _gallery,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Gallery'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _capture,
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text('Capture'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _shot == null || _busy ? null : _upload,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _busy ? 'Uploading…' : 'USE PHOTO',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
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
