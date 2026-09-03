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
    int extraCount = 0,
    IconData? statusIcon,
  }) async {
    final key =
        '$cacheKey|${imageUrl ?? ''}|${ringColor.toARGB32()}|$selected|$size|$extraCount|${statusIcon?.codePoint}';
    final cached = _cache[key];
    if (cached != null) return cached;

    final bytes = await _render(
      imageUrl: imageUrl,
      ringColor: ringColor,
      fallbackIcon: fallbackIcon,
      selected: selected,
      size: size,
      extraCount: extraCount,
      statusIcon: statusIcon,
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
    int extraCount = 0,
    IconData? statusIcon,
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

    if (statusIcon != null) {
      final badgeR = size * 0.11;
      final badgeCenter = ui.Offset(center.dx + photo * 0.72, center.dy - photo * 0.72);
      canvas.drawCircle(badgeCenter, badgeR + 2, ui.Paint()..color = Colors.white);
      canvas.drawCircle(badgeCenter, badgeR, ui.Paint()..color = ringColor);
      final statusPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(statusIcon.codePoint),
          style: TextStyle(
            color: Colors.white,
            fontSize: badgeR * 1.2,
            fontFamily: statusIcon.fontFamily,
            package: statusIcon.fontPackage,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      statusPainter.paint(
        canvas,
        ui.Offset(
          badgeCenter.dx - statusPainter.width / 2,
          badgeCenter.dy - statusPainter.height / 2,
        ),
      );
    }

    if (extraCount > 0) {
      final label = '+$extraCount more';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final pillW = textPainter.width + 20;
      final pillH = 26.0;
      final pillRect = ui.RRect.fromRectAndRadius(
        ui.Rect.fromCenter(
          center: ui.Offset(center.dx, center.dy + outer + 18),
          width: pillW,
          height: pillH,
        ),
        const ui.Radius.circular(99),
      );
      canvas.drawRRect(pillRect, ui.Paint()..color = const Color(0xE6111318));
      textPainter.paint(
        canvas,
        ui.Offset(
          center.dx - textPainter.width / 2,
          center.dy + outer + 18 - textPainter.height / 2,
        ),
      );
    }

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
