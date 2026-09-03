import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const BUCKET = "listing-videos";
const FILE_RE = /^(master|360|540|720)(?:_[0-9]{3})?\.(m3u8|ts)$/;

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

function json(data: unknown, status = 200) {
  return Response.json(data, {
    status,
    headers: { "Cache-Control": "no-store" },
  });
}

async function getJob(jobId: string, token: string) {
  if (!/^[0-9a-f-]{36}$/i.test(jobId) || !/^[0-9a-f]{64}$/i.test(token)) {
    return null;
  }
  const { data, error } = await admin
    .from("listing_video_jobs")
    .select("*")
    .eq("id", jobId)
    .maybeSingle();
  if (error || !data || data.worker_token !== token) return null;
  return data;
}

function contentTypeFor(name: string) {
  return name.endsWith(".m3u8")
    ? "application/vnd.apple.mpegurl"
    : "video/mp2t";
}

async function authorize(
  jobId: string,
  token: string,
  body: Record<string, unknown>,
) {
  const job = await getJob(jobId, token);
  if (!job) return json({ ok: false, error: "unauthorized_job" }, 401);
  if (!["processing", "ready"].includes(String(job.status))) {
    return json({ ok: false, error: `job_${job.status}` }, 409);
  }

  const rawFiles = Array.isArray(body.files) ? body.files : [];
  if (rawFiles.length < 4 || rawFiles.length > 120) {
    return json({ ok: false, error: "invalid_file_count" }, 400);
  }

  const names: string[] = [];
  const seen = new Set<string>();
  for (const raw of rawFiles) {
    const name = String((raw as Record<string, unknown>)?.name ?? "");
    if (!FILE_RE.test(name) || seen.has(name)) {
      return json({ ok: false, error: "invalid_hls_file" }, 400);
    }
    seen.add(name);
    names.push(name);
  }
  if (
    !seen.has("master.m3u8") ||
    !seen.has("360.m3u8") ||
    !seen.has("540.m3u8") ||
    !seen.has("720.m3u8")
  ) {
    return json({ ok: false, error: "missing_hls_playlist" }, 400);
  }

  const prefix = `processed/${job.listing_id}/${job.id}/hls`;
  const uploads: Array<Record<string, string>> = [];
  for (const name of names) {
    const path = `${prefix}/${name}`;
    const { data, error } = await admin.storage
      .from(BUCKET)
      .createSignedUploadUrl(path, { upsert: false });
    if (error || !data?.token) {
      return json({ ok: false, error: error?.message ?? "sign_failed" }, 500);
    }
    uploads.push({
      name,
      path,
      token: data.token,
      content_type: contentTypeFor(name),
      public_url: admin.storage.from(BUCKET).getPublicUrl(path).data.publicUrl,
    });
  }

  const master = uploads.find((item) => item.name === "master.m3u8")!;
  await admin
    .from("listing_video_jobs")
    .update({ hls_master_url: master.public_url })
    .eq("id", job.id);

  return json({
    ok: true,
    storage_url: SUPABASE_URL,
    storage_anon_key: ANON_KEY,
    bucket: BUCKET,
    master_url: master.public_url,
    uploads,
  });
}

async function complete(
  jobId: string,
  token: string,
  body: Record<string, unknown>,
) {
  const job = await getJob(jobId, token);
  if (!job) return json({ ok: false, error: "unauthorized_job" }, 401);
  const masterUrl = String(job.hls_master_url ?? "").trim();
  if (!masterUrl) return json({ ok: false, error: "hls_not_authorized" }, 409);

  const totalSize = Number(body.total_size_bytes ?? 0) || null;
  const outputCount = Number(body.output_count ?? 0) || null;
  await admin
    .from("listing_video_jobs")
    .update({
      hls_total_size_bytes: totalSize,
      hls_output_count: outputCount,
    })
    .eq("id", job.id);

  const { data: promoted, error } = await admin
    .from("listings")
    .update({ video_hls_url: masterUrl })
    .eq("id", job.listing_id)
    .eq("video_original_url", job.source_url)
    .select("id");
  if (error) return json({ ok: false, error: error.message }, 500);

  return json({
    ok: true,
    promoted: Array.isArray(promoted) && promoted.length > 0,
    master_url: masterUrl,
  });
}

Deno.serve(async (req: Request) => {
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !ANON_KEY) {
    return json({ ok: false, error: "server_configuration_missing" }, 500);
  }
  if (req.method === "GET") {
    return json({ ok: true, service: "video-hls-control" });
  }
  if (req.method !== "POST") {
    return json({ ok: false, error: "method_not_allowed" }, 405);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return json({ ok: false, error: "invalid_json" }, 400);
  }

  const action = String(body.action ?? "");
  const jobId = String(body.job_id ?? "");
  const token = String(body.token ?? "");
  if (action === "authorize") return authorize(jobId, token, body);
  if (action === "complete") return complete(jobId, token, body);
  return json({ ok: false, error: "unsupported_action" }, 400);
});
