from pathlib import Path

p = Path('api/studio-render-node.js')
s = p.read_text()

# Import writer for generated soundtrack WAV.
s = s.replace("import { readFile, rm, stat } from 'node:fs/promises';", "import { readFile, rm, stat, writeFile } from 'node:fs/promises';", 1)

if 'const ALLOWED_AUDIO = new Set([' not in s:
    s = s.replace("const HEIGHT = 1920;\n", """const HEIGHT = 1920;
const ALLOWED_AUDIO = new Set([
  'ocean', 'chill', 'singing_bowl', 'om_drone', 'jungle', 'luxury',
  'road', 'workshop', 'clean_ambient', 'night_beach',
]);
""", 1)

# Preserve selected soundtrack in sanitized manifest.
s = s.replace(
    "  return { imageUrls, shots };\n}\n\nfunction easingExpression",
    """  const requestedAudio = String(raw.audio_preset ?? 'clean_ambient');
  const audioPreset = ALLOWED_AUDIO.has(requestedAudio) ? requestedAudio : 'clean_ambient';
  return { imageUrls, shots, audioPreset };
}

function seededRandom(seed) {
  let state = seed >>> 0;
  return () => {
    state = (1664525 * state + 1013904223) >>> 0;
    return state / 0x100000000;
  };
}

function buildSoundtrackWav(presetId) {
  const sampleRate = 16000;
  const seconds = 6;
  const sampleCount = sampleRate * seconds;
  const dataLength = sampleCount * 2;
  const buffer = Buffer.alloc(44 + dataLength);
  buffer.write('RIFF', 0, 4, 'ascii');
  buffer.writeUInt32LE(36 + dataLength, 4);
  buffer.write('WAVE', 8, 4, 'ascii');
  buffer.write('fmt ', 12, 4, 'ascii');
  buffer.writeUInt32LE(16, 16);
  buffer.writeUInt16LE(1, 20);
  buffer.writeUInt16LE(1, 22);
  buffer.writeUInt32LE(sampleRate, 24);
  buffer.writeUInt32LE(sampleRate * 2, 28);
  buffer.writeUInt16LE(2, 32);
  buffer.writeUInt16LE(16, 34);
  buffer.write('data', 36, 4, 'ascii');
  buffer.writeUInt32LE(dataLength, 40);

  let seed = 71;
  for (const code of Buffer.from(presetId)) seed = (seed * 31 + code) >>> 0;
  const random = seededRandom(seed);
  let smoothNoise = 0;
  const tone = (t, hz) => Math.sin(2 * Math.PI * hz * t);
  const pulse = (t, period, decay) => Math.exp(-(((t % period) + period) % period) * decay);

  for (let i = 0; i < sampleCount; i += 1) {
    const t = i / sampleRate;
    const rawNoise = random() * 2 - 1;
    smoothNoise = smoothNoise * .965 + rawNoise * .035;
    let sample = 0;
    switch (presetId) {
      case 'ocean': {
        const swell = .68 + .32 * tone(t, .11);
        sample = smoothNoise * .42 * swell + tone(t, 52) * .035;
        break;
      }
      case 'chill': {
        const breathe = .72 + .28 * tone(t, .18);
        sample = breathe * (.105 * tone(t, 196) + .08 * tone(t, 246.94) + .065 * tone(t, 293.66));
        break;
      }
      case 'singing_bowl': {
        const local = t % 3;
        const env = Math.exp(-local * .72);
        sample = env * (.25 * tone(t, 432) + .075 * tone(t, 864));
        break;
      }
      case 'om_drone': {
        const breathe = .78 + .22 * tone(t, .08);
        sample = breathe * (.18 * tone(t, 136.1) + .075 * tone(t, 272.2));
        break;
      }
      case 'jungle': {
        const chirp = pulse(t, 1.7, 10) * tone(t, 720 + 90 * tone(t, .4));
        sample = smoothNoise * .16 + chirp * .10 + tone(t, 78) * .025;
        break;
      }
      case 'luxury': {
        const bass = pulse(t, .75, 12) * tone(t, 72);
        sample = bass * .14 + tone(t, 220) * .075 + tone(t, 277.18) * .055 + tone(t, 329.63) * .045;
        break;
      }
      case 'road': {
        const kick = pulse(t, .5, 18) * tone(t, 68);
        const tick = pulse(t + .25, .5, 32) * smoothNoise;
        sample = kick * .24 + tick * .10 + tone(t, 110) * .035;
        break;
      }
      case 'workshop': {
        const knock = pulse(t, .4, 24) * tone(t, 175);
        const offbeat = pulse(t + .2, .8, 30) * smoothNoise;
        sample = knock * .20 + offbeat * .13 + tone(t, 88) * .035;
        break;
      }
      case 'night_beach': {
        const swell = .70 + .30 * tone(t, .09);
        sample = smoothNoise * .25 * swell + tone(t, 164.81) * .07 + tone(t, 196) * .05 + tone(t, 246.94) * .035;
        break;
      }
      case 'clean_ambient':
      default: {
        const breathe = .70 + .30 * tone(t, .10);
        sample = smoothNoise * .07 + breathe * (.08 * tone(t, 261.63) + .055 * tone(t, 392));
      }
    }
    const fadeIn = Math.min(1, t / .08);
    const fadeOut = Math.min(1, (seconds - t) / .08);
    const shaped = Math.max(-.92, Math.min(.92, sample * Math.min(fadeIn, fadeOut)));
    buffer.writeInt16LE(Math.round(shaped * 32767), 44 + i * 2);
  }
  return buffer;
}

function easingExpression""",
    1,
)

# Mux soundtrack into final movie.
s = s.replace('async function composeShots(shotPaths, shots, outputPath) {', 'async function composeShots(shotPaths, shots, audioPath, outputPath) {', 1)
s = s.replace(
    "  for (const path of shotPaths) args.push('-i', path);\n\n  const filters = [];",
    "  for (const path of shotPaths) args.push('-i', path);\n  args.push('-stream_loop', '-1', '-i', audioPath);\n  const audioIndex = shotPaths.length;\n\n  const filters = [];",
    1,
)
s = s.replace(
    "    '-map',\n    '[outv]',\n    '-an',\n    '-r',",
    "    '-map',\n    '[outv]',\n    '-map',\n    `${audioIndex}:a:0`,\n    '-t',\n    ffNumber(timeline),\n    '-r',",
    1,
)
# Smooth, decoder-friendly delivery while retaining 1080x1920 CFR30.
s = s.replace("    'high',\n    '-level:v',\n    '4.1',", "    'main',\n    '-level:v',\n    '4.0',\n    '-tune',\n    'fastdecode',", 2)
s = s.replace("    '5500k',\n    '-bufsize',\n    '11000k',", "    '3600k',\n    '-bufsize',\n    '7200k',", 1)
compose_start = s.index('async function composeShots')
compose_end = s.index('async function makePoster')
compose = s[compose_start:compose_end]
compose = compose.replace("    '-g',\n    '60',\n    '-keyint_min',\n    '60',", "    '-g',\n    '30',\n    '-keyint_min',\n    '30',", 1)
compose = compose.replace(
    "    '-sc_threshold',\n    '0',\n    '-movflags',",
    "    '-sc_threshold',\n    '0',\n    '-c:a',\n    'aac',\n    '-b:a',\n    '128k',\n    '-ar',\n    '48000',\n    '-ac',\n    '2',\n    '-movflags',",
    1,
)
s = s[:compose_start] + compose + s[compose_end:]

s = s.replace(
    "  const outputPath = join(tmpdir(), `swipess-studio-${tempId}.mp4`);\n  const posterPath = join(tmpdir(), `swipess-studio-${tempId}.jpg`);",
    "  const outputPath = join(tmpdir(), `swipess-studio-${tempId}.mp4`);\n  const audioPath = join(tmpdir(), `swipess-studio-${tempId}.wav`);\n  const posterPath = join(tmpdir(), `swipess-studio-${tempId}.jpg`);",
    1,
)
s = s.replace(
    '    await composeShots(shotPaths, manifest.shots, outputPath);\n    await makePoster(outputPath, posterPath);',
    '    await writeFile(audioPath, buildSoundtrackWav(manifest.audioPreset));\n    await composeShots(shotPaths, manifest.shots, audioPath, outputPath);\n    await makePoster(outputPath, posterPath);',
    1,
)
s = s.replace(
    "      rm(outputPath, { force: true }).catch(() => {}),\n      rm(posterPath, { force: true }).catch(() => {}),",
    "      rm(outputPath, { force: true }).catch(() => {}),\n      rm(audioPath, { force: true }).catch(() => {}),\n      rm(posterPath, { force: true }).catch(() => {}),",
    1,
)

p.write_text(s)

# Ordinary uploaded videos: easier decode too.
p = Path('api/video-transcode.js')
t = p.read_text()
t = t.replace("    'high',\n    '-level:v',\n    '4.0',", "    'main',\n    '-level:v',\n    '4.0',\n    '-tune',\n    'fastdecode',", 1)
t = t.replace("    '4500k',\n    '-bufsize',\n    '9000k',", "    '3600k',\n    '-bufsize',\n    '7200k',", 1)
t = t.replace("    '-g',\n    '60',\n    '-keyint_min',\n    '60',", "    '-g',\n    '30',\n    '-keyint_min',\n    '30',", 1)
p.write_text(t)
