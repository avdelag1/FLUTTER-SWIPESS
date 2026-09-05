import { createClient } from '@supabase/supabase-js';
import { waitUntil } from '@vercel/functions';
import ffmpegPath from 'ffmpeg-static';
import { createWriteStream } from 'node:fs';
import { readFile, rm, stat, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';

const PROJECT_HOST = 'vplgtcguxujxwrgguxqq.supabase.co';
const PIPELINE_URL = `https://${PROJECT_HOST}/functions/v1/video-pipeline`;
const MAX_MANIFEST_BYTES = 1024 * 1024;
const MAX_IMAGE_BYTES = 12 * 1024 * 1024;
const MAX_ERROR_CHARS = 1800;
const FPS = 30;
const WIDTH = 1080;
const HEIGHT = 1920;

// Work above delivery resolution so slow pan/zoom motion is not quantized into
// visible one-pixel jumps. The old renderer downscaled to 1080x1920 *before*
// zoompan, which could make a technically 30fps clip look like it was shaking.
const WORK_WIDTH = 1620;
const WORK_HEIGHT = 2880;

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

function sendJson(response, data, status = 200) {
  response.statusCode = status;
  response.setHeader('content-type', 'application/json; charset=utf-8');
  response.setHeader('cache-control', 'no-store');
  response.end(JSON.stringify(data));
}

function compactError(error) {
  return (error instanceof Error ? error.message : String(error ?? 'unknown_error')).slice(
    0,
    MAX_ERROR_CHARS,
  );
}

function clamp(value, min, max) {
  const number = Number(value);
  if (!Number.isFinite(number)) return min;
  return Math.min(max, Math.max(min, number));
}

function assertJob(payload) {
  const jobId = String(payload?.job_id ?? '');
  const token = String(payload?.token ?? '');
  const authorizeUrl = String(payload?.authorize_url ?? '');
  if (!/^[0-9a-f-]{36}$/i.test(jobId)) throw new Error('invalid_job_id');
  if (!/^[0-9a-f]{64}$/i.test(token)) throw new Error('invalid_job_token');
  if (authorizeUrl !== PIPELINE_URL) throw new Error('invalid_authorize_url');
  return { jobId, token, authorizeUrl };
}

async function postPipeline(url, body) {
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  const text = await response.text();
  let data = {};
  try {
    data = text ? JSON.parse(text) : {};
  } catch (_) {
    data = { raw: text };
  }
  if (!response.ok) {
    throw new Error(
      `pipeline_${response.status}:${String(data?.error ?? data?.raw ?? 'request_failed')}`,
    );
  }
  return data;
}

function assertSupabaseUrl(raw, name) {
  const parsed = new URL(String(raw ?? ''));
  if (parsed.protocol !== 'https:' || parsed.host !== PROJECT_HOST) {
    throw new Error(`${name}_host_not_allowed`);
  }
  return parsed;
}

async function fetchBytes(url, maxBytes, label) {
  assertSupabaseUrl(url, label);
  const response = await fetch(url, {
    redirect: 'follow',
    headers: { 'accept-encoding': 'identity', 'cache-control': 'no-cache' },
  });
  if (!response.ok) throw new Error(`${label}_download_${response.status}`);
  const declared = Number(response.headers.get('content-length') ?? 0);
  if (declared > maxBytes) throw new Error(`${label}_too_large`);
  const bytes = Buffer.from(await response.arrayBuffer());
  if (bytes.length > maxBytes) throw new Error(`${label}_too_large`);
  return bytes;
}

async function fetchToFile(url, path, maxBytes, label) {
  assertSupabaseUrl(url, label);
  const response = await fetch(url, {
    redirect: 'follow',
    headers: { 'accept-encoding': 'identity', 'cache-control': 'no-cache' },
  });
  if (!response.ok || !response.body) {
    throw new Error(`${label}_download_${response.status}`);
  }
  const declared = Number(response.headers.get('content-length') ?? 0);
  if (declared > maxBytes) throw new Error(`${label}_too_large`);

  let received = 0;
  const limiter = new TransformStream({
    transform(chunk, controller) {
      received += chunk.byteLength;
      if (received > maxBytes) throw new Error(`${label}_too_large`);
      controller.enqueue(chunk);
    },
  });
  await pipeline(
    Readable.fromWeb(response.body.pipeThrough(limiter)),
    createWriteStream(path),
  );
  return received;
}

function runFfmpeg(args, timeoutMs = 260000) {
  if (!ffmpegPath) return Promise.reject(new Error('ffmpeg_binary_missing'));
  return new Promise((resolve, reject) => {
    const child = spawn(ffmpegPath, args, { stdio: ['ignore', 'ignore', 'pipe'] });
    let stderr = '';
    const timer = setTimeout(() => {
      child.kill('SIGKILL');
      reject(new Error('ffmpeg_timeout'));
    }, timeoutMs);
    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
      if (stderr.length > 18000) stderr = stderr.slice(-18000);
    });
    child.once('error', (error) => {
      clearTimeout(timer);
      reject(error);
    });
    child.once('close', (code) => {
      clearTimeout(timer);
      if (code === 0) resolve();
      else reject(new Error(`ffmpeg_exit_${code}:${stderr.slice(-2600)}`));
    });
  });
}

function sanitizeManifest(raw) {
  if (!raw || typeof raw !== 'object' || raw.kind !== 'swipess_studio_manifest') {
    throw new Error('invalid_studio_manifest');
  }
  const imageUrls = Array.isArray(raw.image_urls)
    ? raw.image_urls.map((value) => String(value ?? '').trim()).filter(Boolean)
    : [];
  if (imageUrls.length < 3 || imageUrls.length > 6) {
    throw new Error('studio_requires_3_to_6_images');
  }
  for (const url of imageUrls) assertSupabaseUrl(url, 'studio_image');

  const template = raw.template && typeof raw.template === 'object' ? raw.template : {};
  if (Number(template.width) !== WIDTH || Number(template.height) !== HEIGHT) {
    throw new Error('invalid_studio_output_size');
  }
  if (Number(template.fps) !== FPS) throw new Error('invalid_studio_fps');
  const rawShots = Array.isArray(template.shots) ? template.shots : [];
  if (rawShots.length !== imageUrls.length) throw new Error('studio_shot_count_mismatch');

  const shots = rawShots.map((value) => {
    const shot = value && typeof value === 'object' ? value : {};
    const start = shot.start_position && typeof shot.start_position === 'object'
      ? shot.start_position
      : {};
    const end = shot.end_position && typeof shot.end_position === 'object'
      ? shot.end_position
      : {};
    const focal = shot.focal && typeof shot.focal === 'object' ? shot.focal : {};
    return {
      duration: clamp(shot.duration ?? 3, 1.2, 6),
      startScale: clamp(shot.start_scale ?? 1.04, 1.0, 1.3),
      endScale: clamp(shot.end_scale ?? 1.12, 1.0, 1.3),
      startX: clamp(start.x ?? 0, -0.18, 0.18),
      startY: clamp(start.y ?? 0, -0.18, 0.18),
      endX: clamp(end.x ?? 0, -0.18, 0.18),
      endY: clamp(end.y ?? 0, -0.18, 0.18),
      focalX: clamp(focal.x ?? 0.5, 0, 1),
      focalY: clamp(focal.y ?? 0.5, 0, 1),
      easing: String(shot.easing ?? 'easeInOut'),
      transition: String(shot.transition ?? 'crossFade'),
      transitionSeconds: clamp(shot.transition_duration ?? 0.45, 0.03, 0.9),
    };
  });

  const requestedAudio = String(raw.audio_preset ?? template.audio_preset ?? 'clean_ambient');
  const audioPreset = ALLOWED_AUDIO.has(requestedAudio) ? requestedAudio : 'clean_ambient';
  return { imageUrls, shots, audioPreset };
}

function easingExpression(kind, frameCount) {
  const denominator = Math.max(1, frameCount - 1);
  const t = `(on/${denominator})`;
  switch (kind) {
    case 'linear':
      return t;
    case 'easeIn':
      return `(${t}*${t}*${t})`;
    case 'easeOut':
      return `(1-(1-${t})*(1-${t})*(1-${t}))`;
    case 'easeInOut':
    default:
      return `(${t}*${t}*(3-2*${t}))`;
  }
}

function ffNumber(value) {
  return Number(value).toFixed(6);
}

function xfadeName(name) {
  switch (name) {
    case 'pushLeft':
      return 'slideleft';
    case 'pushUp':
      return 'slideup';
    case 'splitVertical':
      return 'wipeleft';
    case 'splitHorizontal':
      return 'wipeup';
    case 'hardCut':
    case 'crossFade':
    default:
      return 'fade';
  }
}

function safeTransitionDuration(previousShot, nextShot) {
  let duration = Math.min(
    previousShot.transitionSeconds,
    previousShot.duration * 0.45,
    nextShot.duration * 0.45,
  );
  if (previousShot.transition === 'hardCut') duration = 1 / FPS;
  return Math.max(1 / FPS, duration);
}

function composedDuration(shots) {
  if (!shots.length) return 0;
  let timeline = shots[0].duration;
  for (let index = 1; index < shots.length; index += 1) {
    timeline += shots[index].duration - safeTransitionDuration(shots[index - 1], shots[index]);
  }
  return Math.max(0.1, timeline);
}

async function renderShot(imagePath, shot, shotPath) {
  const frameCount = Math.max(2, Math.round(shot.duration * FPS));
  const ease = easingExpression(shot.easing, frameCount);
  const zoom = `(${ffNumber(shot.startScale)}+(${ffNumber(
    shot.endScale - shot.startScale,
  )})*${ease})`;
  const startPanX = clamp(0.5 + shot.startX, 0, 1);
  const endPanX = clamp(0.5 + shot.endX, 0, 1);
  const startPanY = clamp(0.5 + shot.startY, 0, 1);
  const endPanY = clamp(0.5 + shot.endY, 0, 1);
  const panX = `(${ffNumber(startPanX)}+(${ffNumber(endPanX - startPanX)})*${ease})`;
  const panY = `(${ffNumber(startPanY)}+(${ffNumber(endPanY - startPanY)})*${ease})`;
  const cropX = `(iw-${WORK_WIDTH})*${ffNumber(shot.focalX)}`;
  const cropY = `(ih-${WORK_HEIGHT})*${ffNumber(shot.focalY)}`;

  // zoompan's x/y coordinates resolve to integer source pixels. Rendering on a
  // larger canvas first makes each integer step sub-pixel-sized at delivery,
  // removing the tiny back/forth vibration visible on phones.
  const stableX = `max(0,min(iw-iw/zoom,round((iw-iw/zoom)*${panX})))`;
  const stableY = `max(0,min(ih-ih/zoom,round((ih-ih/zoom)*${panY})))`;
  const filter =
    `scale=${WORK_WIDTH}:${WORK_HEIGHT}:force_original_aspect_ratio=increase:` +
    `force_divisible_by=2:flags=lanczos,` +
    `crop=${WORK_WIDTH}:${WORK_HEIGHT}:'max(0,min(iw-${WORK_WIDTH},${cropX}))':` +
    `'max(0,min(ih-${WORK_HEIGHT},${cropY}))',` +
    `setsar=1,` +
    `zoompan=z='${zoom}':x='${stableX}':y='${stableY}':` +
    `d=${frameCount}:s=${WIDTH}x${HEIGHT}:fps=${FPS},` +
    `fps=${FPS},setsar=1,format=yuv420p`;

  await runFfmpeg([
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    '-i',
    imagePath,
    '-sws_flags',
    'lanczos+accurate_rnd+full_chroma_int',
    '-vf',
    filter,
    '-t',
    ffNumber(shot.duration),
    '-an',
    '-r',
    String(FPS),
    '-fps_mode',
    'cfr',
    '-c:v',
    'libx264',
    '-preset',
    'veryfast',
    '-tune',
    'stillimage',
    '-profile:v',
    'high',
    '-level:v',
    '4.1',
    '-pix_fmt',
    'yuv420p',
    '-crf',
    '17',
    '-g',
    '60',
    '-keyint_min',
    '60',
    '-sc_threshold',
    '0',
    shotPath,
  ]);
}

function hashSeed(value) {
  let hash = 2166136261 >>> 0;
  for (const code of String(value).split('').map((char) => char.charCodeAt(0))) {
    hash ^= code;
    hash = Math.imul(hash, 16777619) >>> 0;
  }
  return hash >>> 0;
}

function seededNoise(seed) {
  let state = seed >>> 0;
  return () => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state / 4294967296;
  };
}

function buildStudioSoundtrackWav(presetId, durationSeconds) {
  // Keep the same family of original procedural Swipess soundscapes used by
  // the Flutter preview. No commercial music asset needs to be uploaded.
  const sampleRate = 24000;
  const seconds = Math.max(0.5, Math.min(35, Number(durationSeconds) || 6));
  const sampleCount = Math.ceil(sampleRate * seconds);
  const dataLength = sampleCount * 2;
  const bytes = Buffer.alloc(44 + dataLength);

  bytes.write('RIFF', 0, 'ascii');
  bytes.writeUInt32LE(36 + dataLength, 4);
  bytes.write('WAVE', 8, 'ascii');
  bytes.write('fmt ', 12, 'ascii');
  bytes.writeUInt32LE(16, 16);
  bytes.writeUInt16LE(1, 20);
  bytes.writeUInt16LE(1, 22);
  bytes.writeUInt32LE(sampleRate, 24);
  bytes.writeUInt32LE(sampleRate * 2, 28);
  bytes.writeUInt16LE(2, 32);
  bytes.writeUInt16LE(16, 34);
  bytes.write('data', 36, 'ascii');
  bytes.writeUInt32LE(dataLength, 40);

  const random = seededNoise(hashSeed(presetId));
  let smoothNoise = 0;
  const tone = (t, hz) => Math.sin(2 * Math.PI * hz * t);
  const pulse = (t, period, decay) => Math.exp(-(((t % period) + period) % period) * decay);

  for (let i = 0; i < sampleCount; i += 1) {
    const t = i / sampleRate;
    const rawNoise = random() * 2 - 1;
    smoothNoise = smoothNoise * 0.965 + rawNoise * 0.035;
    let sample = 0;

    switch (presetId) {
      case 'ocean': {
        const swell = 0.68 + 0.32 * tone(t, 0.11);
        sample = smoothNoise * 0.42 * swell + tone(t, 52) * 0.035;
        break;
      }
      case 'chill': {
        const breathe = 0.72 + 0.28 * tone(t, 0.18);
        sample = breathe * (
          0.105 * tone(t, 196) +
          0.08 * tone(t, 246.94) +
          0.065 * tone(t, 293.66)
        );
        break;
      }
      case 'singing_bowl': {
        const local = t % 3;
        const env = Math.exp(-local * 0.72);
        sample = env * (0.25 * tone(t, 432) + 0.075 * tone(t, 864));
        break;
      }
      case 'om_drone': {
        const breathe = 0.78 + 0.22 * tone(t, 0.08);
        sample = breathe * (0.18 * tone(t, 136.1) + 0.075 * tone(t, 272.2));
        break;
      }
      case 'jungle': {
        const chirp = pulse(t, 1.7, 10) * tone(t, 720 + 90 * tone(t, 0.4));
        sample = smoothNoise * 0.16 + chirp * 0.1 + tone(t, 78) * 0.025;
        break;
      }
      case 'luxury': {
        const bass = pulse(t, 0.75, 12) * tone(t, 72);
        sample = bass * 0.14 +
          tone(t, 220) * 0.075 +
          tone(t, 277.18) * 0.055 +
          tone(t, 329.63) * 0.045;
        break;
      }
      case 'road': {
        const kick = pulse(t, 0.5, 18) * tone(t, 68);
        const tick = pulse(t + 0.25, 0.5, 32) * smoothNoise;
        sample = kick * 0.24 + tick * 0.1 + tone(t, 110) * 0.035;
        break;
      }
      case 'workshop': {
        const knock = pulse(t, 0.4, 24) * tone(t, 175);
        const offbeat = pulse(t + 0.2, 0.8, 30) * smoothNoise;
        sample = knock * 0.2 + offbeat * 0.13 + tone(t, 88) * 0.035;
        break;
      }
      case 'night_beach': {
        const swell = 0.7 + 0.3 * tone(t, 0.09);
        sample = smoothNoise * 0.25 * swell +
          tone(t, 164.81) * 0.07 +
          tone(t, 196) * 0.05 +
          tone(t, 246.94) * 0.035;
        break;
      }
      case 'clean_ambient':
      default: {
        const breathe = 0.7 + 0.3 * tone(t, 0.1);
        sample = smoothNoise * 0.07 +
          breathe * (0.08 * tone(t, 261.63) + 0.055 * tone(t, 392));
        break;
      }
    }

    // Only fade the actual movie edges; unlike the old 6-second preview loop,
    // the server generates the complete soundtrack in one continuous pass.
    const fadeIn = Math.min(1, t / 0.12);
    const remaining = seconds - t;
    const fadeOut = Math.min(1, remaining / 0.35);
    const shaped = Math.max(-0.92, Math.min(0.92, sample * Math.min(fadeIn, fadeOut)));
    bytes.writeInt16LE(Math.round(shaped * 32767), 44 + i * 2);
  }
  return bytes;
}

async function composeShots(shotPaths, shots, audioPath, outputPath) {
  const args = ['-hide_banner', '-loglevel', 'error', '-y'];
  for (const path of shotPaths) args.push('-i', path);
  args.push('-i', audioPath);

  const filters = [];
  let current = '0:v';
  let timeline = shots[0].duration;
  for (let index = 1; index < shots.length; index += 1) {
    const previousShot = shots[index - 1];
    const transitionDuration = safeTransitionDuration(previousShot, shots[index]);
    const offset = Math.max(0, timeline - transitionDuration);
    const out = `x${index}`;
    filters.push(
      `[${current}][${index}:v]xfade=transition=${xfadeName(previousShot.transition)}:` +
        `duration=${ffNumber(transitionDuration)}:offset=${ffNumber(offset)}[${out}]`,
    );
    current = out;
    timeline += shots[index].duration - transitionDuration;
  }
  filters.push(`[${current}]fps=${FPS},format=yuv420p,setsar=1[outv]`);

  const audioInputIndex = shotPaths.length;
  args.push(
    '-filter_complex',
    filters.join(';'),
    '-map',
    '[outv]',
    '-map',
    `${audioInputIndex}:a:0`,
    '-r',
    String(FPS),
    '-fps_mode',
    'cfr',
    '-c:v',
    'libx264',
    '-preset',
    'veryfast',
    '-profile:v',
    'main',
    '-level:v',
    '4.0',
    '-tune',
    'fastdecode',
    '-pix_fmt',
    'yuv420p',
    '-crf',
    '18',
    '-maxrate',
    '3600k',
    '-bufsize',
    '7200k',
    '-g',
    '30',
    '-keyint_min',
    '30',
    '-sc_threshold',
    '0',
    '-c:a',
    'aac',
    '-b:a',
    '160k',
    '-ar',
    '48000',
    '-ac',
    '2',
    '-af',
    'volume=0.58',
    '-shortest',
    '-movflags',
    '+faststart',
    outputPath,
  );
  await runFfmpeg(args);
}

async function makePoster(videoPath, posterPath) {
  await runFfmpeg(
    [
      '-hide_banner',
      '-loglevel',
      'error',
      '-y',
      '-ss',
      '0.5',
      '-i',
      videoPath,
      '-frames:v',
      '1',
      '-vf',
      'scale=720:1280:force_original_aspect_ratio=increase:flags=lanczos,crop=720:1280',
      '-q:v',
      '2',
      posterPath,
    ],
    45000,
  );
}

async function uploadSigned(storage, bucket, path, token, bytes, contentType) {
  const { error } = await storage.from(bucket).uploadToSignedUrl(path, token, bytes, {
    contentType,
    cacheControl: '31536000',
  });
  if (error) throw new Error(`storage_upload:${error.message}`);
}

async function processJob({ jobId, token, authorizeUrl }) {
  const tempId = randomUUID();
  const imagePaths = [];
  const shotPaths = [];
  const outputPath = join(tmpdir(), `swipess-studio-${tempId}.mp4`);
  const posterPath = join(tmpdir(), `swipess-studio-${tempId}.jpg`);
  const audioPath = join(tmpdir(), `swipess-studio-${tempId}.wav`);
  let progressiveCompleted = false;
  let sourceSize = 0;

  try {
    const authorization = await postPipeline(authorizeUrl, {
      action: 'authorize',
      job_id: jobId,
      token,
    });
    if (authorization.studio !== true) throw new Error('not_a_studio_job');

    const storageUrl = String(authorization.storage_url ?? '');
    const storageKey = String(authorization.storage_anon_key ?? '');
    const bucket = String(authorization.bucket ?? '');
    const sourceUrl = String(authorization.source_url ?? '');
    const videoPath = String(authorization.video_path ?? '');
    const videoToken = String(authorization.video_token ?? '');
    const posterObjectPath = String(authorization.poster_path ?? '');
    const posterToken = String(authorization.poster_token ?? '');

    assertSupabaseUrl(storageUrl, 'storage');
    if (!storageKey || bucket !== 'listing-videos') throw new Error('invalid_storage_authorization');
    if (!videoPath.startsWith('processed/studio/') || !posterObjectPath.startsWith('processed/studio/')) {
      throw new Error('invalid_studio_output_path');
    }

    const manifestBytes = await fetchBytes(sourceUrl, MAX_MANIFEST_BYTES, 'studio_manifest');
    sourceSize += manifestBytes.length;
    let rawManifest;
    try {
      rawManifest = JSON.parse(manifestBytes.toString('utf8'));
    } catch (_) {
      throw new Error('invalid_studio_manifest_json');
    }
    const manifest = sanitizeManifest(rawManifest);

    for (let index = 0; index < manifest.imageUrls.length; index += 1) {
      const imagePath = join(tmpdir(), `swipess-studio-${tempId}-${index}.img`);
      sourceSize += await fetchToFile(
        manifest.imageUrls[index],
        imagePath,
        MAX_IMAGE_BYTES,
        `studio_image_${index}`,
      );
      imagePaths.push(imagePath);

      const shotPath = join(tmpdir(), `swipess-studio-${tempId}-shot-${index}.mp4`);
      await renderShot(imagePath, manifest.shots[index], shotPath);
      shotPaths.push(shotPath);
    }

    const duration = composedDuration(manifest.shots);
    const soundtrack = buildStudioSoundtrackWav(manifest.audioPreset, duration);
    await writeFile(audioPath, soundtrack);
    sourceSize += soundtrack.length;

    await composeShots(shotPaths, manifest.shots, audioPath, outputPath);
    await makePoster(outputPath, posterPath);

    const [videoInfo, videoBytes, posterBytes] = await Promise.all([
      stat(outputPath),
      readFile(outputPath),
      readFile(posterPath),
    ]);
    const supabase = createClient(storageUrl, storageKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    await uploadSigned(supabase.storage, bucket, videoPath, videoToken, videoBytes, 'video/mp4');
    await uploadSigned(
      supabase.storage,
      bucket,
      posterObjectPath,
      posterToken,
      posterBytes,
      'image/jpeg',
    );

    await postPipeline(authorizeUrl, {
      action: 'complete',
      job_id: jobId,
      token,
      source_size_bytes: sourceSize,
      output_size_bytes: videoInfo.size,
    });
    progressiveCompleted = true;
    console.log(
      '[studio-render-node] ready',
      jobId,
      videoInfo.size,
      `${FPS}fps`,
      manifest.audioPreset,
    );
  } catch (error) {
    const message = compactError(error);
    if (!progressiveCompleted) {
      try {
        await postPipeline(authorizeUrl, {
          action: 'fail',
          job_id: jobId,
          token,
          error: message,
        });
      } catch (_) {}
    }
    console.error('[studio-render-node]', jobId, message);
  } finally {
    await Promise.all([
      ...imagePaths.map((path) => rm(path, { force: true }).catch(() => {})),
      ...shotPaths.map((path) => rm(path, { force: true }).catch(() => {})),
      rm(outputPath, { force: true }).catch(() => {}),
      rm(posterPath, { force: true }).catch(() => {}),
      rm(audioPath, { force: true }).catch(() => {}),
    ]);
  }
}

export default async function handler(request, response) {
  const method = String(request.method ?? 'GET').toUpperCase();
  if (method === 'GET') {
    sendJson(response, {
      ok: true,
      service: 'swipess-studio-render-30fps',
      ffmpeg: Boolean(ffmpegPath),
      fps: FPS,
      width: WIDTH,
      height: HEIGHT,
      motion: 'oversampled-stable',
      audio: 'mixed-aac',
    });
    return;
  }
  if (method !== 'POST') {
    sendJson(response, { ok: false, error: 'method_not_allowed' }, 405);
    return;
  }

  let job;
  try {
    job = assertJob(request.body ?? {});
  } catch (error) {
    sendJson(response, { ok: false, error: compactError(error) }, 400);
    return;
  }

  waitUntil(processJob(job));
  sendJson(response, { ok: true, accepted: job.jobId, renderer: 'native_30fps_audio_v3' }, 202);
}
