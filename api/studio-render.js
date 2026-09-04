import { createClient } from '@supabase/supabase-js';
import ffmpegPath from 'ffmpeg-static';
import { createWriteStream } from 'node:fs';
import { readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';

const PROJECT_HOST = 'vplgtcguxujxwrgguxqq.supabase.co';
const MAX_IMAGE_BYTES = 10 * 1024 * 1024;
const MAX_IMAGES = 6;
const MIN_IMAGES = 3;
const OUTPUT_WIDTH = 1080;
const OUTPUT_HEIGHT = 1920;
const OUTPUT_FPS = 30;
const MAX_TOTAL_SECONDS = 30;
const ALLOWED_TRANSITIONS = new Set([
  'crossFade',
  'hardCut',
  'pushLeft',
  'pushUp',
  'splitVertical',
  'splitHorizontal',
]);
const ALLOWED_EASING = new Set(['linear', 'easeIn', 'easeOut', 'easeInOut']);
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

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
    },
  });
}

function finite(value, fallback, min, max) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.min(max, Math.max(min, number));
}

function assertUrl(raw, userId) {
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
  const transition = String(raw?.transition ?? 'crossFade');
  const easing = String(raw?.easing ?? 'easeInOut');
  if (!ALLOWED_TRANSITIONS.has(transition)) throw new Error(`invalid_transition_${index}`);
  if (!ALLOWED_EASING.has(easing)) throw new Error(`invalid_easing_${index}`);
  const startPosition = raw?.start_position ?? {};
  const endPosition = raw?.end_position ?? {};
  const focal = raw?.focal ?? {};
  return {
    duration: finite(raw?.duration, 3, 1.2, 6),
    startScale: finite(raw?.start_scale, 1.04, 1.0, 1.3),
    endScale: finite(raw?.end_scale, 1.12, 1.0, 1.3),
    startX: finite(startPosition?.x, 0, -.18, .18),
    startY: finite(startPosition?.y, 0, -.18, .18),
    endX: finite(endPosition?.x, 0, -.18, .18),
    endY: finite(endPosition?.y, 0, -.18, .18),
    easing,
    transition,
    transitionDuration: finite(raw?.transition_duration, .45, .04, .9),
    focalX: finite(focal?.x, .5, 0, 1),
    focalY: finite(focal?.y, .5, 0, 1),
  };
}

function assertPayload(payload) {
  const userId = String(payload?.user_id ?? '');
  if (!/^[0-9a-f-]{36}$/i.test(userId)) throw new Error('invalid_user_id');
  const rawImages = Array.isArray(payload?.image_urls) ? payload.image_urls : [];
  if (rawImages.length < MIN_IMAGES || rawImages.length > MAX_IMAGES) {
    throw new Error('studio_requires_3_to_6_images');
  }
  const imageUrls = rawImages.map((url) => assertUrl(url, userId));
  const template = payload?.template ?? {};
  if (Number(template?.width) !== OUTPUT_WIDTH || Number(template?.height) !== OUTPUT_HEIGHT) {
    throw new Error('invalid_studio_output_size');
  }
  if (Number(template?.fps) !== OUTPUT_FPS) throw new Error('invalid_studio_fps');
  const rawShots = Array.isArray(template?.shots) ? template.shots : [];
  if (rawShots.length !== imageUrls.length) throw new Error('studio_shot_count_mismatch');
  const shots = rawShots.map(sanitizeShot);
  const totalDuration = shots.reduce((sum, shot) => sum + shot.duration, 0);
  if (totalDuration > MAX_TOTAL_SECONDS) throw new Error('studio_video_too_long');

  const audioPreset = String(payload?.audio_preset ?? template?.audio_preset ?? 'clean_ambient');
  if (!ALLOWED_AUDIO.has(audioPreset)) throw new Error('invalid_audio_preset');

  const output = payload?.output ?? {};
  const storageUrl = String(output?.storage_url ?? '');
  const storageAnonKey = String(output?.storage_anon_key ?? '');
  const bucket = String(output?.bucket ?? '');
  const videoPath = String(output?.video_path ?? '');
  const videoToken = String(output?.video_token ?? '');
  const posterPath = String(output?.poster_path ?? '');
  const posterToken = String(output?.poster_token ?? '');
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
    totalDuration,
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

async function downloadToFile(url, path) {
  const response = await fetch(url, {
    redirect: 'follow',
    headers: { 'accept-encoding': 'identity' },
  });
  if (!response.ok || !response.body) throw new Error(`studio_image_download_${response.status}`);
  const declared = Number(response.headers.get('content-length') ?? 0);
  if (declared > MAX_IMAGE_BYTES) throw new Error('studio_image_too_large');
  let received = 0;
  const limiter = new TransformStream({
    transform(chunk, controller) {
      received += chunk.byteLength;
      if (received > MAX_IMAGE_BYTES) throw new Error('studio_image_too_large');
      controller.enqueue(chunk);
    },
  });
  await pipeline(
    Readable.fromWeb(response.body.pipeThrough(limiter)),
    createWriteStream(path),
  );
}

function runFfmpeg(args, timeoutMs = 280000) {
  if (!ffmpegPath) return Promise.reject(new Error('ffmpeg_binary_missing'));
  return new Promise((resolve, reject) => {
    const child = spawn(ffmpegPath, args, { stdio: ['ignore', 'ignore', 'pipe'] });
    let stderr = '';
    const timer = setTimeout(() => {
      child.kill('SIGKILL');
      reject(new Error('studio_ffmpeg_timeout'));
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
      else reject(new Error(`studio_ffmpeg_exit_${code}:${stderr.slice(-2600)}`));
    });
  });
}

function easingExpr(kind, t) {
  switch (kind) {
    case 'linear':
      return t;
    case 'easeIn':
      return `pow(${t},3)`;
    case 'easeOut':
      return `(1-pow(1-${t},3))`;
    case 'easeInOut':
    default:
      return `((${t})*(${t})*(3-2*(${t})))`;
  }
}

function lerpExpr(start, end, t) {
  const delta = end - start;
  return `(${start.toFixed(6)}+(${delta.toFixed(6)})*(${t}))`;
}

function transitionName(kind) {
  switch (kind) {
    case 'pushLeft':
      return 'slideleft';
    case 'pushUp':
      return 'slideup';
    case 'splitVertical':
      return 'vertopen';
    case 'splitHorizontal':
      return 'horzopen';
    case 'hardCut':
      return 'fadefast';
    case 'crossFade':
    default:
      return 'fade';
  }
}

function buildFilter(shots) {
  const filters = [];
  for (let i = 0; i < shots.length; i += 1) {
    const shot = shots[i];
    const frames = Math.max(2, Math.round(shot.duration * OUTPUT_FPS));
    const t = `min(1,on/${Math.max(1, frames - 1)})`;
    const eased = easingExpr(shot.easing, t);
    const zoom = lerpExpr(shot.startScale, shot.endScale, eased);
    const travelX = lerpExpr(shot.startX, shot.endX, eased);
    const travelY = lerpExpr(shot.startY, shot.endY, eased);
    const x = `max(0,min(iw-iw/zoom,iw/2-(iw/zoom/2)+(${travelX})*(iw-iw/zoom)))`;
    const y = `max(0,min(ih-ih/zoom,ih/2-(ih/zoom/2)+(${travelY})*(ih-ih/zoom)))`;
    const cropX = `min(max(iw*${shot.focalX.toFixed(6)}-ow/2,0),iw-ow)`;
    const cropY = `min(max(ih*${shot.focalY.toFixed(6)}-oh/2,0),ih-oh)`;
    filters.push(
      `[${i}:v]` +
        `scale=1350:2400:force_original_aspect_ratio=increase,` +
        `crop=1350:2400:x='${cropX}':y='${cropY}',` +
        `setsar=1,` +
        `zoompan=z='${zoom}':x='${x}':y='${y}':d=${frames}:s=${OUTPUT_WIDTH}x${OUTPUT_HEIGHT}:fps=${OUTPUT_FPS},` +
        `fps=${OUTPUT_FPS},settb=AVTB,trim=duration=${shot.duration.toFixed(3)},` +
        `setpts=PTS-STARTPTS,format=yuv420p[v${i}]`,
    );
  }

  let active = 'v0';
  let timeline = shots[0].duration;
  for (let i = 1; i < shots.length; i += 1) {
    const previous = shots[i - 1];
    const duration = previous.transition === 'hardCut'
      ? .04
      : Math.min(previous.transitionDuration, previous.duration * .35, shots[i].duration * .35);
    const offset = Math.max(.01, timeline - duration);
    const raw = `mixRaw${i}`;
    const out = `mix${i}`;
    filters.push(
      `[${active}][v${i}]xfade=transition=${transitionName(previous.transition)}:` +
        `duration=${duration.toFixed(3)}:offset=${offset.toFixed(3)}[${raw}]`,
    );
    filters.push(
      `[${raw}]fps=${OUTPUT_FPS},settb=AVTB,setpts=PTS-STARTPTS,format=yuv420p[${out}]`,
    );
    active = out;
    timeline += shots[i].duration - duration;
  }
  filters.push(`[${active}]fps=${OUTPUT_FPS},settb=AVTB,format=yuv420p[vout]`);
  return { filter: filters.join(';'), duration: timeline };
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

async function renderVideo(imagePaths, shots, audioPath, outputPath) {
  const inputs = [];
  for (let i = 0; i < imagePaths.length; i += 1) {
    // image2 stills have no meaningful frame-rate metadata unless we provide
    // one. xfade requires every input to be CFR, so loop each source photo
    // on an explicit 30fps clock and bound it slightly beyond its shot.
    inputs.push(
      '-loop', '1',
      '-framerate', String(OUTPUT_FPS),
      '-t', (shots[i].duration + 0.25).toFixed(3),
      '-i', imagePaths[i],
    );
  }
  inputs.push('-stream_loop', '-1', '-i', audioPath);
  const { filter, duration } = buildFilter(shots);
  await runFfmpeg([
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    ...inputs,
    '-filter_complex',
    filter,
    '-map',
    '[vout]',
    '-map',
    `${imagePaths.length}:a:0`,
    '-t',
    duration.toFixed(3),
    '-r',
    String(OUTPUT_FPS),
    '-fps_mode',
    'cfr',
    '-c:v',
    'libx264',
    '-preset',
    'veryfast',
    '-profile:v',
    'high',
    '-level:v',
    '4.0',
    '-pix_fmt',
    'yuv420p',
    '-crf',
    '21',
    '-maxrate',
    '6000k',
    '-bufsize',
    '12000k',
    '-g',
    '60',
    '-keyint_min',
    '60',
    '-sc_threshold',
    '0',
    '-c:a',
    'aac',
    '-b:a',
    '128k',
    '-ar',
    '48000',
    '-ac',
    '2',
    '-movflags',
    '+faststart',
    outputPath,
  ]);
  return duration;
}

async function makePoster(videoPath, posterPath) {
  await runFfmpeg([
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    '-ss',
    '.45',
    '-i',
    videoPath,
    '-frames:v',
    '1',
    '-vf',
    'scale=540:960:force_original_aspect_ratio=decrease',
    '-q:v',
    '3',
    posterPath,
  ], 45000);
}

async function uploadSigned(storage, bucket, path, token, bytes, contentType) {
  const { error } = await storage
    .from(bucket)
    .uploadToSignedUrl(path, token, bytes, {
      contentType,
      cacheControl: '31536000',
    });
  if (error) throw new Error(`studio_storage_upload:${error.message}`);
}

async function handler(request) {
  if (request.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  let payload;
  try {
    payload = await request.json();
  } catch (_) {
    return json({ error: 'invalid_json' }, 400);
  }

  let input;
  try {
    input = assertPayload(payload);
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : String(error) }, 400);
  }

  const id = randomUUID();
  const imagePaths = input.imageUrls.map((_, index) => join(tmpdir(), `studio-${id}-${index}.img`));
  const audioPath = join(tmpdir(), `studio-${id}.wav`);
  const videoPath = join(tmpdir(), `studio-${id}.mp4`);
  const posterPath = join(tmpdir(), `studio-${id}.jpg`);

  try {
    // Sequential downloads keep memory and socket pressure predictable on the
    // 2-core Vercel worker. Rendering remains bounded to six source photos.
    for (let i = 0; i < input.imageUrls.length; i += 1) {
      await downloadToFile(input.imageUrls[i], imagePaths[i]);
    }
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

    return json({
      ok: true,
      duration_seconds: duration,
      video_size_bytes: videoBytes.length,
      poster_size_bytes: posterBytes.length,
    });
  } catch (error) {
    console.error('[studio-render]', error);
    return json(
      { error: error instanceof Error ? error.message.slice(0, 1400) : String(error).slice(0, 1400) },
      500,
    );
  } finally {
    await Promise.allSettled([
      ...imagePaths.map((path) => rm(path, { force: true })),
      rm(audioPath, { force: true }),
      rm(videoPath, { force: true }),
      rm(posterPath, { force: true }),
    ]);
  }
}

export default handler;
