import 'package:image_picker/image_picker.dart';

/// The editor returns a rendered file only after an explicit trim/crop/audio
/// edit. For an untouched phone video, upload the exact selected source and
/// let the server create one shared delivery rendition. Re-exporting every
/// iOS/Android upload here was the last difference from Events: it forced an
/// unwanted 9:16 crop and could alter motion before the backend saw the file.
Future<XFile> optimizeVideoForUpload(XFile source) async => source;
