import { createClient } from '@supabase/supabase-js';
import { waitUntil } from '@vercel/functions';
import ffmpegPath from 'ffmpeg-static';
import { createWriteStream } from 'node:fs';
import { mkdtemp, readdir, readFile, rm, stat, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';

const PROJECT_HOST = 'vplgtcguxujxwrgguxqq.supabase.co';
const PIPELINE_URL = `https://${PROJECT_HOST}/functions/v1/video-pipeline`;
const HLS_CONTROL_URL = `https://${PROJECT_HOST}/functions/v1/video-hls-control`;
const MAX_SOURCE_BYTES = 64 * 1024 * 1024;
const MAX_ERROR_CHARS = 1400;

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
    },
  });
}

function compactError(error) {
  const value = error instanceof Error ? error.message : String(error ?? 'unknown_error');
  return value.slice(0, MAX_ERROR_CHARS);
}

function assertPayload(payload) {
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
    throw new Error(`pipeline_${response.status}:${String(data?.error ?? data?.raw ?? 'request_failed')}`);
  }
  return data;
}

async function downloadToFile(url, path) {
  const parsed = new URL(url);
  if (parsed.protocol !== 'https:' || parsed.host !== PROJECT_HOST) {
    throw new Error('source_host_not_allowed');
  }

  const response = await fetch(url, {
    redirect: 'follow',
    headers: { 'accept-encoding': 'identity' },
  });
  if (!response.ok || !response.body) {
    throw new Error(`source_download_${response.status}`);
  }

  const declared = Number(response.headers.get('content-length') ?? 0);
  if (declared > MAX_SOURCE_BYTES) throw new Error('source_too_large');

  let received = 0;
  const limiter = new TransformStream({
    transform(chunk, controller) {
      received += chunk.byteLength;
      if (received > MAX_SOURCE_BYTES) throw new Error('source_too_large');
      controller.enqueue(chunk);
    },
  });

  const nodeStream = Readable.fromWeb(response.body.pipeThrough(limiter));
  await pipeline(nodeStream, createWriteStream(path));
  return received;
}

function runFfmpeg(args, timeoutMs = 240000) {
  if (!ffmpegPath) return Promise.reject(new Error('ffmpeg_binary_missing'));
  return new Promise((resolve, reject) => {
    const child = spawn(ffmpegPath, args, {
      stdio: ['ignore', 'ignore', 'pipe'],
    });
    let stderr = '';
    const timer = setTimeout(() => {
      child.kill('SIGKILL');
      reject(new Error('ffmpeg_timeout'));
    }, timeoutMs);

    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
      if (stderr.length > 16000) stderr = stderr.slice(-16000);
    });
    child.once('error', (error) => {
      clearTimeout(timer);
      reject(error);
    });
    child.once('close', (code) => {
      clearTimeout(timer);
      if (code === 0) resolve();
      else reject(new Error(`ffmpeg_exit_${code}:${stderr.slice(-2200)}`));
    });
  });
}

async function transcode(inputPath, outputPath) {
  await runFfmpeg([
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    '-i',
    inputPath,
    '-t',
    '60',
    '-map',
    '0:v:0',
    '-map',
    '0:a:0?',
    '-vf',
    'scale=1280:1280:force_original_aspect_ratio=decrease:force_divisible_by=2,setsar=1',
    // Normalize variable-rate browser exports to a predictable delivery clock.
    // This cannot invent frames that were already dropped, but it prevents the
    // player from stuttering through irregular timestamps on every device.
    '-r',
    '30',
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
    '22',
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
    '128k',
    '-ar',
    '48000',
    '-ac',
    '2',
    '-movflags',
    '+faststart',
    outputPath,
  ]);
}

async function makePoster(videoPath, posterPath) {
  await runFfmpeg([
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
    'scale=720:720:force_original_aspect_ratio=decrease:force_divisible_by=2',
    '-q:v',
    '3',
    posterPath,
  ], 45000);
}

async function makeHlsVariant(videoPath, hlsDir, config) {
  const playlistPath = join(hlsDir, `${config.name}.m3u8`);
  const segmentPattern = join(hlsDir, `${config.name}_%03d.ts`);
  await runFfmpeg([
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    '-i',
    videoPath,
    '-map',
    '0:v:0',
    '-map',
    '0:a:0?',
    '-vf',
    `scale=${config.box}:${config.box}:force_original_aspect_ratio=decrease:force_divisible_by=2,setsar=1`,
    '-r',
    '30',
    '-fps_mode',
    'cfr',
    '-c:v',
    'libx264',
    '-preset',
    'veryfast',
    '-profile:v',
    'main',
    '-pix_fmt',
    'yuv420p',
    '-b:v',
    config.videoBitrate,
    '-maxrate',
    config.maxRate,
    '-bufsize',
    config.bufferSize,
    '-g',
    '60',
    '-keyint_min',
    '60',
    '-sc_threshold',
    '0',
    '-c:a',
    'aac',
    '-b:a',
    config.audioBitrate,
    '-ar',
    '48000',
    '-ac',
    '2',
    '-hls_time',
    '2',
    '-hls_playlist_type',
    'vod',
    '-hls_flags',
    'independent_segments',
    '-hls_segment_filename',
    segmentPattern,
    playlistPath,
  ], 240000);
}

async function makeAdaptiveHls(videoPath, hlsDir) {
  const variants = [
    {
      name: '360',
      box: 640,
      videoBitrate: '600k',
      maxRate: '750k',
      bufferSize: '1200k',
      audioBitrate: '64k',
    },
    {
      name: '540',
      box: 960,
      videoBitrate: '1250k',
      maxRate: '1550k',
      bufferSize: '2500k',
      audioBitrate: '96k',
    },
    {
      name: '720',
      box: 1280,
      videoBitrate: '2400k',
      maxRate: '2900k',
      bufferSize: '4800k',
      audioBitrate: '128k',
    },
  ];

  // Encode sequentially. This deliberately trades a few seconds of background
  // processing for bounded CPU/RAM so several uploads cannot thrash the worker.
  for (const variant of variants) {
    await makeHlsVariant(videoPath, hlsDir, variant);
  }

  const master = [
    '#EXTM3U',
    '#EXT-X-VERSION:3',
    '#EXT-X-INDEPENDENT-SEGMENTS',
    '#EXT-X-STREAM-INF:BANDWIDTH=750000,AVERAGE-BANDWIDTH=650000',
    '360.m3u8',
    '#EXT-X-STREAM-INF:BANDWIDTH=1500000,AVERAGE-BANDWIDTH=1350000',
    '540.m3u8',
    '#EXT-X-STREAM-INF:BANDWIDTH=2900000,AVERAGE-BANDWIDTH=2550000',
    '720.m3u8',
    '',
  ].join('\n');
  await writeFile(join(hlsDir, 'master.m3u8'), master, 'utf8');
}

async function publishAdaptiveHls({ jobId, token, hlsDir }) {
  const names = (await readdir(hlsDir)).filter(
    (name) => name.endsWith('.m3u8') || name.endsWith('.ts'),
  ).sort();
  if (!names.includes('master.m3u8')) throw new Error('hls_master_missing');

  const files = [];
  let totalSize = 0;
  for (const name of names) {
    const bytes = await readFile(join(hlsDir, name));
    totalSize += bytes.length;
    files.push({ name, bytes });
  }

  const authorization = await postPipeline(HLS_CONTROL_URL, {
    action: 'authorize',
    job_id: jobId,
    token,
    files: files.map((file) => ({ name: file.name })),
  });

  const storageUrl = String(authorization.storage_url ?? '');
  const storageKey = String(authorization.storage_anon_key ?? '');
  const bucket = String(authorization.bucket ?? '');
  const uploads = Array.isArray(authorization.uploads) ? authorization.uploads : [];
  const parsedStorage = new URL(storageUrl);
  if (parsedStorage.protocol !== 'https:' || parsedStorage.host !== PROJECT_HOST) {
    throw new Error('hls_storage_host_not_allowed');
  }
  if (!storageKey || bucket !== 'listing-videos') {
    throw new Error('invalid_hls_storage_authorization');
  }

  const signedByName = new Map(uploads.map((item) => [String(item.name), item]));
  const supabase = createClient(storageUrl, storageKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Upload in small groups: enough parallelism for segments without exploding
  // sockets/memory when several listings are processing at once.
  for (let offset = 0; offset < files.length; offset += 6) {
    const batch = files.slice(offset, offset + 6);
    await Promise.all(batch.map(async (file) => {
      const signed = signedByName.get(file.name);
      if (!signed?.path || !signed?.token || !signed?.content_type) {
        throw new Error(`missing_hls_upload:${file.name}`);
      }
      await uploadSigned(
        supabase.storage,
        bucket,
        String(signed.path),
        String(signed.token),
        file.bytes,
        String(signed.content_type),
      );
    }));
  }

  await postPipeline(HLS_CONTROL_URL, {
    action: 'complete',
    job_id: jobId,
    token,
    total_size_bytes: totalSize,
    output_count: files.length,
  });
}

async function uploadSigned(storage, bucket, path, token, bytes, contentType) {
  const { error } = await storage
    .from(bucket)
    .uploadToSignedUrl(path, token, bytes, {
      contentType,
      cacheControl: '31536000',
    });
  if (error) throw new Error(`storage_upload:${error.message}`);
}

async function processJob({ jobId, token, authorizeUrl }) {
  const tempId = randomUUID();
  const inputPath = join(tmpdir(), `swipess-source-${tempId}`);
  const outputPath = join(tmpdir(), `swipess-playback-${tempId}.mp4`);
  const posterPath = join(tmpdir(), `swipess-poster-${tempId}.jpg`);
  let hlsDir = null;
  let progressiveCompleted = false;

  try {
    hlsDir = await mkdtemp(join(tmpdir(), 'swipess-hls-'));
    const authorization = await postPipeline(authorizeUrl, {
      action: 'authorize',
      job_id: jobId,
      token,
    });

    const storageUrl = String(authorization.storage_url ?? '');
    const storageKey = String(authorization.storage_anon_key ?? '');
    const bucket = String(authorization.bucket ?? '');
    const sourceUrl = String(authorization.source_url ?? '');
    const videoPath = String(authorization.video_path ?? '');
    const videoToken = String(authorization.video_token ?? '');
    const posterObjectPath = String(authorization.poster_path ?? '');
    const posterToken = String(authorization.poster_token ?? '');

    const parsedStorage = new URL(storageUrl);
    if (parsedStorage.protocol !== 'https:' || parsedStorage.host !== PROJECT_HOST) {
      throw new Error('storage_host_not_allowed');
    }
    if (!storageKey || bucket !== 'listing-videos') throw new Error('invalid_storage_authorization');
    if (!videoPath.startsWith('processed/') || !posterObjectPath.startsWith('processed/')) {
      throw new Error('invalid_output_path');
    }

    const sourceSize = await downloadToFile(sourceUrl, inputPath);
    await transcode(inputPath, outputPath);
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
    await uploadSigned(supabase.storage, bucket, posterObjectPath, posterToken, posterBytes, 'image/jpeg');

    await postPipeline(authorizeUrl, {
      action: 'complete',
      job_id: jobId,
      token,
      source_size_bytes: sourceSize,
      output_size_bytes: videoInfo.size,
    });
    progressiveCompleted = true;

    // Adaptive output is additive. A transient HLS problem must never make
    // the already-uploaded fast-start MP4 unavailable to the listing.
    try {
      await makeAdaptiveHls(outputPath, hlsDir);
      await publishAdaptiveHls({ jobId, token, hlsDir });
    } catch (hlsError) {
      console.warn('[video-hls]', jobId, compactError(hlsError));
    }
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
      } catch (_) {
        // The original failure is the useful error. A failed callback is visible
        // in runtime logs and must not recursively retry from the worker.
      }
    }
    console.error('[video-transcode]', jobId, message);
  } finally {
    await Promise.all([
      rm(inputPath, { force: true }).catch(() => {}),
      rm(outputPath, { force: true }).catch(() => {}),
      rm(posterPath, { force: true }).catch(() => {}),
      hlsDir
        ? rm(hlsDir, { recursive: true, force: true }).catch(() => {})
        : Promise.resolve(),
    ]);
  }
}

export default {
  async fetch(request) {
    if (request.method === 'GET') {
      return json({ ok: true, service: 'swipess-video-transcode', ffmpeg: Boolean(ffmpegPath) });
    }
    if (request.method !== 'POST') return json({ ok: false, error: 'method_not_allowed' }, 405);

    let payload;
    try {
      payload = await request.json();
    } catch (_) {
      return json({ ok: false, error: 'invalid_json' }, 400);
    }

    let job;
    try {
      job = assertPayload(payload);
    } catch (error) {
      return json({ ok: false, error: compactError(error) }, 400);
    }

    waitUntil(processJob(job));
    return json({ ok: true, accepted: job.jobId }, 202);
  },
};
