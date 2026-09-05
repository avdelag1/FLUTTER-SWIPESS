import { createClient } from '@supabase/supabase-js';
import { waitUntil } from '@vercel/functions';
import ffmpegPath from 'ffmpeg-static';
import { createWriteStream } from 'node:fs';
import { readFile, rm, stat } from 'node:fs/promises';
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
  return { imageUrls, shots };
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
  const cropX = `(iw-${WIDTH})*${ffNumber(shot.focalX)}`;
  const cropY = `(ih-${HEIGHT})*${ffNumber(shot.focalY)}`;
  const filter =
    `scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=increase:force_divisible_by=2,` +
    `crop=${WIDTH}:${HEIGHT}:'max(0,min(iw-${WIDTH},${cropX}))':'max(0,min(ih-${HEIGHT},${cropY}))',` +
    `setsar=1,` +
    `zoompan=z='${zoom}':x='(iw-iw/zoom)*${panX}':y='(ih-ih/zoom)*${panY}':` +
    `d=${frameCount}:s=${WIDTH}x${HEIGHT}:fps=${FPS},fps=${FPS},format=yuv420p`;

  await runFfmpeg([
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    '-i',
    imagePath,
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
    '-profile:v',
    'high',
    '-level:v',
    '4.1',
    '-pix_fmt',
    'yuv420p',
    '-crf',
    '22',
    '-g',
    '60',
    '-keyint_min',
    '60',
    '-sc_threshold',
    '0',
    shotPath,
  ]);
}

async function composeShots(shotPaths, shots, outputPath) {
  const args = ['-hide_banner', '-loglevel', 'error', '-y'];
  for (const path of shotPaths) args.push('-i', path);

  const filters = [];
  let current = '0:v';
  let timeline = shots[0].duration;
  for (let index = 1; index < shots.length; index += 1) {
    const previousShot = shots[index - 1];
    let transitionDuration = Math.min(
      previousShot.transitionSeconds,
      previousShot.duration * 0.45,
      shots[index].duration * 0.45,
    );
    if (previousShot.transition === 'hardCut') transitionDuration = 1 / FPS;
    transitionDuration = Math.max(1 / FPS, transitionDuration);
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

  args.push(
    '-filter_complex',
    filters.join(';'),
    '-map',
    '[outv]',
    '-an',
    '-r',
    String(FPS),
    '-fps_mode',
    'cfr',
    '-c:v',
    'libx264',
    '-preset',
    'veryfast',
    '-profile:v',
    'high',
    '-level:v',
    '4.1',
    '-pix_fmt',
    'yuv420p',
    '-crf',
    '21',
    '-maxrate',
    '5500k',
    '-bufsize',
    '11000k',
    '-g',
    '60',
    '-keyint_min',
    '60',
    '-sc_threshold',
    '0',
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
      'scale=720:1280:force_original_aspect_ratio=increase,crop=720:1280',
      '-q:v',
      '3',
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

    await composeShots(shotPaths, manifest.shots, outputPath);
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
    console.log('[studio-render-node] ready', jobId, videoInfo.size);
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
  sendJson(response, { ok: true, accepted: job.jobId, renderer: 'native_30fps' }, 202);
}
