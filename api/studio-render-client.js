import { createClient } from '@supabase/supabase-js';
import { chmod, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';

const PROJECT_HOST = 'vplgtcguxujxwrgguxqq.supabase.co';
const OUTPUT_WIDTH = 1080;
const OUTPUT_HEIGHT = 1920;
const OUTPUT_FPS = 30;
const MIN_IMAGES = 3;
const MAX_IMAGES = 6;
const MAX_IMAGE_BYTES = 10 * 1024 * 1024;
const MAX_TOTAL_SECONDS = 30;
const ALLOWED_AUDIO = new Set([
  'ocean',
  'chill',
  'singing_bowl',
  'om_drone',
  'jungle',
  'luxury',
  'road',
  'workshop',
  'clean_ambient',
  'night_beach',
]);

let cachedFfmpegPath = null;

function cors(request) {
  const origin = request.headers.get('origin') || '*';
  return {
    'access-control-allow-origin': origin,
    'access-control-allow-methods': 'POST, OPTIONS',
    'access-control-allow-headers': 'content-type',
    'access-control-allow-credentials': 'true',
    'access-control-max-age': '600',
    vary: 'Origin, Access-Control-Request-Method, Access-Control-Request-Headers',
  };
}

function json(request, data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...cors(request),
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
    },
  });
}

function cleanError(error) {
  return (error instanceof Error ? error.message : String(error ?? 'unknown_error')).slice(0, 1800);
}

function finite(value, fallback, min, max) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.min(max, Math.max(min, number));
}

function assertImageUrl(raw, userId) {
  const url = new URL(String(raw ?? ''));
  if (url.protocol !== 'https:' || url.host !== PROJECT_HOST) {
    throw new Error('studio_image_host_not_allowed');
  }
  const decoded = decodeURIComponent(url.pathname);
  const expected = `/storage/v1/object/public/listing-images/${userId}/`;
  if (!decoded.startsWith(expected)) {
    throw new Error('studio_image_not_owned_by_user');
  }
  return url.toString();
}

function sanitizeShot(raw, index) {
  const shot = raw && typeof raw === 'object' ? raw : {};
  const start = shot.start_position && typeof shot.start_position === 'object'
    ? shot.start_position
    : {};
  const end = shot.end_position && typeof shot.end_position === 'object'
    ? shot.end_position
    : {};
  const focal = shot.focal && typeof shot.focal === 'object' ? shot.focal : {};
  const transition = String(shot.transition ?? 'crossFade');
  return {
    index,
    duration: finite(shot.duration, 3, 1.2, 6),
    startScale: finite(shot.start_scale, 1.04, 1.0, 1.3),
    endScale: finite(shot.end_scale, 1.12, 1.0, 1.3),
    startX: finite(start.x, 0, -0.18, 0.18),
    startY: finite(start.y, 0, -0.18, 0.18),
    endX: finite(end.x, 0, -0.18, 0.18),
    endY: finite(end.y, 0, -0.18, 0.18),
    focalX: finite(focal.x, 0.5, 0, 1),
    focalY: finite(focal.y, 0.5, 0, 1),
    transition,
    transitionDuration: transition === 'hardCut'
      ? 0.04
      : finite(shot.transition_duration, 0.45, 0.08, 0.8),
  };
}

function assertPayload(payload) {
  const userId = String(payload?.user_id ?? '');
  if (!/^[0-9a-f-]{36}$/i.test(userId)) throw new Error('invalid_user_id');

  const rawImages = Array.isArray(payload?.image_urls) ? payload.image_urls : [];
  if (rawImages.length < MIN_IMAGES || rawImages.length > MAX_IMAGES) {
    throw new Error('studio_requires_3_to_6_images');
  }
  const imageUrls = rawImages.map((url) => assertImageUrl(url, userId));

  const template = payload?.template ?? {};
  if (Number(template.width) !== OUTPUT_WIDTH || Number(template.height) !== OUTPUT_HEIGHT) {
    throw new Error('invalid_studio_output_size');
  }
  if (Number(template.fps) !== OUTPUT_FPS) throw new Error('invalid_studio_fps');

  const rawShots = Array.isArray(template.shots) ? template.shots : [];
  if (rawShots.length !== imageUrls.length) throw new Error('studio_shot_count_mismatch');
  const shots = rawShots.map(sanitizeShot);
  const totalDuration = shots.reduce((sum, shot) => sum + shot.duration, 0);
  if (totalDuration > MAX_TOTAL_SECONDS) throw new Error('studio_video_too_long');

  const audioPreset = String(payload?.audio_preset ?? template.audio_preset ?? 'clean_ambient');
  if (!ALLOWED_AUDIO.has(audioPreset)) throw new Error('invalid_audio_preset');

  const output = payload?.output ?? {};
  const storageUrl = String(output.storage_url ?? '');
  const storageAnonKey = String(output.storage_anon_key ?? '');
  const bucket = String(output.bucket ?? '');
  const videoPath = String(output.video_path ?? '');
  const videoToken = String(output.video_token ?? '');
  const posterPath = String(output.poster_path ?? '');
  const posterToken = String(output.poster_token ?? '');
  const storage = new URL(storageUrl);
  if (storage.protocol !== 'https:' || storage.host !== PROJECT_HOST) {
    throw new Error('invalid_storage_host');
  }
  if (!storageAnonKey || bucket !== 'listing-videos') throw new Error('invalid_storage_output');
  const expectedPrefix = `generated/${userId}/`;
  if (!videoPath.startsWith(expectedPrefix) || !posterPath.startsWith(expectedPrefix)) {
    throw new Error('invalid_studio_output_path');
  }
  if (!videoToken || !posterToken) throw new Error('missing_studio_upload_token');

  return {
    userId,
    imageUrls,
    shots,
    audioPreset,
    output: {
      storageUrl,
      storageAnonKey,
      bucket,
      videoPath,
      videoToken,
      posterPath,
      posterToken,
    },
  };
}

async function getFfmpegPath() {
  if (cachedFfmpegPath) return cachedFfmpegPath;
  let imported;
  try {
    imported = await import('ffmpeg-static');
  } catch (error) {
    throw new Error(`studio_ffmpeg_import:${cleanError(error)}`);
  }
  const path = imported?.default;
  if (!path) throw new Error('studio_ffmpeg_binary_missing');
  try {
    await chmod(path, 0o755);
  } catch (_) {
    // Vercel bundles are often already executable and may be read-only.
  }
  cachedFfmpegPath = path;
  return path;
}

async function runFfmpeg(args, timeoutMs = 270000) {
  const ffmpegPath = await getFfmpegPath();
  return await new Promise((resolve, reject) => {
    const child = spawn(ffmpegPath, args, { stdio: ['ignore', 'ignore', 'pipe'] });
    let stderr = '';
    let settled = false;
    const finish = (error) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      error ? reject(error) : resolve();
    };
    const timer = setTimeout(() => {
      child.kill('SIGKILL');
      finish(new Error('studio_ffmpeg_timeout'));
    }, timeoutMs);
    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
      if (stderr.length > 24000) stderr = stderr.slice(-24000);
    });
    child.once('error', (error) => finish(new Error(`studio_ffmpeg_spawn:${cleanError(error)}`)));
    child.once('close', (code) => {
      if (code === 0) finish();
      else finish(new Error(`studio_ffmpeg_exit_${code}:${stderr.slice(-4200)}`));
    });
  });
}

async function downloadImage(url, path) {
  const response = await fetch(url, {
    redirect: 'follow',
    headers: { 'accept-encoding': 'identity' },
  });
  if (!response.ok) throw new Error(`studio_image_download_${response.status}`);
  const declared = Number(response.headers.get('content-length') ?? 0);
  if (declared > MAX_IMAGE_BYTES) throw new Error('studio_image_too_large');
  const bytes = new Uint8Array(await response.arrayBuffer());
  if (bytes.byteLength > MAX_IMAGE_BYTES) throw new Error('studio_image_too_large');
  await writeFile(path, bytes);
}

function xfadeName(transition) {
  switch (transition) {
    case 'pushLeft':
      return 'slideleft';
    case 'pushUp':
      return 'slideup';
    case 'splitVertical':
      return 'wipeleft';
    case 'splitHorizontal':
      return 'wipeup';
    case 'hardCut':
      return 'fade';
    case 'crossFade':
    default:
      return 'fade';
  }
}

function buildVideoFilter(shots) {
  const filters = [];
  for (let i = 0; i < shots.length; i += 1) {
    const shot = shots[i];
    const frames = Math.max(2, Math.round(shot.duration * OUTPUT_FPS));
    const denom = Math.max(1, frames - 1);
    const zoom = `(${shot.startScale.toFixed(6)}+(${(shot.endScale - shot.startScale).toFixed(6)})*min(1,on/${denom}))`;
    const panX = `(${shot.startX.toFixed(6)}+(${(shot.endX - shot.startX).toFixed(6)})*min(1,on/${denom}))`;
    const panY = `(${shot.startY.toFixed(6)}+(${(shot.endY - shot.startY).toFixed(6)})*min(1,on/${denom}))`;
    const x = `max(0,min(iw-iw/zoom,(iw-iw/zoom)/2+(${panX})*(iw-iw/zoom)))`;
    const y = `max(0,min(ih-ih/zoom,(ih-ih/zoom)/2+(${panY})*(ih-ih/zoom)))`;
    const cropX = `max(0,min(iw-${OUTPUT_WIDTH},iw*${shot.focalX.toFixed(6)}-${OUTPUT_WIDTH / 2}))`;
    const cropY = `max(0,min(ih-${OUTPUT_HEIGHT},ih*${shot.focalY.toFixed(6)}-${OUTPUT_HEIGHT / 2}))`;
    filters.push(
      `[${i}:v]scale=1350:2400:force_original_aspect_ratio=increase,` +
        `crop=${OUTPUT_WIDTH}:${OUTPUT_HEIGHT}:x='${cropX}':y='${cropY}',` +
        `setsar=1,zoompan=z='${zoom}':x='${x}':y='${y}':d=1:` +
        `s=${OUTPUT_WIDTH}x${OUTPUT_HEIGHT}:fps=${OUTPUT_FPS},` +
        `trim=duration=${shot.duration.toFixed(3)},setpts=PTS-STARTPTS,` +
        `fps=${OUTPUT_FPS},settb=AVTB,format=yuv420p[v${i}]`,
    );
  }

  let currentLabel = 'v0';
  let currentDuration = shots[0].duration;
  for (let i = 1; i < shots.length; i += 1) {
    const previous = shots[i - 1];
    const duration = Math.min(
      previous.transitionDuration,
      previous.duration * 0.3,
      shots[i].duration * 0.3,
    );
    const offset = Math.max(0.04, currentDuration - duration);
    const nextLabel = `mix${i}`;
    filters.push(
      `[${currentLabel}][v${i}]xfade=transition=${xfadeName(previous.transition)}:` +
        `duration=${duration.toFixed(3)}:offset=${offset.toFixed(3)},` +
        `fps=${OUTPUT_FPS},settb=AVTB,format=yuv420p[${nextLabel}]`,
    );
    currentLabel = nextLabel;
    currentDuration += shots[i].duration - duration;
  }
  return {
    filter: filters.join(';'),
    label: currentLabel,
    duration: currentDuration,
  };
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
  const base = {
    ocean: 110,
    chill: 196,
    singing_bowl: 432,
    om_drone: 136.1,
    jungle: 164.81,
    luxury: 220,
    road: 110,
    workshop: 175,
    night_beach: 164.81,
    clean_ambient: 261.63,
  }[presetId] ?? 261.63;
  let smoothNoise = 0;
  for (let i = 0; i < sampleCount; i += 1) {
    const t = i / sampleRate;
    smoothNoise = smoothNoise * 0.97 + (random() * 2 - 1) * 0.03;
    const breathe = 0.74 + 0.26 * Math.sin(2 * Math.PI * 0.1 * t);
    const tone1 = Math.sin(2 * Math.PI * base * t);
    const tone2 = Math.sin(2 * Math.PI * base * 1.5 * t);
    const rhythmic = presetId === 'road' || presetId === 'workshop'
      ? Math.exp(-((t % 0.5) * 14)) * Math.sin(2 * Math.PI * 72 * t) * 0.12
      : 0;
    const noiseAmount = presetId === 'ocean' || presetId === 'jungle' || presetId === 'night_beach'
      ? 0.09
      : 0.025;
    const sample = breathe * (tone1 * 0.08 + tone2 * 0.035) + smoothNoise * noiseAmount + rhythmic;
    const fade = Math.min(1, t / 0.08, (seconds - t) / 0.08);
    const shaped = Math.max(-0.9, Math.min(0.9, sample * Math.max(0, fade)));
    buffer.writeInt16LE(Math.round(shaped * 32767), 44 + i * 2);
  }
  return buffer;
}

async function renderVideo(imagePaths, shots, audioPath, outputPath) {
  const args = ['-hide_banner', '-loglevel', 'error', '-y'];
  for (let i = 0; i < imagePaths.length; i += 1) {
    args.push(
      '-loop', '1',
      '-framerate', String(OUTPUT_FPS),
      '-t', shots[i].duration.toFixed(3),
      '-i', imagePaths[i],
    );
  }
  args.push('-stream_loop', '-1', '-i', audioPath);
  const audioIndex = imagePaths.length;
  const built = buildVideoFilter(shots);
  args.push(
    '-filter_complex', built.filter,
    '-map', `[${built.label}]`,
    '-map', `${audioIndex}:a:0`,
    '-t', built.duration.toFixed(3),
    '-r', String(OUTPUT_FPS),
    '-fps_mode', 'cfr',
    '-c:v', 'libx264',
    '-preset', 'veryfast',
    '-profile:v', 'high',
    '-level:v', '4.0',
    '-pix_fmt', 'yuv420p',
    '-crf', '21',
    '-maxrate', '6000k',
    '-bufsize', '12000k',
    '-g', '60',
    '-keyint_min', '60',
    '-sc_threshold', '0',
    '-c:a', 'aac',
    '-b:a', '128k',
    '-ar', '48000',
    '-ac', '2',
    '-movflags', '+faststart',
    outputPath,
  );
  await runFfmpeg(args);
  return built.duration;
}

async function makePoster(videoPath, posterPath) {
  await runFfmpeg([
    '-hide_banner', '-loglevel', 'error', '-y',
    '-ss', '0.45', '-i', videoPath,
    '-frames:v', '1',
    '-vf', 'scale=540:960:force_original_aspect_ratio=decrease',
    '-q:v', '3',
    posterPath,
  ], 45000);
}

async function uploadSigned(storage, bucket, path, token, bytes, contentType) {
  const { error } = await storage.from(bucket).uploadToSignedUrl(path, token, bytes, {
    contentType,
    cacheControl: '31536000',
  });
  if (error) throw new Error(`studio_storage_upload:${error.message}`);
}

export default async function handler(request) {
  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: cors(request) });
  }
  if (request.method !== 'POST') return json(request, { error: 'method_not_allowed' }, 405);

  let payload;
  try {
    payload = await request.json();
  } catch (_) {
    return json(request, { error: 'invalid_json' }, 400);
  }

  let input;
  try {
    input = assertPayload(payload);
  } catch (error) {
    return json(request, { error: cleanError(error) }, 400);
  }

  const id = randomUUID();
  const imagePaths = input.imageUrls.map((_, index) => join(tmpdir(), `studio2-${id}-${index}.img`));
  const audioPath = join(tmpdir(), `studio2-${id}.wav`);
  const videoPath = join(tmpdir(), `studio2-${id}.mp4`);
  const posterPath = join(tmpdir(), `studio2-${id}.jpg`);

  try {
    await Promise.all(input.imageUrls.map((url, index) => downloadImage(url, imagePaths[index])));
    await writeFile(audioPath, buildSoundtrackWav(input.audioPreset));
    const duration = await renderVideo(imagePaths, input.shots, audioPath, videoPath);
    await makePoster(videoPath, posterPath);

    const [videoBytes, posterBytes] = await Promise.all([
      readFile(videoPath),
      readFile(posterPath),
    ]);
    const supabase = createClient(
      input.output.storageUrl,
      input.output.storageAnonKey,
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
    await uploadSigned(
      supabase.storage,
      input.output.bucket,
      input.output.videoPath,
      input.output.videoToken,
      videoBytes,
      'video/mp4',
    );
    await uploadSigned(
      supabase.storage,
      input.output.bucket,
      input.output.posterPath,
      input.output.posterToken,
      posterBytes,
      'image/jpeg',
    );

    return json(request, {
      ok: true,
      duration_seconds: duration,
      video_size_bytes: videoBytes.length,
      poster_size_bytes: posterBytes.length,
      renderer: 'studio-one-pass-v2',
    });
  } catch (error) {
    console.error('[studio-render-client]', error);
    return json(request, { error: cleanError(error), renderer: 'studio-one-pass-v2' }, 500);
  } finally {
    await Promise.allSettled([
      ...imagePaths.map((path) => rm(path, { force: true })),
      rm(audioPath, { force: true }),
      rm(videoPath, { force: true }),
      rm(posterPath, { force: true }),
    ]);
  }
}
