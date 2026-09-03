import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
const APP_ORIGIN = (Deno.env.get("APP_ORIGIN") ?? "https://www.swipess.com").replace(/\/$/, "");
const CALLBACK_URL = Deno.env.get("SOCIAL_CALLBACK_URL") ?? `${SUPABASE_URL}/functions/v1/social-connect-callback`;
const STATE_SECRET = Deno.env.get("SOCIAL_STATE_SECRET") ?? "";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};

const enc = new TextEncoder();
function b64url(bytes: Uint8Array) {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}
async function signState(payload: Record<string, unknown>) {
  if (!STATE_SECRET) throw new Error("SOCIAL_STATE_SECRET is not configured");
  const body = b64url(enc.encode(JSON.stringify(payload)));
  const key = await crypto.subtle.importKey("raw", enc.encode(STATE_SECRET), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", key, enc.encode(body)));
  return `${body}.${b64url(sig)}`;
}

function config(provider: string) {
  if (provider === "instagram" || provider === "facebook") {
    const clientId = Deno.env.get("META_APP_ID") ?? "";
    const clientSecret = Deno.env.get("META_APP_SECRET") ?? "";
    const version = Deno.env.get("META_GRAPH_VERSION") ?? "v23.0";
    const scopes = Deno.env.get("META_OAUTH_SCOPES") ?? "public_profile,pages_show_list,pages_read_engagement,pages_manage_posts,instagram_basic,instagram_content_publish,business_management";
    return { clientId, clientSecret, version, scopes };
  }
  if (provider === "tiktok") {
    return {
      clientId: Deno.env.get("TIKTOK_CLIENT_KEY") ?? "",
      clientSecret: Deno.env.get("TIKTOK_CLIENT_SECRET") ?? "",
      scopes: Deno.env.get("TIKTOK_SCOPES") ?? "user.info.basic,video.publish,video.upload",
    };
  }
  if (provider === "youtube") {
    return {
      clientId: Deno.env.get("YOUTUBE_CLIENT_ID") ?? "",
      clientSecret: Deno.env.get("YOUTUBE_CLIENT_SECRET") ?? "",
      scopes: Deno.env.get("YOUTUBE_SCOPES") ?? "https://www.googleapis.com/auth/youtube.upload https://www.googleapis.com/auth/youtube.readonly",
    };
  }
  return { clientId: "", clientSecret: "", scopes: "" };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  try {
    const auth = req.headers.get("Authorization") ?? "";
    if (!auth || !SUPABASE_URL || !SUPABASE_ANON_KEY) return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401, headers: cors });
    const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: auth } } });
    const { data: { user }, error } = await client.auth.getUser();
    if (error || !user) return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401, headers: cors });

    const body = await req.json().catch(() => ({}));
    const provider = String(body.provider ?? "").toLowerCase();
    if (!["instagram", "facebook", "tiktok", "youtube"].includes(provider)) {
      return new Response(JSON.stringify({ error: "unsupported_provider" }), { status: 400, headers: cors });
    }
    const c = config(provider);
    const missing = [];
    if (!c.clientId) missing.push("client_id");
    if (!c.clientSecret) missing.push("client_secret");
    if (!STATE_SECRET) missing.push("SOCIAL_STATE_SECRET");
    if (missing.length) {
      return new Response(JSON.stringify({ configured: false, provider, missing }), { status: 412, headers: cors });
    }

    const state = await signState({
      uid: user.id,
      provider,
      exp: Date.now() + 10 * 60 * 1000,
      nonce: crypto.randomUUID(),
      return_to: `${APP_ORIGIN}/client/settings?social_connected=${provider}`,
    });

    let authUrl = "";
    if (provider === "instagram" || provider === "facebook") {
      const p = new URLSearchParams({ client_id: c.clientId, redirect_uri: CALLBACK_URL, response_type: "code", scope: c.scopes, state });
      authUrl = `https://www.facebook.com/${c.version}/dialog/oauth?${p}`;
    } else if (provider === "tiktok") {
      const p = new URLSearchParams({ client_key: c.clientId, redirect_uri: CALLBACK_URL, response_type: "code", scope: c.scopes, state });
      authUrl = `https://www.tiktok.com/v2/auth/authorize/?${p}`;
    } else {
      const p = new URLSearchParams({ client_id: c.clientId, redirect_uri: CALLBACK_URL, response_type: "code", scope: c.scopes, access_type: "offline", prompt: "consent", include_granted_scopes: "true", state });
      authUrl = `https://accounts.google.com/o/oauth2/v2/auth?${p}`;
    }

    return new Response(JSON.stringify({ configured: true, provider, auth_url: authUrl }), { headers: cors });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: cors });
  }
});
