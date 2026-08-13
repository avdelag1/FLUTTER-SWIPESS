import 'dart:ui' as ui;

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';

/// Bakes a live ColorFilter into the captured JPEG/PNG so listing uploads
/// match Cap camera (`applyFilterToCanvas`), not just the on-screen preview.
Future<XFile> bakeCameraFilter({
  required XFile source,
  required ColorFilter filter,
}) async {
  final bytes = await source.readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1920);
  final frame = await codec.getNextFrame();
  final src = frame.image;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImage(src, Offset.zero, Paint()..colorFilter = filter);
  final picture = recorder.endRecording();
  final out = await picture.toImage(src.width, src.height);
  final data = await out.toByteData(format: ui.ImageByteFormat.png);
  src.dispose();
  out.dispose();
  picture.dispose();
  if (data == null) return source;
  final stem = source.name.replaceAll(RegExp(r'\.[^.]+$'), '');
  return XFile.fromData(
    data.buffer.asUint8List(),
    mimeType: 'image/png',
    name: '$stem-filtered.png',
  );
}
