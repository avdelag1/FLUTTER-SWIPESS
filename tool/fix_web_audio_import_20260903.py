from pathlib import Path

path = Path('lib/src/features/camera/data/video_recut_v2_html.dart')
text = path.read_text()

text = text.replace("// ignore: deprecated_member_use\nimport 'dart:web_audio' as web_audio;\n", "")
text = text.replace('web_audio.AudioContext', 'html.AudioContext')
text = text.replace('web_audio.AudioBufferSourceNode', 'html.AudioBufferSourceNode')

path.write_text(text)
