import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/studio/domain/cinematic_template.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;

/// Bakes a listing photo into a real 9:16 file so the chosen framing survives
/// upload, moderation, other devices and every gallery/card renderer.
///
/// PORTRAIT = full-bleed 9:16 crop around [focalPoint].
/// FIT      = entire source preserved inside a black 9:16 canvas.
Future<XFile> bakeListingPhotoFrame({
  required XFile source,
  required StudioPhotoFit fit,
  StudioFocalPoint focalPoint = const StudioFocalPoint(),
}) async {
  final sourceBytes = await source.readAsBytes();
  var decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    throw Exception('Could not read ${source.name}. Choose another photo.');
  }
  decoded = img.bakeOrientation(decoded);

  const targetWidth = 1080;
  const targetHeight = 1920;
  const targetRatio = targetWidth / targetHeight;

  late final img.Image framed;
  if (fit == StudioPhotoFit.portrait) {
    final sourceRatio = decoded.width / decoded.height;
    var cropX = 0;
    var cropY = 0;
    var cropWidth = decoded.width;
    var cropHeight = decoded.height;

    if (sourceRatio > targetRatio) {
      cropWidth = (decoded.height * targetRatio)
          .round()
          .clamp(1, decoded.width)
          .toInt();
      final maxX = decoded.width - cropWidth;
      cropX = (maxX * focalPoint.x.clamp(0.0, 1.0)).round();
    } else if (sourceRatio < targetRatio) {
      cropHeight = (decoded.width / targetRatio)
          .round()
          .clamp(1, decoded.height)
          .toInt();
      final maxY = decoded.height - cropHeight;
      cropY = (maxY * focalPoint.y.clamp(0.0, 1.0)).round();
    }

    final cropped = img.copyCrop(
      decoded,
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
    );
    framed = img.copyResize(
      cropped,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.cubic,
    );
  } else {
    final canvas = img.Image(width: targetWidth, height: targetHeight);
    img.fill(canvas, color: img.ColorRgb8(0, 0, 0));

    final sourceRatio = decoded.width / decoded.height;
    final contained = sourceRatio > targetRatio
        ? img.copyResize(
            decoded,
            width: targetWidth,
            interpolation: img.Interpolation.cubic,
          )
        : img.copyResize(
            decoded,
            height: targetHeight,
            interpolation: img.Interpolation.cubic,
          );
    final dstX = ((targetWidth - contained.width) / 2).round();
    final dstY = ((targetHeight - contained.height) / 2).round();
    img.compositeImage(canvas, contained, dstX: dstX, dstY: dstY);
    framed = canvas;
  }

  final encoded = Uint8List.fromList(img.encodeJpg(framed, quality: 92));
  final stem = source.name.replaceAll(RegExp(r'\.[^.]+$'), '');
  return XFile.fromData(
    encoded,
    mimeType: 'image/jpeg',
    name: '$stem-${fit.name}-9x16.jpg',
    length: encoded.lengthInBytes,
  );
}

/// Sequential on purpose: decoding several full-resolution phone photos at the
/// same time can spike memory on older iPhones/PWA browsers.
Future<List<XFile>> bakeListingPhotoFrames(
  List<XFile> photos, {
  Map<int, StudioPhotoFit> photoFits = const <int, StudioPhotoFit>{},
  Map<int, StudioFocalPoint> focalPoints = const <int, StudioFocalPoint>{},
}) async {
  final framed = <XFile>[];
  for (var i = 0; i < photos.length; i++) {
    framed.add(
      await bakeListingPhotoFrame(
        source: photos[i],
        fit: photoFits[i] ?? StudioPhotoFit.portrait,
        focalPoint: focalPoints[i] ?? const StudioFocalPoint(),
      ),
    );
  }
  return framed;
}

class ListingPhotoFramingScreen extends StatefulWidget {
  const ListingPhotoFramingScreen({
    super.key,
    required this.photos,
    this.title = 'PHOTO FRAMING',
  });

  final List<XFile> photos;
  final String title;

  @override
  State<ListingPhotoFramingScreen> createState() =>
      _ListingPhotoFramingScreenState();
}

class _ListingPhotoFramingScreenState extends State<ListingPhotoFramingScreen> {
  static const _pink = Color(0xFFFF2D6F);
  late final List<StudioPhotoFit> _fits;
  late final List<StudioFocalPoint> _focals;
  int _selected = 0;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fits = List<StudioPhotoFit>.filled(
      widget.photos.length,
      StudioPhotoFit.portrait,
      growable: false,
    );
    _focals = List<StudioFocalPoint>.filled(
      widget.photos.length,
      const StudioFocalPoint(),
      growable: false,
    );
  }

  void _setFit(StudioPhotoFit fit) {
    setState(() {
      _fits[_selected] = fit;
      _error = null;
    });
  }

  void _portraitAll() {
    setState(() {
      for (var i = 0; i < _fits.length; i++) {
        _fits[i] = StudioPhotoFit.portrait;
      }
      _error = null;
    });
  }

  void _setFocal({double? x, double? y}) {
    final current = _focals[_selected];
    setState(() {
      _focals[_selected] = StudioFocalPoint(
        x: x ?? current.x,
        y: y ?? current.y,
      );
    });
  }

  Future<void> _apply() async {
    if (_saving || widget.photos.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await bakeListingPhotoFrames(
        widget.photos,
        photoFits: <int, StudioPhotoFit>{
          for (var i = 0; i < _fits.length; i++) i: _fits[i],
        },
        focalPoints: <int, StudioFocalPoint>{
          for (var i = 0; i < _focals.length; i++) i: _focals[i],
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.photos[_selected];
    final fit = _fits[_selected];
    final focal = _focals[_selected];
    final portrait = fit == StudioPhotoFit.portrait;
    final alignment = Alignment(
      (focal.x.clamp(0.0, 1.0) * 2) - 1,
      (focal.y.clamp(0.0, 1.0) * 2) - 1,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                children: [
                  Text(
                    'MAKE EVERY PHOTO LOOK RIGHT',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Portrait is the default. Choose Fit only when you want the complete original photo visible. Your choice is baked into a real 9:16 listing photo.',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF9999A3),
                      fontSize: 11,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 330),
                      child: AspectRatio(
                        aspectRatio: 9 / 16,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: ColoredBox(
                            color: Colors.black,
                            child: FutureBuilder<Uint8List>(
                              future: file.readAsBytes(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      color: _pink,
                                    ),
                                  );
                                }
                                return Image.memory(
                                  snapshot.data!,
                                  fit: portrait ? BoxFit.cover : BoxFit.contain,
                                  alignment: portrait
                                      ? alignment
                                      : Alignment.center,
                                  gaplessPlayback: true,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 78,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.photos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final selected = index == _selected;
                        return GestureDetector(
                          onTap: _saving
                              ? null
                              : () => setState(() => _selected = index),
                          child: Container(
                            width: 58,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? _pink : Colors.white24,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: FutureBuilder<Uint8List>(
                              future: widget.photos[index].readAsBytes(),
                              builder: (context, snap) => snap.hasData
                                  ? Image.memory(
                                      snap.data!,
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                    )
                                  : const ColoredBox(
                                      color: Color(0xFF19191F),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF17171C),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PHOTO ${_selected + 1} · ${portrait ? 'PORTRAIT' : 'FIT'}',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              selected: portrait,
                              showCheckmark: false,
                              onSelected: _saving
                                  ? null
                                  : (_) => _setFit(StudioPhotoFit.portrait),
                              avatar: const Icon(
                                Icons.crop_portrait_rounded,
                                size: 18,
                              ),
                              label: const Text('PORTRAIT'),
                              selectedColor: _pink,
                              backgroundColor: const Color(0xFF24242B),
                              labelStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            ChoiceChip(
                              selected: !portrait,
                              showCheckmark: false,
                              onSelected: _saving
                                  ? null
                                  : (_) => _setFit(StudioPhotoFit.fit),
                              avatar: const Icon(
                                Icons.fit_screen_rounded,
                                size: 18,
                              ),
                              label: const Text('FIT'),
                              selectedColor: _pink,
                              backgroundColor: const Color(0xFF24242B),
                              labelStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _saving ? null : _portraitAll,
                              icon: const Icon(
                                Icons.crop_portrait_rounded,
                                size: 17,
                              ),
                              label: const Text('PORTRAIT ALL'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          portrait
                              ? 'Fills the complete 9:16 card. Move the focus if the source is landscape.'
                              : 'Keeps the entire original photo visible inside the 9:16 card.',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF9999A3),
                            fontSize: 9.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (portrait) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.swap_horiz_rounded,
                                color: Colors.white54,
                                size: 18,
                              ),
                              Expanded(
                                child: Slider(
                                  value: focal.x,
                                  min: 0,
                                  max: 1,
                                  activeColor: _pink,
                                  onChanged: _saving
                                      ? null
                                      : (value) => _setFocal(x: value),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.swap_vert_rounded,
                                color: Colors.white54,
                                size: 18,
                              ),
                              Expanded(
                                child: Slider(
                                  value: focal.y,
                                  min: 0,
                                  max: 1,
                                  activeColor: _pink,
                                  onChanged: _saving
                                      ? null
                                      : (value) => _setFocal(y: value),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFF87171),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _apply,
                  style: FilledButton.styleFrom(
                    backgroundColor: _pink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(
                    _saving ? 'CREATING 9:16 PHOTOS…' : 'USE THESE PHOTOS',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
