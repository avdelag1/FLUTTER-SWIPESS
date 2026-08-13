import 'package:image_picker/image_picker.dart';

/// Platforms without recut — return the original file (Cap Safari fallback).
Future<XFile> recutVideoWindow({
  required XFile source,
  required double start,
  required double end,
}) async {
  return source;
}
