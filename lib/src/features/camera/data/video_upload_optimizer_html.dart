import 'package:image_picker/image_picker.dart';

/// Browser/PWA uploads must follow the same path as the Admin Events uploader:
/// upload the exact selected file to Supabase Storage and let the backend create
/// any delivery renditions afterward.
///
/// Do NOT run the selected file through canvas.captureStream/MediaRecorder here.
/// That browser-side export was forcing a 30 fps capture before the file even
/// reached Supabase, changing motion cadence and making listing video previews
/// look slow/juddery compared with Events.
Future<XFile> optimizeVideoForUpload(XFile source) async => source;
