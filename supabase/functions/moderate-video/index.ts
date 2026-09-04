import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const BUCKET = "listing-videos";
const MAX_BYTES = 50 * 1024 * 1024;
const PROJECT_HOST = "vplgtcguxujxwrgguxqq.supabase.co";

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const PROMPT = `You are the strict video-safety moderator for Swipess, a property, vehicle, jobs and events marketplace.
Review the ENTIRE uploaded video from first frame to last frame, not only a thumbnail. Inspect visible people, every scene, overlays, signs, screenshots, watermarks, small text, and QR codes.

REJECT when any part clearly contains:
- explicit nudity, exposed genitals, pornography, sexual acts, or sexually explicit solicitation;
- graphic gore, extreme violence, or clearly illegal content;
- a phone number or WhatsApp number intended as contact information;
- an email address;
- an @ social handle or social-media username intended to move contact outside Swipess;
- a URL/domain, wa.me link, social-media link, or other external-contact link;
- a QR/scannable code that redirects or provides outside contact;
- an outside advertisement or promotional watermark intended to redirect users off-platform.

ALLOW ordinary non-explicit swimwear/beachwear, normal dancing, kissing, fitness content, property/vehicle scenes, street or unit numbers, prices, dates, license plates, brand names, and decorative text unless they are clearly being used as prohibited outside contact.

If the evidence is genuinely ambiguous, choose REVIEW instead of guessing.
Return ONLY valid JSON:
{"decision":"allow|reject|review","safe":true|false,"reasons":["short reason"],"categories":["nudity|sexual|violence|illegal|phone|email|social_handle|url|qr_code|outside_ad"],"confidence":0.0}`;

type Verdict = {
  decision: "allow" | "reject" | "review";
  safe: boolean;
  reasons: string[];
  categories: string[];
  confidence: number;
};

function json(data: unknown, status = 200) {
  return Response.json(data, { status, headers: { "Cache-Control": "no-store" } });
}

function cleanText(value: unknown, max = 500) {
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
  const confidence = Math.max(0, Math.min(1, Number(parsed?.confidence ?? 0.85) || 0.85));
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

function mimeFor(path: string, blobType?: string) {
  if (blobType?.startsWith("video/")) return blobType;
  const lower = path.toLowerCase();
  if (lower.endsWith(".mov")) return "video/quicktime";
  if (lower.endsWith(".webm")) return "video/webm";
  return "video/mp4";
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
      body: JSON.stringify({ file: { display_name: `swipess-moderation-${crypto.randomUUID()}` } }),
    },
  );
  if (!start.ok) throw new Error(`gemini_upload_start_${start.status}:${await start.text()}`);
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
  if (!finalized.ok) throw new Error(`gemini_upload_${finalized.status}:${await finalized.text()}`);
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
    const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/${name}?key=${GEMINI_API_KEY}`);
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
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`,
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
  if (!res.ok) throw new Error(`gemini_moderation_${res.status}:${await res.text()}`);
  const payload = await res.json();
  const text = payload?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  return parseVerdict(String(text));
}

async function deleteGeminiFile(file: Record<string, unknown> | null) {
  const name = String((file as any)?.name ?? "");
  if (!name || !GEMINI_API_KEY) return;
  await fetch(`https://generativelanguage.googleapis.com/v1beta/${name}?key=${GEMINI_API_KEY}`, {
    method: "DELETE",
  }).catch(() => {});
}

async function promoteReadyJob(listingId: string, sourceUrl: string, moderatedAt: string) {
  const { data: jobs } = await admin
    .from("listing_video_jobs")
    .select("playback_url,poster_url,hls_master_url,completed_at")
    .eq("listing_id", listingId)
    .eq("source_url", sourceUrl)
    .eq("status", "ready")
    .order("created_at", { ascending: false })
    .limit(1);
  const job = Array.isArray(jobs) ? jobs[0] : null;
  const playback = cleanText(job?.playback_url, 2000);
  const poster = cleanText(job?.poster_url, 2000);
  const hls = cleanText(job?.hls_master_url, 2000);

  const update: Record<string, unknown> = {
    video_moderation_status: "approved",
    video_moderation_reason: null,
    video_moderated_at: moderatedAt,
  };
  if (playback) {
    update.video_url = playback;
    update.video_playback_url = playback;
    update.video_poster_url = poster || null;
    update.video_hls_url = hls || null;
    update.video_processing_status = "ready";
    update.video_processing_error = null;
    update.video_processed_at = job?.completed_at ?? moderatedAt;
  }

  await admin
    .from("listings")
    .update(update)
    .eq("id", listingId)
    .eq("video_original_url", sourceUrl);
}

async function quarantineVideo(
  listingId: string,
  sourceUrl: string,
  verdict: Verdict,
  status: "rejected" | "review",
) {
  const reason = cleanText(verdict.reasons.join("; ") || `video_${status}`, 1000);
  await admin
    .from("listing_video_jobs")
    .update({ status: "superseded", error: `moderation_${status}:${reason}`.slice(0, 1200) })
    .eq("listing_id", listingId)
    .eq("source_url", sourceUrl)
    .in("status", ["queued", "processing"]);

  const sourcePath = storagePathFromPublicUrl(sourceUrl);
  if (sourcePath) {
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
      video_moderation_status: status,
      video_moderation_reason: reason,
      video_moderated_at: new Date().toISOString(),
    })
    .eq("id", listingId)
    .eq("video_original_url", sourceUrl);

  await admin
    .from("listings")
    .update({
      video_processing_status: "failed",
      video_processing_error: status === "rejected"
        ? `Video blocked by safety review: ${reason}`.slice(0, 1200)
        : `Video needs manual safety review: ${reason}`.slice(0, 1200),
      video_moderation_status: status,
      video_moderation_reason: reason,
      video_moderated_at: new Date().toISOString(),
    })
    .eq("id", listingId);
}

Deno.serve(async (req: Request) => {
  if (req.method === "GET") return json({ ok: true, service: "moderate-video" });
  if (req.method !== "POST") return json({ ok: false, error: "method_not_allowed" }, 405);
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) return json({ ok: false, error: "server_configuration_missing" }, 500);
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

  const sourceUrl = cleanText(listing.video_original_url, 2500);
  if (!sourceUrl) return json({ ok: true, skipped: "no_video" });
  if (listing.video_moderation_status === "approved") return json({ ok: true, skipped: "already_approved" });
  if (listing.video_moderation_status === "processing") return json({ ok: true, processing: true }, 202);

  await admin
    .from("listings")
    .update({
      video_moderation_status: "processing",
      video_moderation_reason: null,
    })
    .eq("id", listingId)
    .eq("video_original_url", sourceUrl);

  let geminiFile: Record<string, unknown> | null = null;
  try {
    if (!GEMINI_API_KEY) throw new Error("gemini_not_configured");
    const path = storagePathFromPublicUrl(sourceUrl);
    if (!path) throw new Error("unsupported_video_url");
    const { data: blob, error: downloadError } = await admin.storage.from(BUCKET).download(path);
    if (downloadError || !blob) throw new Error(downloadError?.message ?? "video_download_failed");
    if (blob.size <= 0) throw new Error("video_empty");
    if (blob.size > MAX_BYTES) throw new Error("video_too_large");

    const bytes = new Uint8Array(await blob.arrayBuffer());
    const mimeType = mimeFor(path, blob.type);
    geminiFile = await uploadGeminiFile(bytes, mimeType);
    geminiFile = await waitForGeminiFile(geminiFile);
    const verdict = await moderateGemini(geminiFile, mimeType);
    const moderatedAt = new Date().toISOString();

    if (verdict.decision === "allow") {
      await promoteReadyJob(listingId, sourceUrl, moderatedAt);
      return json({ ok: true, decision: "allow", confidence: verdict.confidence });
    }

    const status = verdict.decision === "reject" ? "rejected" : "review";
    await quarantineVideo(listingId, sourceUrl, verdict, status);
    return json({
      ok: true,
      decision: verdict.decision,
      confidence: verdict.confidence,
      reasons: verdict.reasons,
      categories: verdict.categories,
    });
  } catch (error) {
    const reason = cleanText(error instanceof Error ? error.message : error, 800) || "moderation_unavailable";
    console.error("[moderate-video]", listingId, reason);
    await quarantineVideo(
      listingId,
      sourceUrl,
      { decision: "review", safe: false, reasons: ["Automated video safety check unavailable"], categories: [], confidence: 0 },
      "review",
    );
    return json({ ok: false, error: reason, decision: "review" }, 202);
  } finally {
    await deleteGeminiFile(geminiFile);
  }
});
