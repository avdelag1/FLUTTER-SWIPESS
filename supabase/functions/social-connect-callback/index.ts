import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const APP_ORIGIN = (Deno.env.get("APP_ORIGIN") ?? "https://www.swipess.com").replace(/\/$/, "");
const CALLBACK_URL = Deno.env.get("SOCIAL_CALLBACK_URL") ?? `${SUPABASE_URL}/functions/v1/social-connect-callback`;
const STATE_SECRET = Deno.env.get("SOCIAL_STATE_SECRET") ?? "";
const TOKEN_KEY = Deno.env.get("SOCIAL_TOKEN_ENCRYPTION_KEY") ?? "";
const enc = new TextEncoder();
const dec = new TextDecoder();

function fromB64url(value: string) {
  const s = value.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((value.length + 3) % 4);
  const raw = atob(s);
  return Uint8Array.from(raw, (c) => c.charCodeAt(0));
}
function toB64(bytes: Uint8Array) {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s);
}
async function verifyState(state: string) {
  if (!STATE_SECRET || !state.includes(".")) throw new Error("invalid_state");
  const [body, signature] = state.split(".", 2);
  const key = await crypto.subtle.importKey("raw", enc.encode(STATE_SECRET), { name: "HMAC", hash: "SHA-256" }, false, ["verify"]);
  const ok = await crypto.subtle.verify("HMAC", key, fromB64url(signature), enc.encode(body));
  if (!ok) throw new Error("invalid_state_signature");
  const payload = JSON.parse(dec.decode(fromB64url(body)));
  if (!payload.uid || !payload.provider || Number(payload.exp ?? 0) < Date.now()) throw new Error("expired_state");
  return payload as { uid: string; provider: string; return_to?: string };
}
async function cryptoKey() {
  if (!TOKEN_KEY) throw new Error("SOCIAL_TOKEN_ENCRYPTION_KEY is not configured");
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", enc.encode(TOKEN_KEY)));
  return crypto.subtle.importKey("raw", digest, { name: "AES-GCM" }, false, ["encrypt"]);
}
async function encrypt(value: string | null | undefined) {
  if (!value) return null;
  const key = await cryptoKey();
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const cipher = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, enc.encode(value)));
  return `${toB64(iv)}.${toB64(cipher)}`;
}
function redirect(returnTo: string | undefined, params: Record<string, string>) {
  const url = new URL(returnTo || `${APP_ORIGIN}/client/settings`);
  for (const [key, value] of Object.entries(params)) url.searchParams.set(key, value);
  return Response.redirect(url.toString(), 302);
}

async function exchangeMeta(code: string, provider: string) {
  const appId = Deno.env.get("META_APP_ID") ?? "";
  const secret = Deno.env.get("META_APP_SECRET") ?? "";
  const version = Deno.env.get("META_GRAPH_VERSION") ?? "v23.0";
  if (!appId || !secret) throw new Error("meta_not_configured");
  const tokenUrl = new URL(`https://graph.facebook.com/${version}/oauth/access_token`);
  tokenUrl.search = new URLSearchParams({ client_id: appId, client_secret: secret, redirect_uri: CALLBACK_URL, code }).toString();
  const tokenRes = await fetch(tokenUrl);
  const tokenData = await tokenRes.json();
  if (!tokenRes.ok || !tokenData.access_token) throw new Error(`meta_token_${tokenData.error?.message ?? tokenRes.status}`);

  const pagesUrl = new URL(`https://graph.facebook.com/${version}/me/accounts`);
  pagesUrl.search = new URLSearchParams({ fields: "id,name,access_token,instagram_business_account{id,username}", access_token: tokenData.access_token }).toString();
  const pagesRes = await fetch(pagesUrl);
  const pagesData = await pagesRes.json();
  if (!pagesRes.ok) throw new Error(`meta_accounts_${pagesData.error?.message ?? pagesRes.status}`);
  const pages = Array.isArray(pagesData.data) ? pagesData.data : [];
  if (!pages.length) throw new Error("no_facebook_page_found");

  if (provider === "instagram") {
    const page = pages.find((p: any) => p.instagram_business_account?.id);
    if (!page) throw new Error("no_instagram_professional_account_found");
    return {
      accessToken: String(page.access_token || tokenData.access_token),
      refreshToken: null,
      expiresIn: Number(tokenData.expires_in || 0),
      accountId: String(page.instagram_business_account.id),
      accountName: String(page.instagram_business_account.username || page.name || "Instagram"),
      metadata: { page_id: String(page.id), page_name: String(page.name || ""), instagram_id: String(page.instagram_business_account.id) },
    };
  }

  const page = pages[0];
  return {
    accessToken: String(page.access_token || tokenData.access_token),
    refreshToken: null,
    expiresIn: Number(tokenData.expires_in || 0),
    accountId: String(page.id),
    accountName: String(page.name || "Facebook Page"),
    metadata: { page_id: String(page.id), page_name: String(page.name || "") },
  };
}

async function exchangeTikTok(code: string) {
  const clientKey = Deno.env.get("TIKTOK_CLIENT_KEY") ?? "";
  const secret = Deno.env.get("TIKTOK_CLIENT_SECRET") ?? "";
  if (!clientKey || !secret) throw new Error("tiktok_not_configured");
  const form = new URLSearchParams({ client_key: clientKey, client_secret: secret, code, grant_type: "authorization_code", redirect_uri: CALLBACK_URL });
  const res = await fetch("https://open.tiktokapis.com/v2/oauth/token/", { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: form });
  const data = await res.json();
  if (!res.ok || !data.access_token) throw new Error(`tiktok_token_${data.error_description ?? data.error ?? res.status}`);
  let accountName = "TikTok";
  let accountId = String(data.open_id || "");
  try {
    const userRes = await fetch("https://open.tiktokapis.com/v2/user/info/?fields=open_id,union_id,avatar_url,display_name", { headers: { Authorization: `Bearer ${data.access_token}` } });
    const userData = await userRes.json();
    const u = userData?.data?.user;
    if (u) {
      accountName = String(u.display_name || accountName);
      accountId = String(u.open_id || accountId);
    }
  } catch (_) {}
  return { accessToken: String(data.access_token), refreshToken: data.refresh_token ? String(data.refresh_token) : null, expiresIn: Number(data.expires_in || 0), accountId, accountName, metadata: { open_id: accountId } };
}

async function exchangeYouTube(code: string) {
  const clientId = Deno.env.get("YOUTUBE_CLIENT_ID") ?? "";
  const secret = Deno.env.get("YOUTUBE_CLIENT_SECRET") ?? "";
  if (!clientId || !secret) throw new Error("youtube_not_configured");
  const form = new URLSearchParams({ client_id: clientId, client_secret: secret, code, grant_type: "authorization_code", redirect_uri: CALLBACK_URL });
  const res = await fetch("https://oauth2.googleapis.com/token", { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: form });
  const data = await res.json();
  if (!res.ok || !data.access_token) throw new Error(`youtube_token_${data.error_description ?? data.error ?? res.status}`);
  let accountId = "";
  let accountName = "YouTube";
  const chRes = await fetch("https://www.googleapis.com/youtube/v3/channels?part=snippet&mine=true", { headers: { Authorization: `Bearer ${data.access_token}` } });
  if (chRes.ok) {
    const ch = await chRes.json();
    const first = ch.items?.[0];
    if (first) { accountId = String(first.id || ""); accountName = String(first.snippet?.title || accountName); }
  }
  return { accessToken: String(data.access_token), refreshToken: data.refresh_token ? String(data.refresh_token) : null, expiresIn: Number(data.expires_in || 0), accountId, accountName, metadata: { channel_id: accountId } };
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  let statePayload: { uid: string; provider: string; return_to?: string } | null = null;
  try {
    statePayload = await verifyState(url.searchParams.get("state") ?? "");
    const code = url.searchParams.get("code") ?? "";
    if (!code) throw new Error(url.searchParams.get("error") || "missing_code");
    if (!SUPABASE_URL || !SERVICE_KEY) throw new Error("server_not_configured");

    const provider = statePayload.provider;
    const token = provider === "tiktok"
      ? await exchangeTikTok(code)
      : provider === "youtube"
      ? await exchangeYouTube(code)
      : await exchangeMeta(code, provider);

    const db = createClient(SUPABASE_URL, SERVICE_KEY);
    await db.from("social_connections").upsert({
      user_id: statePayload.uid,
      provider,
      provider_account_id: token.accountId || null,
      provider_account_name: token.accountName || provider,
      metadata: token.metadata || {},
      connected_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }, { onConflict: "user_id,provider" });

    const accessCipher = await encrypt(token.accessToken);
    const refreshCipher = await encrypt(token.refreshToken);
    if (!accessCipher) throw new Error("token_encrypt_failed");
    await db.from("social_connection_tokens").upsert({
      user_id: statePayload.uid,
      provider,
      access_token_ciphertext: accessCipher,
      refresh_token_ciphertext: refreshCipher,
      expires_at: token.expiresIn > 0 ? new Date(Date.now() + token.expiresIn * 1000).toISOString() : null,
      updated_at: new Date().toISOString(),
    }, { onConflict: "user_id,provider" });

    return redirect(statePayload.return_to, { social_connected: provider, social_status: "connected" });
  } catch (e) {
    console.error("social-connect-callback", e);
    return redirect(statePayload?.return_to, { social_status: "error", social_error: String(e).slice(0, 120) });
  }
});
