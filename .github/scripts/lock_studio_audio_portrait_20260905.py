from pathlib import Path

renderer = Path('api/studio-render-node.js')
s = renderer.read_text()

needle = """  await runFfmpeg(args);\n}\n\nasync function makePoster(videoPath, posterPath) {"""
replacement = """  await runFfmpeg(args);\n}\n\nasync function verifyOutputStreams(outputPath) {\n  // Do not publish a Studio MP4 unless FFmpeg can explicitly map BOTH the\n  // rendered video stream and the baked soundtrack stream. A missing audio\n  // stream makes this command fail, which fails the job before Storage upload.\n  await runFfmpeg(\n    [\n      '-hide_banner',\n      '-loglevel',\n      'error',\n      '-i',\n      outputPath,\n      '-map',\n      '0:v:0',\n      '-map',\n      '0:a:0',\n      '-c',\n      'copy',\n      '-f',\n      'null',\n      '-',\n    ],\n    45000,\n  );\n}\n\nasync function makePoster(videoPath, posterPath) {"""
if 'async function verifyOutputStreams(outputPath)' not in s:
    if needle not in s:
        raise SystemExit('renderer compose/makePoster anchor not found')
    s = s.replace(needle, replacement, 1)

needle2 = """    await composeShots(shotPaths, manifest.shots, audioPath, outputPath);\n    await makePoster(outputPath, posterPath);"""
replacement2 = """    await composeShots(shotPaths, manifest.shots, audioPath, outputPath);\n    await verifyOutputStreams(outputPath);\n    await makePoster(outputPath, posterPath);"""
if 'await verifyOutputStreams(outputPath);' not in s:
    if needle2 not in s:
        raise SystemExit('renderer output verification anchor not found')
    s = s.replace(needle2, replacement2, 1)

# Make the selected Studio soundtrack clearly audible while retaining headroom.
s = s.replace("'volume=0.58'", "'volume=0.72'", 1)
renderer.write_text(s)

edge = Path('supabase/functions/studio-render/index.ts')
e = edge.read_text()

# Native renderer is mandatory. The legacy sparse-frame fallback could produce
# a visually valid movie without the guaranteed baked AAC soundtrack.
anchor = """  const imageUrls = validateImages(body.image_urls, userId);\n  const template = validateTemplate(body.template, imageUrls.length);"""
locked = """  if (!nativeReady) throw new Error(\"studio_native_renderer_unavailable\");\n  const imageUrls = validateImages(body.image_urls, userId);\n  const template = validateTemplate(body.template, imageUrls.length);"""
if 'if (!nativeReady) throw new Error("studio_native_renderer_unavailable");' not in e:
    if anchor not in e:
        raise SystemExit('edge prepareRender anchor not found')
    e = e.replace(anchor, locked, 1)

# Return 503 instead of silently falling back when the native renderer is down.
handler_anchor = """    const nativeReady = await nativeWorkerAvailable();\n    prepared = await prepareRender(body, user.id, nativeReady);"""
handler_locked = """    const nativeReady = await nativeWorkerAvailable();\n    if (!nativeReady) {\n      return json({ ok: false, error: \"studio_native_renderer_unavailable\" }, 503, req);\n    }\n    prepared = await prepareRender(body, user.id, true);"""
if handler_anchor in e:
    e = e.replace(handler_anchor, handler_locked, 1)
elif 'prepared = await prepareRender(body, user.id, true);' not in e:
    raise SystemExit('edge handler native lock anchor not found')

edge.write_text(e)

# Guard the contracts that previously regressed.
checks = {
    'renderer preserves selected audio preset': "raw.audio_preset ?? template.audio_preset" in s,
    'renderer maps audio into final MP4': "`${audioInputIndex}:a:0`" in s,
    'renderer encodes AAC': "'-c:a'" in s and "'aac'" in s,
    'renderer verifies final audio stream': "await verifyOutputStreams(outputPath);" in s,
    'renderer output is portrait': 'const WIDTH = 1080;' in s and 'const HEIGHT = 1920;' in s,
    'renderer portrait is default': "fit: String(shot.fit ?? 'portrait') === 'fit' ? 'fit' : 'portrait'" in s,
    'edge refuses silent legacy fallback': 'studio_native_renderer_unavailable' in e,
    'edge passes selected audio preset': 'audio_preset: audioPreset' in e,
}
failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit('Studio contract check failed: ' + ', '.join(failed))

print('Studio audio + portrait contracts locked.')
