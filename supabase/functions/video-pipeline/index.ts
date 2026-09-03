import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const WORKER_URL =
  Deno.env.get("VIDEO_TRANSCODER_URL") ??
  "https://www.swipess.com/api/video-transcode";
const BUCKET = "listing-videos";

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

function json(data: unknown, status = 200) {
  return Response.json(data, {
    status,
    headers: { "Cache-Control": "no-store" },
  });
}

function randomToken(bytes = 32) {
  const raw = new Uint8Array(bytes);
  crypto.getRandomValues(raw);
  return Array.from(raw, (b) => b.toString(16).padStart(2, "0")).join("");
}

function cleanError(value: unknown) {
  const text = value instanceof Error
    ? value.message
    : String(value ?? "unknown_error");
  return text.slice(0, 1200);
}

function isProcessedUrl(url: string) {
  return url.includes("/processed/");
}

function storagePathFromPublicUrl(url: string): string | null {
  try {
    const parsed = new URL(url);
    const expectedHost = new URL(SUPABASE_URL).host;
    if (parsed.host !== expectedHost) return null;
    const marker = `/storage/v1/object/public/${BUCKET}/`;
    const index = parsed.pathname.indexOf(marker);
    if (index < 0) return null;
    return decodeURIComponent(parsed.pathname.slice(index + marker.length));
  } catch (_) {
    return null;
  }
}

async function internalSecretMatches(req: Request) {
  const supplied = req.headers.get("x-job-secret") ?? "";
  if (!supplied) return false;
  const { data, error } = await admin
    .from("internal_job_secrets")
    .select("secret")
    .eq("job_name", "listing-video-pipeline")
    .maybeSingle();
  return !error && !!data && supplied === data.secret;
}

async function getAuthorizedJob(jobId: string, token: string) {
  if (!jobId || !token) return null;
  const { data, error } = await admin
    .from("listing_video_jobs")
    .select("*")
    .eq("id", jobId)
    .maybeSingle();
  if (error || !data || data.worker_token !== token) return null;
  return data;
}

async function noteDispatchFailure(jobId: string, message: string) {
  await admin
    .from("listing_video_jobs")
    .update({ error: `dispatch: ${message}`.slice(0, 1200) })
    .eq("id", jobId)
    .eq("status", "queued");
}

function dispatchJob(job: Record<string, unknown>) {
  const request = fetch(WORKER_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      job_id: job.id,
      token: job.worker_token,
      authorize_url: `${SUPABASE_URL}/functions/v1/video-pipeline`,
    }),
  })
    .then(async (response) => {
      if (!response.ok) {
        const body = await response.text().catch(() => "");
        await noteDispatchFailure(
          String(job.id),
          `${response.status} ${body}`,
        );
      } else {
        await admin
          .from("listing_video_jobs")
          .update({ error: null })
          .eq("id", job.id)
          .eq("status", "queued");
      }
    })
    .catch((error) =>
      noteDispatchFailure(String(job.id), cleanError(error))
    );

  const runtime = (globalThis as unknown as {
    EdgeRuntime?: { waitUntil: (p: Promise<unknown>) => void };
  }).EdgeRuntime;
  if (runtime?.waitUntil) runtime.waitUntil(request);
  else void request;
}

async function startInternal(listingId: string) {
  if (!listingId) {
    return json({ ok: false, error: "listing_id_required" }, 400);
  }

  const { data: listing, error: listingError } = await admin
    .from("listings")
    .select(
      "id,owner_id,video_url,video_original_url,video_playback_url,video_processing_status",
    )
    .eq("id", listingId)
    .maybeSingle();
  if (listingError) {
    return json({ ok: false, error: listingError.message }, 500);
  }
  if (!listing) return json({ ok: false, error: "listing_not_found" }, 404);

  const currentVideo = String(listing.video_url ?? "").trim();
  const originalVideo = String(listing.video_original_url ?? "").trim();
  const sourceUrl =
    (isProcessedUrl(currentVideo) ? originalVideo : currentVideo) ||
    originalVideo;
  if (!sourceUrl) return json({ ok: true, skipped: "no_video" });

  if (
    listing.video_processing_status === "ready" &&
    String(listing.video_playback_url ?? "").trim() &&
    isProcessedUrl(currentVideo)
  ) {
    return json({ ok: true, skipped: "already_ready" });
  }

  const { data: existingRows, error: existingError } = await admin
    .from("listing_video_jobs")
    .select("*")
    .eq("listing_id", listingId)
    .eq("source_url", sourceUrl)
    .in("status", ["queued", "processing", "ready"])
    .order("created_at", { ascending: false })
    .limit(1);
  if (existingError) {
    return json({ ok: false, error: existingError.message }, 500);
  }

  const existing = Array.isArray(existingRows) ? existingRows[0] : null;
  if (existing?.status === "ready" && existing.playback_url) {
    await admin
      .from("listings")
      .update({
        video_url: existing.playback_url,
        video_playback_url: existing.playback_url,
        video_poster_url: existing.poster_url,
        video_processing_status: "ready",
        video_processing_error: null,
        video_processed_at:
          existing.completed_at ?? new Date().toISOString(),
      })
      .eq("id", listingId)
      .eq("video_original_url", sourceUrl);
    return json({ ok: true, reused: existing.id });
  }
  if (existing?.status === "processing") {
    return json({ ok: true, processing: existing.id }, 202);
  }
  if (existing?.status === "queued") {
    dispatchJob(existing);
    return json({ ok: true, queued: existing.id, redispatched: true }, 202);
  }

  await admin
    .from("listing_video_jobs")
    .update({ status: "superseded" })
    .eq("listing_id", listingId)
    .in("status", ["queued", "processing"]);

  const workerToken = randomToken();
  const { data: job, error: insertError } = await admin
    .from("listing_video_jobs")
    .insert({
      listing_id: listing.id,
      owner_id: listing.owner_id,
      source_url: sourceUrl,
      worker_token: workerToken,
      status: "queued",
    })
    .select("*")
    .single();
  if (insertError || !job) {
    return json(
      { ok: false, error: insertError?.message ?? "job_insert_failed" },
      500,
    );
  }

  await admin
    .from("listings")
    .update({
      video_processing_status: "queued",
      video_processing_error: null,
    })
    .eq("id", listingId);

  dispatchJob(job);
  return json({ ok: true, queued: job.id }, 202);
}

async function authorize(jobId: string, token: string) {
  const job = await getAuthorizedJob(jobId, token);
  if (!job) return json({ ok: false, error: "unauthorized_job" }, 401);
  if (!["queued", "processing"].includes(job.status)) {
    return json({ ok: false, error: `job_${job.status}` }, 409);
  }

  const sourcePath = storagePathFromPublicUrl(String(job.source_url));
  if (!sourcePath) {
    return json({ ok: false, error: "unsupported_source_url" }, 400);
  }

  const { data: sourceSigned, error: sourceError } = await admin.storage
    .from(BUCKET)
    .createSignedUrl(sourcePath, 7200);
  if (sourceError || !sourceSigned?.signedUrl) {
    return json(
      {
        ok: false,
        error: sourceError?.message ?? "source_sign_failed",
      },
      500,
    );
  }

  const videoPath = `processed/${job.listing_id}/${job.id}.mp4`;
  const posterPath = `processed/${job.listing_id}/${job.id}.jpg`;
  const { data: videoUpload, error: videoUploadError } = await admin.storage
    .from(BUCKET)
    .createSignedUploadUrl(videoPath, { upsert: false });
  const { data: posterUpload, error: posterUploadError } = await admin.storage
    .from(BUCKET)
    .createSignedUploadUrl(posterPath, { upsert: false });
  if (
    videoUploadError ||
    posterUploadError ||
    !videoUpload?.token ||
    !posterUpload?.token
  ) {
    return json(
      {
        ok: false,
        error:
          videoUploadError?.message ??
          posterUploadError?.message ??
          "output_sign_failed",
      },
      500,
    );
  }

  const playbackUrl = admin.storage.from(BUCKET).getPublicUrl(videoPath).data
    .publicUrl;
  const posterUrl = admin.storage.from(BUCKET).getPublicUrl(posterPath).data
    .publicUrl;
  const now = new Date().toISOString();
  await admin
    .from("listing_video_jobs")
    .update({
      status: "processing",
      attempt_count: Number(job.attempt_count ?? 0) + 1,
      started_at: job.started_at ?? now,
      output_video_path: videoPath,
      output_poster_path: posterPath,
      playback_url: playbackUrl,
      poster_url: posterUrl,
      error: null,
    })
    .eq("id", job.id);
  await admin
    .from("listings")
    .update({
      video_processing_status: "processing",
      video_processing_error: null,
    })
    .eq("id", job.listing_id)
    .eq("video_original_url", job.source_url);

  return json({
    ok: true,
    source_url: sourceSigned.signedUrl,
    storage_url: SUPABASE_URL,
    storage_anon_key: ANON_KEY,
    bucket: BUCKET,
    video_path: videoPath,
    video_token: videoUpload.token,
    poster_path: posterPath,
    poster_token: posterUpload.token,
    playback_url: playbackUrl,
    poster_url: posterUrl,
  });
}

async function complete(
  jobId: string,
  token: string,
  body: Record<string, unknown>,
) {
  const job = await getAuthorizedJob(jobId, token);
  if (!job) return json({ ok: false, error: "unauthorized_job" }, 401);
  if (!job.playback_url || !job.poster_url) {
    return json({ ok: false, error: "job_not_authorized" }, 409);
  }

  const now = new Date().toISOString();
  await admin
    .from("listing_video_jobs")
    .update({
      status: "ready",
      source_size_bytes: Number(body.source_size_bytes ?? 0) || null,
      output_size_bytes: Number(body.output_size_bytes ?? 0) || null,
      error: null,
      completed_at: now,
    })
    .eq("id", job.id);

  const { data: updatedRows, error: listingError } = await admin
    .from("listings")
    .update({
      video_url: job.playback_url,
      video_playback_url: job.playback_url,
      video_poster_url: job.poster_url,
      video_processing_status: "ready",
      video_processing_error: null,
      video_processed_at: now,
    })
    .eq("id", job.listing_id)
    .eq("video_original_url", job.source_url)
    .select("id");
  if (listingError) {
    return json({ ok: false, error: listingError.message }, 500);
  }

  const promoted = Array.isArray(updatedRows) && updatedRows.length > 0;
  if (promoted) {
    await admin
      .from("listing_video_jobs")
      .update({ status: "superseded" })
      .eq("listing_id", job.listing_id)
      .neq("id", job.id)
      .in("status", ["queued", "processing"]);
  }

  return json({ ok: true, promoted });
}

async function fail(
  jobId: string,
  token: string,
  body: Record<string, unknown>,
) {
  const job = await getAuthorizedJob(jobId, token);
  if (!job) return json({ ok: false, error: "unauthorized_job" }, 401);
  const message = cleanError(body.error ?? "transcode_failed");
  await admin
    .from("listing_video_jobs")
    .update({
      status: "failed",
      error: message,
      completed_at: new Date().toISOString(),
    })
    .eq("id", job.id);
  await admin
    .from("listings")
    .update({
      video_processing_status: "failed",
      video_processing_error: message,
    })
    .eq("id", job.listing_id)
    .eq("video_original_url", job.source_url);
  return json({ ok: true });
}

Deno.serve(async (req: Request) => {
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    return json({ ok: false, error: "server_configuration_missing" }, 500);
  }
  if (req.method === "GET") {
    return json({ ok: true, service: "video-pipeline" });
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
  if (action === "start_internal" || action === "retry_internal") {
    if (!(await internalSecretMatches(req))) {
      return json({ ok: false, error: "unauthorized" }, 401);
    }
    return startInternal(String(body.listing_id ?? ""));
  }
  if (action === "authorize") {
    return authorize(String(body.job_id ?? ""), String(body.token ?? ""));
  }
  if (action === "complete") {
    return complete(
      String(body.job_id ?? ""),
      String(body.token ?? ""),
      body,
    );
  }
  if (action === "fail") {
    return fail(
      String(body.job_id ?? ""),
      String(body.token ?? ""),
      body,
    );
  }
  return json({ ok: false, error: "unsupported_action" }, 400);
});
