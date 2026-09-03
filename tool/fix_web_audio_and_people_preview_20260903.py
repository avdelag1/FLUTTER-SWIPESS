from pathlib import Path

# ---------------------------------------------------------------------------
# Modern WebAudio: dart:web_audio was removed from Dart 3.13 and AudioContext
# is not exposed from dart:html. Keep the mature dart:html video/canvas code,
# but use package:web for WebAudio and bridge its MediaStream track into the
# legacy capture stream through JSObject.fromInteropObject.
# ---------------------------------------------------------------------------
path = Path('lib/src/features/camera/data/video_recut_v2_html.dart')
text = path.read_text()

old_imports = """import 'dart:async';\n// ignore: deprecated_member_use, avoid_web_libraries_in_flutter\nimport 'dart:html' as html;\nimport 'dart:math' as math;\nimport 'dart:typed_data';\n\nimport 'package:image_picker/image_picker.dart';\n"""
new_imports = """import 'dart:async';\n// ignore: deprecated_member_use, avoid_web_libraries_in_flutter\nimport 'dart:html' as html;\nimport 'dart:js_interop';\nimport 'dart:js_interop_unsafe';\nimport 'dart:math' as math;\nimport 'dart:typed_data';\n\nimport 'package:image_picker/image_picker.dart';\nimport 'package:web/web.dart' as web;\n"""
assert old_imports in text
text = text.replace(old_imports, new_imports, 1)
text = text.replace('html.AudioContext? audioContext;', 'web.AudioContext? audioContext;', 1)
text = text.replace('html.AudioBufferSourceNode? musicSource;', 'web.AudioBufferSourceNode? musicSource;', 1)
text = text.replace('audioContext = html.AudioContext();', 'audioContext = web.AudioContext();', 1)
text = text.replace('await audioContext.resume();', 'await audioContext.resume().toDart;', 1)

old_decode = """        final audioBuffer = await audioContext.decodeAudioData(\n          Uint8List.fromList(musicBytes).buffer,\n        );\n        final duration = (audioBuffer.duration ?? 0).toDouble();\n"""
new_decode = """        final audioBuffer = await audioContext.decodeAudioData(\n          Uint8List.fromList(musicBytes).buffer.toJS,\n        ).toDart;\n        final duration = audioBuffer.duration.toDouble();\n"""
assert old_decode in text
text = text.replace(old_decode, new_decode, 1)

old_connect = """          musicSource.connectNode(destination);\n          final mixedStream = destination.stream;\n          if (mixedStream != null) {\n            for (final track in mixedStream.getAudioTracks()) {\n              stream.addTrack(track);\n            }\n          }\n"""
new_connect = """          musicSource.connect(destination);\n          final mixedStream = destination.stream;\n          final captureStreamJs = JSObject.fromInteropObject(stream);\n          for (final track in mixedStream.getAudioTracks().toDart) {\n            // `stream` is still a dart:html MediaStream. Convert the legacy\n            // wrapper to its underlying JS object so a package:web track can\n            // be attached without unsafe Dart casts between the two bindings.\n            captureStreamJs.callMethod<JSAny?>('addTrack'.toJS, track);\n          }\n"""
assert old_connect in text
text = text.replace(old_connect, new_connect, 1)

# There is a second resume during actual export playback.
text = text.replace('await audioContext.resume();', 'await audioContext.resume().toDart;', 1)
text = text.replace(
    "final bufferDuration = (musicSource.buffer?.duration ?? 0).toDouble();",
    "final bufferDuration = (musicSource.buffer?.duration ?? 0).toDouble();",
    1,
)
text = text.replace(
    "musicSource.stop((audioContext.currentTime ?? 0) + cutDuration + .15);",
    "musicSource.stop(audioContext.currentTime + cutDuration + .15);",
    1,
)
text = text.replace('await audioContext?.close();', 'await audioContext?.close().toDart;', 1)
path.write_text(text)

# Declare package:web explicitly; it was already locked transitively at 1.1.1.
pubspec = Path('pubspec.yaml')
text = pubspec.read_text()
if '  web: ^1.1.1\n' not in text:
    anchor = '  http: ^1.2.2\n'
    assert anchor in text
    text = text.replace(anchor, anchor + '  web: ^1.1.1\n', 1)
pubspec.write_text(text)

lock = Path('pubspec.lock')
text = lock.read_text()
old = '''  web:\n    dependency: transitive\n    description:\n      name: web\n'''
new = '''  web:\n    dependency: "direct main"\n    description:\n      name: web\n'''
if old in text:
    text = text.replace(old, new, 1)
lock.write_text(text)

# ---------------------------------------------------------------------------
# Profile discovery: keep the image list growable before using vap_avatar as a
# fallback, otherwise an empty fixed-length list throws at runtime.
# ---------------------------------------------------------------------------
path = Path('lib/src/features/seekers/presentation/screens/people_intent_discovery_screen.dart')
text = path.read_text()
old = """            .where((e) => e.isNotEmpty)\n            .toList(growable: false)\n        : <String>[];\n    final avatar = row['vap_avatar']?.toString().trim() ?? '';\n    if (images.isEmpty && avatar.isNotEmpty) images.add(avatar);\n"""
new = """            .where((e) => e.isNotEmpty)\n            .toList()\n        : <String>[];\n    final avatar = row['vap_avatar']?.toString().trim() ?? '';\n    if (images.isEmpty && avatar.isNotEmpty) images.add(avatar);\n"""
assert old in text
text = text.replace(old, new, 1)
path.write_text(text)
