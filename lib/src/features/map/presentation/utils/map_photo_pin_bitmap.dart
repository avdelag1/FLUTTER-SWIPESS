import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Builds circular Instagram-style map pin bitmaps for native Mapbox annotations.
abstract final class MapPhotoPinBitmap {
  static final _cache = <String, Uint8List>{};

  static Future<Uint8List> build({
    required String cacheKey,
    String? imageUrl,
    required Color ringColor,
    required IconData fallbackIcon,
    bool selected = false,
    double size = 168,
  }) async {
    final key =
        '$cacheKey|${imageUrl ?? ''}|${ringColor.toARGB32()}|$selected|$size';
    final cached = _cache[key];
    if (cached != null) return cached;

    final bytes = await _render(
      imageUrl: imageUrl,
      ringColor: ringColor,
      fallbackIcon: fallbackIcon,
      selected: selected,
      size: size,
    );
    _cache[key] = bytes;
    if (_cache.length > 140) {
      _cache.remove(_cache.keys.first);
    }
    return bytes;
  }

  static Future<Uint8List> _render({
    String? imageUrl,
    required Color ringColor,
    required IconData fallbackIcon,
    required bool selected,
    required double size,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final center = ui.Offset(size / 2, size / 2 - 4);
    final outer = size * 0.34;
    final photo = outer - (selected ? 5 : 4);

    canvas.drawCircle(
      center.translate(0, 6),
      outer + 4,
      ui.Paint()
        ..color = ringColor.withAlpha(selected ? 72 : 48)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10),
    );
    canvas.drawCircle(
      center,
      outer + 2,
      ui.Paint()..color = selected ? ringColor : Colors.white,
    );
    canvas.drawCircle(center, outer, ui.Paint()..color = Colors.white);

    final photoPaint = ui.Paint()..isAntiAlias = true;
    final clipPath = ui.Path()..addOval(
      ui.Rect.fromCircle(center: center, radius: photo),
    );
    canvas.save();
    canvas.clipPath(clipPath);

    final image = await _loadImage(imageUrl);
    if (image != null) {
      final src = _coverSrc(image.width.toDouble(), image.height.toDouble(), photo * 2);
      canvas.drawImageRect(
        image,
        src,
        ui.Rect.fromCircle(center: center, radius: photo),
        photoPaint,
      );
    } else {
      canvas.drawCircle(center, photo, ui.Paint()..color = ringColor.withAlpha(36));
      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(fallbackIcon.codePoint),
          style: TextStyle(
            color: ringColor,
            fontSize: photo * 0.95,
            fontWeight: FontWeight.w600,
            fontFamily: fallbackIcon.fontFamily,
            package: fallbackIcon.fontPackage,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        ui.Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
      );
    }
    canvas.restore();

    final picture = recorder.endRecording();
    final raster = await picture.toImage(size.toInt(), size.toInt());
    return (await raster.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();
  }

  static ui.Rect _coverSrc(double w, double h, double side) {
    if (w <= 0 || h <= 0) return const ui.Rect.fromLTWH(0, 0, 1, 1);
    final scale = (side / w).clamp(side / h, double.infinity);
    final sw = side / scale;
    final sh = side / scale;
    return ui.Rect.fromLTWH((w - sw) / 2, (h - sh) / 2, sw, sh);
  }

  static Future<ui.Image?> _loadImage(String? url) async {
    final raw = url?.trim();
    if (raw == null || raw.isEmpty) return null;
    try {
      final response = await http
          .get(Uri.parse(raw))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return null;
      final codec = await ui.instantiateImageCodec(response.bodyBytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }
}
