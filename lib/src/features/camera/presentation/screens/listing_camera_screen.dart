import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/camera/data/bake_camera_filter.dart';
import 'package:flutter_swipes/src/features/camera/presentation/widgets/camera_filters_strip.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

/// Cap OwnerListingCamera — capture / gallery multi-shot for listings.
class ListingCameraScreen extends StatefulWidget {
  const ListingCameraScreen({
    super.key,
    this.maxPhotos = 30,
    this.existingCount = 0,
    this.title = 'LISTING CAMERA',
  });

  final int maxPhotos;
  final int existingCount;
  final String title;

  @override
  State<ListingCameraScreen> createState() => _ListingCameraScreenState();
}

class _ListingCameraScreenState extends State<ListingCameraScreen> {
  final _shots = <XFile>[];
  bool _busy = false;
  CapCameraFilter _filter = CapCameraFilter.none;

  int get _remaining =>
      (widget.maxPhotos - widget.existingCount - _shots.length).clamp(0, 99);

  Future<void> _capture() async {
    if (_remaining <= 0 || _busy) return;
    setState(() => _busy = true);
    AppHaptics.medium();
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file != null) setState(() => _shots.add(file));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _gallery() async {
    if (_remaining <= 0 || _busy) return;
    setState(() => _busy = true);
    try {
      final files = await ImagePicker().pickMultiImage(
        imageQuality: 88,
        limit: _remaining,
      );
      if (files.isNotEmpty) {
        setState(() => _shots.addAll(files.take(_remaining)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _done() async {
    if (_shots.isEmpty) return;
    if (_filter == CapCameraFilter.none) {
      Navigator.pop(context, List<XFile>.from(_shots));
      return;
    }
    setState(() => _busy = true);
    try {
      final baked = <XFile>[];
      for (final shot in _shots) {
        baked.add(
          await bakeCameraFilter(source: shot, filter: _filter.colorFilter),
        );
      }
      if (mounted) Navigator.pop(context, baked);
    } catch (_) {
      if (mounted) Navigator.pop(context, List<XFile>.from(_shots));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    child: Column(
                      children: [
                        Text(
                          widget.title,
                          style: AppTheme.displayItalic.copyWith(fontSize: 18),
                        ),
                        Text(
                          '${_shots.length} captured · $_remaining left',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _shots.isEmpty || _busy ? null : _done,
                    child: const Text('DONE'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _shots.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_camera_rounded,
                              size: 64, color: Colors.transparent),
                          const SizedBox(height: 16),
                          Text(
                            'Shoot listing photos like Cap camera',
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.white54),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _shots.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemBuilder: (context, i) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: FutureBuilder(
                                future: _shots[i].readAsBytes(),
                                builder: (context, snap) {
                                  if (!snap.hasData) {
                                    return const ColoredBox(
                                        color: Color(0xFF16161C));
                                  }
                                  final image = Image.memory(
                                    snap.data!,
                                    fit: BoxFit.cover,
                                  );
                                  if (_filter == CapCameraFilter.none) {
                                    return image;
                                  }
                                  return ColorFiltered(
                                    colorFilter: _filter.colorFilter,
                                    child: image,
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _shots.removeAt(i)),
                                child: const CircleAvatar(
                                  radius: 12,
                                  child: Icon(Icons.close,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            CameraFiltersStrip(
              selected: _filter,
              onSelected: (f) => setState(() => _filter = f),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _gallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _busy || _remaining <= 0 ? null : _capture,
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: Text(_busy ? '…' : 'CAPTURE'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
