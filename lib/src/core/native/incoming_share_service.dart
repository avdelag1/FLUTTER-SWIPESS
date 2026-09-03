import 'dart:async';
import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class IncomingSharedMedia {
  const IncomingSharedMedia({required this.file, required this.mimeType});

  final XFile file;
  final String mimeType;

  bool get isImage {
    final lower = mimeType.toLowerCase();
    if (lower.startsWith('image/')) return true;
    final name = file.name.toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp') ||
        name.endsWith('.heic') ||
        name.endsWith('.heif');
  }

  bool get isVideo {
    final lower = mimeType.toLowerCase();
    if (lower.startsWith('video/')) return true;
    final name = file.name.toLowerCase();
    return name.endsWith('.mp4') ||
        name.endsWith('.mov') ||
        name.endsWith('.m4v') ||
        name.endsWith('.webm');
  }
}

class IncomingShareService {
  IncomingShareService._() {
    _installNativeHandler();
  }

  static final IncomingShareService instance = IncomingShareService._();
  static const MethodChannel _channel = MethodChannel('swipess/incoming_share');

  final StreamController<List<IncomingSharedMedia>> _events =
      StreamController<List<IncomingSharedMedia>>.broadcast();
  bool _nativeHandlerInstalled = false;

  Stream<List<IncomingSharedMedia>> get events {
    _installNativeHandler();
    return _events.stream;
  }

  void _installNativeHandler() {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        _nativeHandlerInstalled) {
      return;
    }
    _nativeHandlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'received') return;
      final media = _decodeNative(call.arguments);
      if (media.isNotEmpty) _events.add(media);
    });
  }

  Future<List<IncomingSharedMedia>> takeInitial() async {
    if (kIsWeb) return _takeWebShare();
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const <IncomingSharedMedia>[];
    }
    _installNativeHandler();
    try {
      final raw = await _channel.invokeMethod<Object?>('take');
      return _decodeNative(raw);
    } catch (error) {
      debugPrint('[IncomingShare] native take skipped: $error');
      return const <IncomingSharedMedia>[];
    }
  }

  List<IncomingSharedMedia> _decodeNative(Object? raw) {
    if (raw is! List) return const <IncomingSharedMedia>[];
    final out = <IncomingSharedMedia>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = item.map((key, value) => MapEntry(key.toString(), value));
      final path = map['path']?.toString().trim() ?? '';
      if (path.isEmpty) continue;
      final name = map['name']?.toString().trim();
      final mimeType = map['mimeType']?.toString().trim() ?? '';
      final size = map['size'];
      out.add(
        IncomingSharedMedia(
          file: XFile(
            path,
            name: name == null || name.isEmpty ? null : name,
            mimeType: mimeType.isEmpty ? null : mimeType,
            length: size is num ? size.toInt() : null,
          ),
          mimeType: mimeType,
        ),
      );
    }
    return out;
  }

  Future<List<IncomingSharedMedia>> _takeWebShare() async {
    final session = Uri.base.queryParameters['share_session']?.trim() ?? '';
    if (session.isEmpty) return const <IncomingSharedMedia>[];

    try {
      final encoded = Uri.encodeComponent(session);
      final manifestUri = Uri.base.resolve(
        '/__swipess_share/$encoded/manifest.json',
      );
      final manifestResponse = await http
          .get(manifestUri, headers: const {'Cache-Control': 'no-store'})
          .timeout(const Duration(seconds: 8));
      if (manifestResponse.statusCode != 200) {
        return const <IncomingSharedMedia>[];
      }

      final decoded = jsonDecode(utf8.decode(manifestResponse.bodyBytes));
      if (decoded is! Map || decoded['files'] is! List) {
        return const <IncomingSharedMedia>[];
      }

      final out = <IncomingSharedMedia>[];
      for (final raw in (decoded['files'] as List).take(32)) {
        if (raw is! Map) continue;
        final item = raw.map((key, value) => MapEntry(key.toString(), value));
        final href = item['url']?.toString().trim() ?? '';
        if (href.isEmpty) continue;
        final response = await http
            .get(
              Uri.base.resolve(href),
              headers: const {'Cache-Control': 'no-store'},
            )
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) continue;
        final mimeType = item['type']?.toString().trim() ?? '';
        final name = item['name']?.toString().trim();
        final safeName = name == null || name.isEmpty ? 'shared-media' : name;
        out.add(
          IncomingSharedMedia(
            file: XFile.fromData(
              response.bodyBytes,
              name: safeName,
              mimeType: mimeType.isEmpty ? null : mimeType,
            ),
            mimeType: mimeType,
          ),
        );
      }
      return out;
    } catch (error) {
      debugPrint('[IncomingShare] web share skipped: $error');
      return const <IncomingSharedMedia>[];
    }
  }
}
