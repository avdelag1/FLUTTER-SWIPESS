import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.4";
import { Image, Frame, GIF } from "https://deno.land/x/imagescript@1.2.15/mod.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const IMAGE_BUCKET = "listing-images";
const VIDEO_BUCKET = "listing-videos";
const VIDEO_WORKER_URL = Deno.env.get("VIDEO_TRANSCODER_URL") ?? "https://www.swipess.com/api/video-transcode";
const PIPELINE_URL = `${SUPABASE_URL}/functions/v1/video-pipeline`;
const MIN_IMAGES = 3;
const MAX_IMAGES = 6;
const SOURCE_WIDTH = 320;
const SOURCE_HEIGHT = 568;
const FRAMES_PER_SHOT = 4;
const MAX_IMAGE_BYTES = 10 * 1024 * 1024;
const ALLOWED_AUDIO = new Set([
  "ocean",
  "chill",
  "singing_bowl",
  "om_drone",
  "jungle",
  "luxury",
  "road",
  "workshop",
  "clean_ambient",
  "night_beach",
]);

const fallbackAllowedHeaders = [
  "authorization",
  "x-client-info",
  "apikey",
  "content-type",
  "x-supabase-api-version",
  "x-supabase-client-platform",
  "x-supabase-client-platform-version",
  "x-supabase-client-runtime",
  "x-supabase-client-runtime-version",
].join(", ");

function corsHeaders(req?: Request) {
  const requestedHeaders = req?.headers.get("Access-Control-Request-Headers")?.trim();
  const origin = req?.headers.get("Origin")?.trim() || "*";
  const privateNetwork = req?.headers
    .get("Access-Control-Request-Private-Network")
    ?.trim()
    .toLowerCase() === "true";
  const headers: Record<string, string> = {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Headers": requestedHeaders || fallbackAllowedHeaders,
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Credentials": "true",
    "Access-Control-Max-Age": "600",
    "Access-Control-Expose-Headers": "content-type, x-request-id",
    "Vary": "Origin, Access-Control-Request-Method, Access-Control-Request-Headers",
  };
  if (privateNetwork) headers["Access-Control-Allow-Private-Network"] = "true";
  return headers;
}

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

function json(data: unknown, status = 200, req?: Request) {
  return Response.json(data, {
    status,
    headers: { ...corsHeaders(req), "Cache-Control": "no-store" },
  });
}

function cleanError(value: unknown) {
  return (value instanceof Error ? value.message : String(value ?? "unknown_error")).slice(0, 1400);
}

function finite(value: unknown, fallback: number, min: number, max: number) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, parsed));
}

function clamp(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value));
}

function lerp(start: number, end: number, t: number) {
  return start + (end - start) * t;
}

function ease(kind: string, value: number) {
  const t = clamp(value, 0, 1);
  switch (kind) {
    case "linear":
      return t;
    case "easeIn":
      return t * t * t;
    case "easeOut": {
      const inverse = 1 - t;
      return 1 - inverse * inverse * inverse;
    }
    case "easeInOut":
    default:
      return t * t * (3 - 2 * t);
  }
}

function randomToken(bytes = 32) {
  const raw = new Uint8Array(bytes);
  crypto.getRandomValues(raw);
  return Array.from(raw, (b) => b.toString(16).padStart(2, "0")).join("");
}

async function authenticatedUser(req: Request) {
  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.toLowerCase().startsWith("bearer ")) return null;
  const token = authorization.slice(7).trim();
  if (!token) return null;
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) return null;
  return data.user;
}

function storagePathFromPublicUrl(raw: string, bucket: string): string | null {
  try {
    const parsed = new URL(raw);
    const expectedHost = new URL(SUPABASE_URL).host;
    if (parsed.protocol !== "https:" || parsed.host !== expectedHost) return null;
    const marker = `/storage/v1/object/public/${bucket}/`;
    const index = parsed.pathname.indexOf(marker);
    if (index < 0) return null;
    return decodeURIComponent(parsed.pathname.slice(index + marker.length));
  } catch (_) {
    return null;
  }
}

function studioOutputPathForUser(raw: unknown, userId: string): string | null {
  const value = String(raw ?? "").trim();
  if (!value) return null;
  const path = storagePathFromPublicUrl(value, VIDEO_BUCKET);
  if (!path) return null;
  if (path.startsWith(`processed/studio/${userId}/`)) return path;
  if (path.startsWith(`generated/${userId}/`)) return path;
  return null;
}

function validateImages(raw: unknown, userId: string): string[] {
  if (!Array.isArray(raw) || raw.length < MIN_IMAGES || raw.length > MAX_IMAGES) {
    throw new Error("studio_requires_3_to_6_images");
  }
  return raw.map((value) => {
    const url = String(value ?? "").trim();
    const path = storagePathFromPublicUrl(url, IMAGE_BUCKET);
    if (!path || !path.startsWith(`${userId}/`)) {
      throw new Error("studio_image_not_owned_by_user");
    }
    return url;
  });
}

function validateTemplate(raw: unknown, photoCount: number) {
  if (!raw || typeof raw !== "object") throw new Error("studio_template_required");
  const template = raw as Record<string, unknown>;
  if (Number(template.width) !== 1080 || Number(template.height) !== 1920) {
    throw new Error("invalid_studio_output_size");
  }
  if (Number(template.fps) !== 30) throw new Error("invalid_studio_fps");
  const shots = Array.isArray(template.shots) ? template.shots : [];
  if (shots.length !== photoCount) throw new Error("studio_shot_count_mismatch");
  return template;
}

function expectedDuration(template: Record<string, unknown>) {
  const shots = Array.isArray(template.shots) ? template.shots : [];
  return shots.reduce((sum, shot) => {
    const duration = Number((shot as Record<string, unknown>)?.duration ?? 0);
    return sum + (Number.isFinite(duration) ? clamp(duration, 1.2, 6) : 3);
  }, 0);
}

type Shot = {
  duration: number;
  startScale: number;
  endScale: number;
  startX: number;
  startY: number;
  endX: number;
  endY: number;
  focalX: number;
  focalY: number;
  easing: string;
};

function sanitizeShot(raw: unknown): Shot {
  const shot = raw && typeof raw === "object" ? raw as Record<string, unknown> : {};
  const start = shot.start_position && typeof shot.start_position === "object"
    ? shot.start_position as Record<string, unknown>
    : {};
  const end = shot.end_position && typeof shot.end_position === "object"
    ? shot.end_position as Record<string, unknown>
    : {};
  const focal = shot.focal && typeof shot.focal === "object"
    ? shot.focal as Record<string, unknown>
    : {};
  return {
    duration: finite(shot.duration, 3, 1.2, 6),
    startScale: finite(shot.start_scale, 1.04, 1, 1.3),
    endScale: finite(shot.end_scale, 1.12, 1, 1.3),
    startX: finite(start.x, 0, -0.18, 0.18),
    startY: finite(start.y, 0, -0.18, 0.18),
    endX: finite(end.x, 0, -0.18, 0.18),
    endY: finite(end.y, 0, -0.18, 0.18),
    focalX: finite(focal.x, 0.5, 0, 1),
    focalY: finite(focal.y, 0.5, 0, 1),
    easing: String(shot.easing ?? "easeInOut"),
  };
}

async function downloadImage(url: string) {
  const response = await fetch(url, {
    redirect: "follow",
    headers: { "accept-encoding": "identity", "cache-control": "no-cache" },
  });
  if (!response.ok) throw new Error(`studio_image_download_${response.status}`);
  const declared = Number(response.headers.get("content-length") ?? 0);
  if (declared > MAX_IMAGE_BYTES) throw new Error("studio_image_too_large");
  const bytes = new Uint8Array(await response.arrayBuffer());
  if (bytes.byteLength > MAX_IMAGE_BYTES) throw new Error("studio_image_too_large");
  return bytes;
}

async function createAnimatedSource(
  imageUrls: string[],
  template: Record<string, unknown>,
) {
  const rawShots = Array.isArray(template.shots) ? template.shots : [];
  const shots = rawShots.map(sanitizeShot);
  const frames: Frame[] = [];

  for (let index = 0; index < imageUrls.length; index += 1) {
    const source = await Image.decode(await downloadImage(imageUrls[index]));
    const shot = shots[index];
    const frameCount = FRAMES_PER_SHOT;
    const delayMs = Math.max(120, Math.round((shot.duration * 1000) / frameCount));

    for (let frameIndex = 0; frameIndex < frameCount; frameIndex += 1) {
      const progress = frameCount <= 1 ? 1 : frameIndex / (frameCount - 1);
      const eased = ease(shot.easing, progress);
      const scale = Math.max(1.01, lerp(shot.startScale, shot.endScale, eased));
      const canvasWidth = Math.max(SOURCE_WIDTH + 2, Math.ceil(SOURCE_WIDTH * scale));
      const canvasHeight = Math.max(SOURCE_HEIGHT + 2, Math.ceil(SOURCE_HEIGHT * scale));
      const image = source.clone();
      image.cover(canvasWidth, canvasHeight);

      const maxX = Math.max(0, canvasWidth - SOURCE_WIDTH);
      const maxY = Math.max(0, canvasHeight - SOURCE_HEIGHT);
      const panX = lerp(shot.startX, shot.endX, eased);
      const panY = lerp(shot.startY, shot.endY, eased);
      const x = Math.round(clamp(shot.focalX * maxX + panX * maxX, 0, maxX));
      const y = Math.round(clamp(shot.focalY * maxY + panY * maxY, 0, maxY));
      image.crop(x, y, SOURCE_WIDTH, SOURCE_HEIGHT);
      frames.push(Frame.from(image, delayMs));
    }
  }

  if (frames.length < 1) throw new Error("studio_source_frames_empty");
  return await new GIF(frames, 1).encode(74);
}

type PreparedRender = {
  jobId: string;
  workerToken: string;
  workerPayload: Record<string, unknown>;
  sourcePath: string;
  videoPath: string;
  posterPath: string;
  videoUrl: string;
  posterUrl: string;
  durationSeconds: number;
  templateId: string;
  templateVersion: number;
  audioPreset: string;
};

async function prepareRender(
  body: Record<string, unknown>,
  userId: string,
): Promise<PreparedRender> {
  const imageUrls = validateImages(body.image_urls, userId);
  const template = validateTemplate(body.template, imageUrls.length);
  const project = body.project && typeof body.project === "object"
    ? body.project as Record<string, unknown>
    : {};
  const audioPresetRaw = String(project.audio_preset ?? template.audio_preset ?? "clean_ambient");
  const audioPreset = ALLOWED_AUDIO.has(audioPresetRaw) ? audioPresetRaw : "clean_ambient";
  const renderId = crypto.randomUUID();
  const sourcePath = `studio-source/${userId}/${renderId}.webm`;
  const videoPath = `processed/studio/${userId}/${renderId}.mp4`;
  const posterPath = `processed/studio/${userId}/${renderId}.jpg`;
  const videoUrl = admin.storage.from(VIDEO_BUCKET).getPublicUrl(videoPath).data.publicUrl;
  const posterUrl = admin.storage.from(VIDEO_BUCKET).getPublicUrl(posterPath).data.publicUrl;

  const sourceBytes = await createAnimatedSource(imageUrls, template);
  const { error: sourceUploadError } = await admin.storage
    .from(VIDEO_BUCKET)
    .upload(sourcePath, sourceBytes, {
      contentType: "video/webm",
      cacheControl: "3600",
      upsert: false,
    });
  if (sourceUploadError) throw new Error(`studio_source_upload:${sourceUploadError.message}`);

  const workerToken = randomToken();
  const durationSeconds = expectedDuration(template);
  const { data: job, error: jobError } = await admin
    .from("studio_video_jobs")
    .insert({
      owner_id: userId,
      source_path: sourcePath,
      source_url: admin.storage.from(VIDEO_BUCKET).getPublicUrl(sourcePath).data.publicUrl,
      worker_token: workerToken,
      video_path: videoPath,
      poster_path: posterPath,
      playback_url: videoUrl,
      poster_url: posterUrl,
      status: "queued",
      expected_duration_seconds: durationSeconds,
    })
    .select("id")
    .single();

  if (jobError || !job?.id) {
    await admin.storage.from(VIDEO_BUCKET).remove([sourcePath]).catch(() => {});
    throw new Error(`studio_job_insert:${jobError?.message ?? "missing_job_id"}`);
  }

  const workerPayload = {
    job_id: job.id,
    token: workerToken,
    authorize_url: PIPELINE_URL,
  };

  return {
    jobId: String(job.id),
    workerToken,
    workerPayload,
    sourcePath,
    videoPath,
    posterPath,
    videoUrl,
    posterUrl,
    durationSeconds,
    templateId: String(project.template_id ?? template.id ?? ""),
    templateVersion: Number(project.template_version ?? template.version ?? 1),
    audioPreset,
  };
}

function clientWorkerUrl(req?: Request) {
  const origin = req?.headers.get("Origin")?.trim();
  if (origin) {
    try {
      const parsed = new URL(origin);
      const host = parsed.hostname.toLowerCase();
      if (host === "swipess.com" || host === "www.swipess.com") {
        return `${parsed.origin}/api/video-transcode`;
      }
    } catch (_) {}
  }
  return VIDEO_WORKER_URL;
}

async function dispatchRender(prepared: PreparedRender) {
  let response: Response;
  try {
    response = await fetch(VIDEO_WORKER_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(prepared.workerPayload),
    });
  } catch (error) {
    const message = `studio_worker_unreachable:${cleanError(error)}`;
    await admin.from("studio_video_jobs").update({
      status: "failed",
      error: message,
      completed_at: new Date().toISOString(),
    }).eq("id", prepared.jobId);
    await admin.storage.from(VIDEO_BUCKET).remove([prepared.sourcePath]).catch(() => {});
    throw new Error(message);
  }

  const text = await response.text();
  let worker: Record<string, unknown> = {};
  try {
    worker = text ? JSON.parse(text) : {};
  } catch (_) {
    worker = { error: text };
  }
  if (!response.ok || worker.ok !== true) {
    const message = cleanError(worker.error ?? `studio_worker_${response.status}`);
    await admin.from("studio_video_jobs").update({
      status: "failed",
      error: message,
      completed_at: new Date().toISOString(),
    }).eq("id", prepared.jobId);
    await admin.storage.from(VIDEO_BUCKET).remove([prepared.sourcePath]).catch(() => {});
    throw new Error(message);
  }
  return worker;
}

async function cleanupGenerated(
  body: Record<string, unknown>,
  userId: string,
  req?: Request,
) {
  const videoRaw = String(body.video_url ?? "").trim();
  const posterRaw = String(body.poster_url ?? "").trim();
  const paths = new Set<string>();
  const videoPath = studioOutputPathForUser(videoRaw, userId);
  const posterPath = studioOutputPathForUser(posterRaw, userId);
  if (videoPath) paths.add(videoPath);
  if (posterPath) paths.add(posterPath);

  let sourcePath: string | null = null;
  if (videoRaw) {
    const { data: job } = await admin
      .from("studio_video_jobs")
      .select("id,source_path,status")
      .eq("owner_id", userId)
      .eq("playback_url", videoRaw)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (job?.source_path && String(job.source_path).startsWith(`studio-source/${userId}/`)) {
      sourcePath = String(job.source_path);
      paths.add(sourcePath);
    }
    if (job?.id && ["queued", "processing"].includes(String(job.status))) {
      await admin.from("studio_video_jobs").update({
        status: "failed",
        error: "cancelled_before_listing_publish",
        completed_at: new Date().toISOString(),
      }).eq("id", job.id);
    }
  }

  if (paths.size === 0) {
    return json({ ok: false, error: "studio_cleanup_path_invalid" }, 400, req);
  }
  const { error } = await admin.storage.from(VIDEO_BUCKET).remove([...paths]);
  if (error) return json({ ok: false, error: cleanError(error) }, 500, req);
  return json({ ok: true, removed: paths.size, source_removed: sourcePath != null }, 200, req);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: corsHeaders(req) });
  }
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !PIPELINE_URL) {
    return json({ ok: false, error: "server_configuration_missing" }, 500, req);
  }
  if (req.method === "GET") {
    return json({ ok: true, service: "studio-render", renderer: "imagescript-to-video-transcode-v1" }, 200, req);
  }
  if (req.method !== "POST") return json({ ok: false, error: "method_not_allowed" }, 405, req);

  const user = await authenticatedUser(req);
  if (!user) return json({ ok: false, error: "unauthorized" }, 401, req);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return json({ ok: false, error: "invalid_json" }, 400, req);
  }

  const action = String(body.action ?? "render");
  if (action === "cleanup") return cleanupGenerated(body, user.id, req);
  if (action !== "render" && action !== "prepare") {
    return json({ ok: false, error: "unsupported_action" }, 400, req);
  }

  let prepared: PreparedRender | null = null;
  try {
    prepared = await prepareRender(body, user.id);

    if (action === "prepare") {
      return json({
        ok: true,
        worker_url: clientWorkerUrl(req),
        worker_payload: prepared.workerPayload,
        video_url: prepared.videoUrl,
        poster_url: prepared.posterUrl,
        duration_seconds: prepared.durationSeconds,
        template_id: prepared.templateId,
        template_version: prepared.templateVersion,
        audio_preset: prepared.audioPreset,
        job_id: prepared.jobId,
      }, 200, req);
    }

    await dispatchRender(prepared);
    return json({
      ok: true,
      render_pending: true,
      video_url: prepared.videoUrl,
      poster_url: prepared.posterUrl,
      duration_seconds: prepared.durationSeconds,
      template_id: prepared.templateId,
      template_version: prepared.templateVersion,
      audio_preset: prepared.audioPreset,
      job_id: prepared.jobId,
    }, 202, req);
  } catch (error) {
    if (prepared != null) {
      await admin.storage.from(VIDEO_BUCKET).remove([prepared.sourcePath]).catch(() => {});
    }
    return json({ ok: false, error: cleanError(error) }, 400, req);
  }
});
