import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const GEMINI_MODEL = "gemini-3.6-flash";
const BUCKET = "listing-videos";
const MAX_BYTES = 50 * 1024 * 1024;
const PROJECT_HOST = "vplgtcguxujxwrgguxqq.supabase.co";

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const PROMPT = `You are the strict video-safety moderator for Swipess, a property, vehicle, jobs and events marketplace.
Review the ENTIRE uploaded video from first frame to last frame, not only a thumbnail. Inspect visible people, every scene, overlays, signs, screenshots, watermarks, small text, and QR codes.
REJECT when any part clearly contains explicit nudity, exposed genitals, pornography, sexual acts, sexually explicit solicitation, graphic gore, extreme violence, clearly illegal content, a phone/WhatsApp number intended as contact information, an email address, an @ social handle intended to move contact outside Swipess, a URL/domain/social link, a QR/scannable code that redirects or provides outside contact, or an outside advertisement/promotional watermark intended to redirect users off-platform.
ALLOW ordinary non-explicit swimwear/beachwear, normal dancing, kissing, fitness content, property/vehicle scenes, street or unit numbers, prices, dates, license plates, brand names, and decorative text unless clearly used as prohibited outside contact.
If evidence is genuinely ambiguous, choose REVIEW instead of guessing.
Return ONLY valid JSON:
{"decision":"allow|reject|review","safe":true|false,"reasons":["short reason"],"categories":["nudity|sexual|violence|illegal|phone|email|social_handle|url|qr_code|outside_ad"],"confidence":0.0}`;

type Verdict = {
  decision: "allow" | "reject" | "review";
  safe: boolean;
  reasons: string[];
  categories: string[];
  confidence: number;
};

type ReadyJob = {
  id: string;
  source_url: string | null;
  playback_url: string | null;
  poster_url: string | null;
  hls_master_url: string | null;
  completed_at: string | null;
};

function json(data: unknown, status = 200) {
  return Response.json(data, {
    status,
    headers: { "Cache-Control": "no-store" },
  });
}

function cleanText(value: unknown, max = 800) {
  return String(value ?? "").replace(/\s+/g, " ").trim().slice(0, max);
}

function cleanList(value: unknown) {
  return Array.isArray(value)
    ? value.map((v) => cleanText(v, 180)).filter(Boolean).slice(0, 12)
    : [];
}

function parseVerdict(text: string): Verdict {
  const raw = text.replace(/```json/gi, "").replace(/```/g, "").trim();
  const parsed = JSON.parse(raw);
  let decision = String(parsed?.decision ?? "").toLowerCase();
  if (!["allow", "reject", "review"].includes(decision)) {
    decision = parsed?.safe === false ? "reject" : "allow";
  }
  const confidence = Math.max(
    0,
    Math.min(1, Number(parsed?.confidence ?? 0.85) || 0.85),
  );
  if (decision === "reject" && confidence < 0.6) decision = "review";
  return {
    decision: decision as Verdict["decision"],
    safe: decision === "allow",
    reasons: cleanList(parsed?.reasons),
    categories: cleanList(parsed?.categories),
    confidence,
  };
}

async function secretMatches(req: Request) {
  const supplied = req.headers.get("x-job-secret") ?? "";
  if (!supplied) return false;
  const { data, error } = await admin
    .from("internal_job_secrets")
    .select("secret")
    .eq("job_name", "listing-video-moderation")
    .maybeSingle();
  return !error && !!data && supplied === data.secret;
}

function storagePathFromPublicUrl(url: string): string | null {
  try {
    const parsed = new URL(url);
    if (parsed.protocol !== "https:" || parsed.host !== PROJECT_HOST) return null;
    const marker = `/storage/v1/object/public/${BUCKET}/`;
    const index = parsed.pathname.indexOf(marker);
    if (index < 0) return null;
    return decodeURIComponent(parsed.pathname.slice(index + marker.length));
  } catch (_) {
    return null;
  }
}

async function latestReadyJob(listingId: string): Promise<ReadyJob | null> {
  const { data, error } = await admin
    .from("listing_video_jobs")
    .select("id,source_url,playback_url,poster_url,hls_master_url,completed_at")
    .eq("listing_id", listingId)
    .eq("status", "ready")
    .order("created_at", { ascending: false })
    .limit(1);
  if (error) throw error;
  return (Array.isArray(data) ? data[0] : null) as ReadyJob | null;
}

async function uploadGeminiFile(bytes: Uint8Array, mimeType: string) {
  const start = await fetch(
    `https://generativelanguage.googleapis.com/upload/v1beta/files?key=${GEMINI_API_KEY}`,
    {
      method: "POST",
      headers: {
        "X-Goog-Upload-Protocol": "resumable",
        "X-Goog-Upload-Command": "start",
        "X-Goog-Upload-Header-Content-Length": String(bytes.byteLength),
        "X-Goog-Upload-Header-Content-Type": mimeType,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        file: { display_name: `swipess-moderation-${crypto.randomUUID()}` },
      }),
    },
  );
  if (!start.ok) {
    throw new Error(`gemini_upload_start_${start.status}:${await start.text()}`);
  }
  const uploadUrl = start.headers.get("x-goog-upload-url");
  if (!uploadUrl) throw new Error("gemini_upload_url_missing");

  const finalized = await fetch(uploadUrl, {
    method: "POST",
    headers: {
      "X-Goog-Upload-Offset": "0",
      "X-Goog-Upload-Command": "upload, finalize",
      "Content-Length": String(bytes.byteLength),
    },
    body: bytes,
  });
  if (!finalized.ok) {
    throw new Error(`gemini_upload_${finalized.status}:${await finalized.text()}`);
  }
  const payload = await finalized.json();
  return payload?.file ?? payload;
}

async function waitForGeminiFile(file: Record<string, unknown>) {
  let current = file;
  for (let attempt = 0; attempt < 30; attempt++) {
    const state = String((current as any)?.state ?? "ACTIVE").toUpperCase();
    if (state === "ACTIVE") return current;
    if (state === "FAILED") throw new Error("gemini_file_processing_failed");
    const name = String((current as any)?.name ?? "");
    if (!name) throw new Error("gemini_file_name_missing");
    await new Promise((resolve) => setTimeout(resolve, 2000));
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/${name}?key=${GEMINI_API_KEY}`,
    );
    if (!res.ok) throw new Error(`gemini_file_poll_${res.status}`);
    const payload = await res.json();
    current = payload?.file ?? payload;
  }
  throw new Error("gemini_file_processing_timeout");
}

async function moderateGemini(file: Record<string, unknown>, mimeType: string) {
  const uri = String((file as any)?.uri ?? "");
  if (!uri) throw new Error("gemini_file_uri_missing");
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{
          role: "user",
          parts: [
            { file_data: { mime_type: mimeType, file_uri: uri } },
            { text: PROMPT },
          ],
        }],
        generationConfig: {
          temperature: 0.05,
          responseMimeType: "application/json",
        },
      }),
    },
  );
  if (!res.ok) {
    throw new Error(`gemini_moderation_${res.status}:${await res.text()}`);
  }
  const payload = await res.json();
  const text = payload?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  return parseVerdict(String(text));
}

async function deleteGeminiFile(file: Record<string, unknown> | null) {
  const name = String((file as any)?.name ?? "");
  if (!name || !GEMINI_API_KEY) return;
  await fetch(
    `https://generativelanguage.googleapis.com/v1beta/${name}?key=${GEMINI_API_KEY}`,
    { method: "DELETE" },
  ).catch(() => {});
}

async function promote(
  listingId: string,
  originalUrl: string,
  job: ReadyJob,
  reason: string | null = null,
) {
  const playback = cleanText(job.playback_url, 2200);
  if (!playback) throw new Error("ready_job_missing_playback_url");
  const now = new Date().toISOString();
  const { error } = await admin
    .from("listings")
    .update({
      video_moderation_status: "approved",
      video_moderation_reason: reason,
      video_moderated_at: now,
      video_url: playback,
      video_playback_url: playback,
      video_poster_url: cleanText(job.poster_url, 2200) || null,
      video_hls_url: cleanText(job.hls_master_url, 2200) || null,
      video_processing_status: "ready",
      video_processing_error: null,
      video_processed_at: job.completed_at ?? now,
    })
    .eq("id", listingId)
    .eq("video_original_url", originalUrl);
  if (error) throw error;
}

async function review(
  listingId: string,
  originalUrl: string,
  verdict: Verdict,
) {
  const reason = cleanText(
    verdict.reasons.join("; ") || "Video needs manual safety review",
    1000,
  );
  await admin
    .from("listings")
    .update({
      video_moderation_status: "review",
      video_moderation_reason: reason,
      video_moderated_at: new Date().toISOString(),
      video_processing_status: "ready",
      video_processing_error: null,
    })
    .eq("id", listingId)
    .eq("video_original_url", originalUrl);
}

async function reject(
  listingId: string,
  originalUrl: string,
  verdict: Verdict,
) {
  const reason = cleanText(
    verdict.reasons.join("; ") || "Video blocked by safety review",
    1000,
  );
  const sourcePath = storagePathFromPublicUrl(originalUrl);
  if (sourcePath && !sourcePath.startsWith("processed/")) {
    await admin.storage.from(BUCKET).remove([sourcePath]).catch(() => {});
  }
  await admin
    .from("listings")
    .update({
      video_url: null,
      video_original_url: null,
      video_playback_url: null,
      video_hls_url: null,
      video_poster_url: null,
      video_moderation_status: "rejected",
      video_moderation_reason: reason,
      video_moderated_at: new Date().toISOString(),
      video_processing_status: "failed",
      video_processing_error: `Video blocked by safety review: ${reason}`.slice(0, 1200),
    })
    .eq("id", listingId)
    .eq("video_original_url", originalUrl);
}

Deno.serve(async (req: Request) => {
  if (req.method === "GET") {
    return json({ ok: true, service: "moderate-video", version: 3, model: GEMINI_MODEL });
  }
  if (req.method !== "POST") return json({ ok: false, error: "method_not_allowed" }, 405);
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    return json({ ok: false, error: "server_configuration_missing" }, 500);
  }
  if (!(await secretMatches(req))) return json({ ok: false, error: "unauthorized" }, 401);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return json({ ok: false, error: "invalid_json" }, 400);
  }

  const listingId = cleanText(body.listing_id, 80);
  if (!listingId) return json({ ok: false, error: "listing_id_required" }, 400);

  const { data: listing, error: listingError } = await admin
    .from("listings")
    .select("id,video_original_url,video_moderation_status")
    .eq("id", listingId)
    .maybeSingle();
  if (listingError) return json({ ok: false, error: listingError.message }, 500);
  if (!listing) return json({ ok: false, error: "listing_not_found" }, 404);

  const originalUrl = cleanText(listing.video_original_url, 2500);
  if (!originalUrl) return json({ ok: true, skipped: "no_video" });

  let job: ReadyJob | null;
  try {
    job = await latestReadyJob(listingId);
  } catch (error) {
    return json({ ok: false, error: cleanText(error) }, 500);
  }

  const processedUrl = cleanText(job?.playback_url, 2500);
  if (!job || !processedUrl) {
    await admin
      .from("listings")
      .update({
        video_moderation_status: "queued",
        video_moderation_reason: "Waiting for processed video safety scan",
      })
      .eq("id", listingId)
      .eq("video_original_url", originalUrl);
    return json({ ok: true, waiting_for_processing: true }, 202);
  }

  await admin
    .from("listings")
    .update({
      video_moderation_status: "processing",
      video_moderation_reason: null,
    })
    .eq("id", listingId)
    .eq("video_original_url", originalUrl);

  let geminiFile: Record<string, unknown> | null = null;
  try {
    if (!GEMINI_API_KEY) throw new Error("gemini_not_configured");
    const path = storagePathFromPublicUrl(processedUrl);
    if (!path) throw new Error("unsupported_processed_video_url");
    const { data: blob, error: downloadError } = await admin.storage
      .from(BUCKET)
      .download(path);
    if (downloadError || !blob) {
      throw new Error(downloadError?.message ?? "processed_video_download_failed");
    }
    if (blob.size <= 0) throw new Error("video_empty");
    if (blob.size > MAX_BYTES) throw new Error("video_too_large");

    const bytes = new Uint8Array(await blob.arrayBuffer());
    geminiFile = await uploadGeminiFile(bytes, "video/mp4");
    geminiFile = await waitForGeminiFile(geminiFile);
    const verdict = await moderateGemini(geminiFile, "video/mp4");

    if (verdict.decision === "allow") {
      await promote(listingId, originalUrl, job);
    } else if (verdict.decision === "reject") {
      await reject(listingId, originalUrl, verdict);
    } else {
      await review(listingId, originalUrl, verdict);
    }

    return json({
      ok: true,
      decision: verdict.decision,
      confidence: verdict.confidence,
      reasons: verdict.reasons,
      categories: verdict.categories,
    });
  } catch (error) {
    const reason = cleanText(error instanceof Error ? error.message : error) || "moderation_unavailable";
    console.error("[moderate-video]", listingId, reason);
    await promote(
      listingId,
      originalUrl,
      job,
      `Automated safety scan unavailable: ${reason}`.slice(0, 1000),
    );
    return json({ ok: true, decision: "allow", degraded: true, reason });
  } finally {
    await deleteGeminiFile(geminiFile);
  }
});
