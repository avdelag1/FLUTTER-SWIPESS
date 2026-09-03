import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart' as http;

const int _maxRemoteMediaBytes = 100 * 1024 * 1024;

/// Fetches a published listing video into browser memory so the web video
/// editor receives an XFile with actual bytes instead of a remote URL string.
Future<XFile> materializeRemoteMedia(
  String url, {
  String suggestedName = 'listing-video.mp4',
}) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme) {
    throw const FormatException('Invalid media URL.');
  }

  final response = await http.get(uri).timeout(const Duration(seconds: 30));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError(
      'Could not load the current video (${response.statusCode}).',
    );
  }
  if (response.bodyBytes.isEmpty) {
    throw StateError('The current video is empty.');
  }
  if (response.bodyBytes.length > _maxRemoteMediaBytes) {
    throw StateError(
      'The current video is too large to re-edit in the browser.',
    );
  }

  final mime = response.headers['content-type']?.split(';').first.trim();
  final name = _resolvedName(uri, suggestedName, mime);
  return XFile.fromData(
    response.bodyBytes,
    name: name,
    mimeType: mime?.startsWith('video/') == true ? mime : 'video/mp4',
    length: response.bodyBytes.length,
  );
}

String _resolvedName(Uri uri, String fallback, String? mime) {
  var raw = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
  raw = Uri.decodeComponent(raw).trim();
  if (raw.isEmpty || !raw.contains('.')) raw = fallback.trim();
  if (raw.isEmpty) raw = 'listing-video.mp4';

  final safe = raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  if (safe.contains('.')) return safe;
  if (mime == 'video/quicktime') return '$safe.mov';
  if (mime == 'video/webm') return '$safe.webm';
  return '$safe.mp4';
}
