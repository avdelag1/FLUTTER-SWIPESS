import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
const APP_ORIGIN = (Deno.env.get("APP_ORIGIN") ?? "https://www.swipess.com").replace(/\/$/, "");
const TOKEN_KEY = Deno.env.get("SOCIAL_TOKEN_ENCRYPTION_KEY") ?? "";
const enc = new TextEncoder();
const dec = new TextDecoder();
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};

function fromB64(value: string) {
  const raw = atob(value);
  return Uint8Array.from(raw, (c) => c.charCodeAt(0));
}
async function decrypt(value: string | null | undefined) {
  if (!value) return null;
  if (!TOKEN_KEY) throw new Error("SOCIAL_TOKEN_ENCRYPTION_KEY is not configured");
  const [ivText, cipherText] = value.split(".", 2);
  if (!ivText || !cipherText) throw new Error("invalid_token_ciphertext");
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", enc.encode(TOKEN_KEY)));
  const key = await crypto.subtle.importKey("raw", digest, { name: "AES-GCM" }, false, ["decrypt"]);
  const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv: fromB64(ivText) }, key, fromB64(cipherText));
  return dec.decode(plain);
}

function firstImage(images: unknown): string | null {
  if (!Array.isArray(images)) return null;
  for (const item of images) if (typeof item === "string" && /^https?:\/\//i.test(item)) return item;
  return null;
}
function allImages(images: unknown): string[] {
  if (!Array.isArray(images)) return [];
  return images.map((v) => typeof v === "string" ? v.trim() : "").filter((v) => /^https?:\/\//i.test(v)).slice(0, 35);
}
function priceText(listing: any) {
  const price = Number(listing.price);
  if (!Number.isFinite(price) || price <= 0) return "";
  const currency = String(listing.currency || "USD").toUpperCase();
  return `${new Intl.NumberFormat("en-US", { maximumFractionDigits: 0 }).format(price)} ${currency}`;
}
function captionFor(listing: any) {
  const parts = [String(listing.title || "Swipess listing").trim()];
  const details = [listing.city, priceText(listing)].filter(Boolean).join(" · ");
  if (details) parts.push(details);
  const desc = String(listing.description || "").replace(/\s+/g, " ").trim();
  if (desc) parts.push(desc.slice(0, 700));
  parts.push(`${APP_ORIGIN}/listing/${listing.id}`);
  const category = String(listing.category || "listing").replace(/[^a-z0-9]/gi, "");
  parts.push(`#Swipess #${category || "listing"}`);
  return parts.join("\n\n");
}

async function publishInstagram(accessToken: string, connection: any, listing: any) {
  const version = Deno.env.get("META_GRAPH_VERSION") ?? "v23.0";
  const igId = String(connection.metadata?.instagram_id || connection.provider_account_id || "");
  if (!igId) throw new Error("instagram_account_missing");
  const video = String(listing.video_url || "").trim();
  const image = firstImage(listing.images);
  if (!video && !image) throw new Error("instagram_media_missing");
  const params = new URLSearchParams({ access_token: accessToken, caption: captionFor(listing) });
  if (video) {
    params.set("media_type", "REELS");
    params.set("video_url", video);
    params.set("share_to_feed", "true");
  } else {
    params.set("image_url", image!);
  }
  const createRes = await fetch(`https://graph.facebook.com/${version}/${igId}/media`, { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: params });
  const created = await createRes.json();
  if (!createRes.ok || !created.id) throw new Error(`instagram_create_${created.error?.message ?? createRes.status}`);
  if (video) {
    for (let i = 0; i < 18; i++) {
      await new Promise((r) => setTimeout(r, 2000));
      const statusRes = await fetch(`https://graph.facebook.com/${version}/${created.id}?fields=status_code&access_token=${encodeURIComponent(accessToken)}`);
      const status = await statusRes.json();
      if (status.status_code === "FINISHED") break;
      if (status.status_code === "ERROR" || status.status_code === "EXPIRED") throw new Error(`instagram_processing_${status.status_code}`);
    }
  }
  const publishBody = new URLSearchParams({ creation_id: String(created.id), access_token: accessToken });
  const pubRes = await fetch(`https://graph.facebook.com/${version}/${igId}/media_publish`, { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: publishBody });
  const pub = await pubRes.json();
  if (!pubRes.ok || !pub.id) throw new Error(`instagram_publish_${pub.error?.message ?? pubRes.status}`);
  return String(pub.id);
}

async function publishFacebook(accessToken: string, connection: any, listing: any) {
  const version = Deno.env.get("META_GRAPH_VERSION") ?? "v23.0";
  const pageId = String(connection.metadata?.page_id || connection.provider_account_id || "");
  if (!pageId) throw new Error("facebook_page_missing");
  const video = String(listing.video_url || "").trim();
  const image = firstImage(listing.images);
  if (!video && !image) throw new Error("facebook_media_missing");
  const endpoint = video ? "videos" : "photos";
  const body = new URLSearchParams({ access_token: accessToken });
  if (video) {
    body.set("file_url", video);
    body.set("description", captionFor(listing));
  } else {
    body.set("url", image!);
    body.set("caption", captionFor(listing));
  }
  const res = await fetch(`https://graph.facebook.com/${version}/${pageId}/${endpoint}`, { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body });
  const data = await res.json();
  if (!res.ok || (!data.id && !data.post_id)) throw new Error(`facebook_publish_${data.error?.message ?? res.status}`);
  return String(data.post_id || data.id);
}

async function tiktokCreator(accessToken: string) {
  const res = await fetch("https://open.tiktokapis.com/v2/post/publish/creator_info/query/", { method: "POST", headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json; charset=UTF-8" } });
  const data = await res.json();
  if (!res.ok || data.error?.code && data.error.code !== "ok") throw new Error(`tiktok_creator_${data.error?.message ?? res.status}`);
  const options = data.data?.privacy_level_options || [];
  const privacy = options.includes("PUBLIC_TO_EVERYONE") ? "PUBLIC_TO_EVERYONE" : options[0] || "SELF_ONLY";
  return { privacy, maxDuration: Number(data.data?.max_video_post_duration_sec || 300) };
}
async function publishTikTok(accessToken: string, listing: any) {
  const creator = await tiktokCreator(accessToken);
  const video = String(listing.video_url || "").trim();
  const images = allImages(listing.images);
  const title = captionFor(listing).slice(0, 2100);
  if (video) {
    const res = await fetch("https://open.tiktokapis.com/v2/post/publish/video/init/", {
      method: "POST",
      headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json; charset=UTF-8" },
      body: JSON.stringify({ post_info: { title, privacy_level: creator.privacy, brand_organic_toggle: true }, source_info: { source: "PULL_FROM_URL", video_url: video } }),
    });
    const data = await res.json();
    if (!res.ok || !data.data?.publish_id) throw new Error(`tiktok_publish_${data.error?.message ?? res.status}`);
    return String(data.data.publish_id);
  }
  if (!images.length) throw new Error("tiktok_media_missing");
  const res = await fetch("https://open.tiktokapis.com/v2/post/publish/content/init/", {
    method: "POST",
    headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify({ post_info: { title, description: title, privacy_level: creator.privacy }, post_mode: "DIRECT_POST", media_type: "PHOTO", source_info: { source: "PULL_FROM_URL", photo_cover_index: 0, photo_images: images } }),
  });
  const data = await res.json();
  if (!res.ok || !data.data?.publish_id) throw new Error(`tiktok_photo_${data.error?.message ?? res.status}`);
  return String(data.data.publish_id);
}

async function refreshYouTube(refreshToken: string) {
  const clientId = Deno.env.get("YOUTUBE_CLIENT_ID") ?? "";
  const secret = Deno.env.get("YOUTUBE_CLIENT_SECRET") ?? "";
  if (!clientId || !secret) throw new Error("youtube_not_configured");
  const body = new URLSearchParams({ client_id: clientId, client_secret: secret, refresh_token: refreshToken, grant_type: "refresh_token" });
  const res = await fetch("https://oauth2.googleapis.com/token", { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body });
  const data = await res.json();
  if (!res.ok || !data.access_token) throw new Error(`youtube_refresh_${data.error_description ?? data.error ?? res.status}`);
  return String(data.access_token);
}
async function publishYouTube(accessToken: string, refreshToken: string | null, expiresAt: string | null, listing: any) {
  const videoUrl = String(listing.video_url || "").trim();
  if (!videoUrl) throw new Error("youtube_requires_video");
  let token = accessToken;
  if (expiresAt && Date.parse(expiresAt) < Date.now() + 60_000 && refreshToken) token = await refreshYouTube(refreshToken);
  const metadata = {
    snippet: { title: String(listing.title || "Swipess listing").slice(0, 95), description: captionFor(listing).slice(0, 4500), tags: ["Swipess", String(listing.category || "listing")], categoryId: "22" },
    status: { privacyStatus: Deno.env.get("YOUTUBE_DEFAULT_PRIVACY") ?? "public", selfDeclaredMadeForKids: false },
  };
  const initRes = await fetch("https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status", {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json; charset=UTF-8", "X-Upload-Content-Type": "video/*" },
    body: JSON.stringify(metadata),
  });
  if (!initRes.ok) throw new Error(`youtube_init_${await initRes.text()}`);
  const uploadUrl = initRes.headers.get("location");
  if (!uploadUrl) throw new Error("youtube_upload_url_missing");
  const source = await fetch(videoUrl);
  if (!source.ok || !source.body) throw new Error(`youtube_source_${source.status}`);
  const headers: Record<string, string> = { "Content-Type": source.headers.get("content-type") || "video/mp4" };
  const length = source.headers.get("content-length");
  if (length) headers["Content-Length"] = length;
  const uploadRes = await fetch(uploadUrl, { method: "PUT", headers, body: source.body });
  const data = await uploadRes.json().catch(() => ({}));
  if (!uploadRes.ok || !data.id) throw new Error(`youtube_upload_${data.error?.message ?? uploadRes.status}`);
  return String(data.id);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  try {
    if (!SUPABASE_URL || !SERVICE_KEY || !ANON_KEY) throw new Error("server_not_configured");
    const auth = req.headers.get("Authorization") ?? "";
    const userClient = createClient(SUPABASE_URL, ANON_KEY, { global: { headers: { Authorization: auth } } });
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401, headers: cors });
    const { listing_id } = await req.json();
    if (!listing_id) return new Response(JSON.stringify({ error: "listing_id_required" }), { status: 400, headers: cors });

    const db = createClient(SUPABASE_URL, SERVICE_KEY);
    const { data: listing, error: listingError } = await db.from("listings").select("id,owner_id,title,description,city,price,currency,category,images,video_url,is_active,status").eq("id", listing_id).maybeSingle();
    if (listingError || !listing || listing.owner_id !== user.id) return new Response(JSON.stringify({ error: "listing_not_found" }), { status: 404, headers: cors });
    if (listing.is_active === false || (listing.status && !["active", "available"].includes(String(listing.status)))) return new Response(JSON.stringify({ skipped: "listing_not_active" }), { headers: cors });

    const { data: pref } = await db.from("social_distribution_preferences").select("auto_publish,providers").eq("user_id", user.id).maybeSingle();
    if (!pref?.auto_publish) return new Response(JSON.stringify({ skipped: "auto_publish_off" }), { headers: cors });
    const providers = Array.isArray(pref.providers) ? pref.providers.filter((p: string) => ["instagram","facebook","tiktok","youtube"].includes(p)) : [];
    if (!providers.length) return new Response(JSON.stringify({ skipped: "no_providers" }), { headers: cors });

    const { data: connections } = await db.from("social_connections").select("provider,provider_account_id,provider_account_name,metadata").eq("user_id", user.id).in("provider", providers);
    const { data: tokens } = await db.from("social_connection_tokens").select("provider,access_token_ciphertext,refresh_token_ciphertext,expires_at").eq("user_id", user.id).in("provider", providers);
    const connectionMap = new Map((connections || []).map((c: any) => [c.provider, c]));
    const tokenMap = new Map((tokens || []).map((t: any) => [t.provider, t]));
    const results: any[] = [];

    for (const provider of providers) {
      const connection: any = connectionMap.get(provider);
      const tokenRow: any = tokenMap.get(provider);
      const jobBase = { user_id: user.id, listing_id: listing.id, provider, payload: { title: listing.title, listing_url: `${APP_ORIGIN}/listing/${listing.id}` }, updated_at: new Date().toISOString() };
      if (!connection || !tokenRow) {
        await db.from("social_publish_jobs").insert({ ...jobBase, status: "needs_setup", error_message: "Connect this social account first." });
        results.push({ provider, status: "needs_setup" });
        continue;
      }
      const { data: job } = await db.from("social_publish_jobs").insert({ ...jobBase, status: "publishing" }).select("id").single();
      try {
        const access = await decrypt(tokenRow.access_token_ciphertext);
        const refresh = await decrypt(tokenRow.refresh_token_ciphertext);
        if (!access) throw new Error("access_token_missing");
        const postId = provider === "instagram"
          ? await publishInstagram(access, connection, listing)
          : provider === "facebook"
          ? await publishFacebook(access, connection, listing)
          : provider === "tiktok"
          ? await publishTikTok(access, listing)
          : await publishYouTube(access, refresh, tokenRow.expires_at, listing);
        await db.from("social_publish_jobs").update({ status: "published", provider_post_id: postId, updated_at: new Date().toISOString() }).eq("id", job.id);
        results.push({ provider, status: "published", post_id: postId });
      } catch (e) {
        const message = String(e).slice(0, 700);
        await db.from("social_publish_jobs").update({ status: "failed", error_message: message, updated_at: new Date().toISOString() }).eq("id", job.id);
        results.push({ provider, status: "failed", error: message });
      }
    }
    return new Response(JSON.stringify({ listing_id: listing.id, results }), { headers: cors });
  } catch (e) {
    console.error("social-distribute", e);
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: cors });
  }
});
