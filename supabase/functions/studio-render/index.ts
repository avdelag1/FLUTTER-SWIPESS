import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const WORKER_URL = Deno.env.get("STUDIO_RENDERER_URL") ?? "https://www.swipess.com/api/studio-render";
const IMAGE_BUCKET = "listing-images";
const VIDEO_BUCKET = "listing-videos";
const MIN_IMAGES = 3;
const MAX_IMAGES = 6;

const fallbackAllowedHeaders = [
  "authorization",
  "x-client-info",
  "apikey",
  "content-type",
  "x-supabase-client-platform",
  "x-supabase-client-platform-version",
  "x-supabase-client-runtime",
  "x-supabase-client-runtime-version",
].join(", ");

function corsHeaders(req?: Request) {
  const requestedHeaders = req?.headers
    .get("Access-Control-Request-Headers")
    ?.trim();
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": requestedHeaders || fallbackAllowedHeaders,
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin, Access-Control-Request-Headers",
  };
}

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

function json(data: unknown, status = 200, req?: Request) {
  return Response.json(data, {
    status,
    headers: {
      ...corsHeaders(req),
      "Cache-Control": "no-store",
    },
  });
}

function cleanError(value: unknown) {
  return (value instanceof Error ? value.message : String(value ?? "unknown_error")).slice(0, 1200);
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

function generatedPathForUser(raw: unknown, userId: string): string | null {
  const value = String(raw ?? "").trim();
  if (!value) return null;
  const path = storagePathFromPublicUrl(value, VIDEO_BUCKET);
  if (!path || !path.startsWith(`generated/${userId}/`)) return null;
  return path;
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

async function cleanupGenerated(body: Record<string, unknown>, userId: string, req?: Request) {
  const paths = new Set<string>();
  const videoPath = generatedPathForUser(body.video_url, userId);
  const posterPath = generatedPathForUser(body.poster_url, userId);
  if (videoPath) paths.add(videoPath);
  if (posterPath) paths.add(posterPath);
  if (paths.size === 0) {
    return json({ ok: false, error: "studio_cleanup_path_invalid" }, 400, req);
  }
  const { error } = await admin.storage.from(VIDEO_BUCKET).remove([...paths]);
  if (error) return json({ ok: false, error: cleanError(error) }, 500, req);
  return json({ ok: true, removed: paths.size }, 200, req);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(req) });
  }

  if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !ANON_KEY) {
    return json({ ok: false, error: "server_configuration_missing" }, 500, req);
  }
  if (req.method === "GET") return json({ ok: true, service: "studio-render" }, 200, req);
  if (req.method !== "POST") return json({ ok: false, error: "method_not_allowed" }, 405, req);

  const user = await authenticatedUser(req);
  if (!user) return json({ ok: false, error: "unauthorized" }, 401, req);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return json({ ok: false, error: "invalid_json" }, 400, req);
  }

  if (String(body.action ?? "render") === "cleanup") {
    return cleanupGenerated(body, user.id, req);
  }

  try {
    const imageUrls = validateImages(body.image_urls, user.id);
    const template = validateTemplate(body.template, imageUrls.length);
    const project = body.project && typeof body.project === "object"
      ? body.project as Record<string, unknown>
      : {};
    const audioPreset = String(project.audio_preset ?? template.audio_preset ?? "clean_ambient");

    const renderId = crypto.randomUUID();
    const videoPath = `generated/${user.id}/${renderId}.mp4`;
    const posterPath = `generated/${user.id}/${renderId}.jpg`;

    const { data: videoUpload, error: videoUploadError } = await admin.storage
      .from(VIDEO_BUCKET)
      .createSignedUploadUrl(videoPath, { upsert: false });
    const { data: posterUpload, error: posterUploadError } = await admin.storage
      .from(VIDEO_BUCKET)
      .createSignedUploadUrl(posterPath, { upsert: false });
    if (videoUploadError || posterUploadError || !videoUpload?.token || !posterUpload?.token) {
      return json({
        ok: false,
        error: videoUploadError?.message ?? posterUploadError?.message ?? "studio_output_sign_failed",
      }, 500, req);
    }

    let response: Response;
    try {
      response = await fetch(WORKER_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          user_id: user.id,
          image_urls: imageUrls,
          template,
          audio_preset: audioPreset,
          output: {
            storage_url: SUPABASE_URL,
            storage_anon_key: ANON_KEY,
            bucket: VIDEO_BUCKET,
            video_path: videoPath,
            video_token: videoUpload.token,
            poster_path: posterPath,
            poster_token: posterUpload.token,
          },
        }),
      });
    } catch (error) {
      await admin.storage.from(VIDEO_BUCKET).remove([videoPath, posterPath]).catch(() => {});
      return json({ ok: false, error: `studio_worker_unreachable:${cleanError(error)}` }, 502, req);
    }

    const text = await response.text();
    let worker: Record<string, unknown> = {};
    try {
      worker = text ? JSON.parse(text) : {};
    } catch (_) {
      worker = { error: text };
    }
    if (!response.ok || worker.ok !== true) {
      await admin.storage.from(VIDEO_BUCKET).remove([videoPath, posterPath]).catch(() => {});
      return json({
        ok: false,
        error: cleanError(worker.error ?? `studio_worker_${response.status}`),
      }, response.status >= 400 && response.status < 600 ? response.status : 500, req);
    }

    const videoUrl = admin.storage.from(VIDEO_BUCKET).getPublicUrl(videoPath).data.publicUrl;
    const posterUrl = admin.storage.from(VIDEO_BUCKET).getPublicUrl(posterPath).data.publicUrl;
    return json({
      ok: true,
      video_url: videoUrl,
      poster_url: posterUrl,
      duration_seconds: Number(worker.duration_seconds ?? 0) || null,
      template_id: String(project.template_id ?? template.id ?? ""),
      template_version: Number(project.template_version ?? template.version ?? 1),
      audio_preset: audioPreset,
    }, 200, req);
  } catch (error) {
    return json({ ok: false, error: cleanError(error) }, 400, req);
  }
});