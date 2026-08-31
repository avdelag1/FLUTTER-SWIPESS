// Web AccessCodeGate validator.
//
// Codes never ship in the Flutter/web client. The browser posts the typed
// value; this function answers { valid, role }.
//
// Resolution order (first match wins):
// 1. CMS site_content (page swipess_gate / section secret_code)
// 2. SWIPESS_ACCESS_CODE secret
// 3. hashed rows in public.portal_access_keys (admin/owner/lawyer)
//
// Consumer-app role is always "client". Privileged portals live on
// admin.swipess.com and are authorized separately.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ENV_CODE = (Deno.env.get("SWIPESS_ACCESS_CODE") ?? "").trim();

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const jsonHeaders = {
  ...corsHeaders,
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
};

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function normalizeCode(value: string): string {
  return String(value ?? "")
    .normalize("NFKC")
    .replace(/[^a-z0-9]/gi, "")
    .toUpperCase();
}

function constantTimeEqual(left: string, right: string) {
  if (left.length !== right.length) return false;
  let diff = 0;
  for (let i = 0; i < left.length; i += 1) {
    diff |= left.charCodeAt(i) ^ right.charCodeAt(i);
  }
  return diff === 0;
}

async function sha256Hex(value: string) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest), (b) =>
    b.toString(16).padStart(2, "0"),
  ).join("");
}

function serviceClient() {
  if (!SUPABASE_URL || !SERVICE_KEY) return null;
  return createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

async function cmsCode(db: ReturnType<typeof createClient>): Promise<string> {
  try {
    const { data } = await db
      .from("site_content")
      .select("text_value")
      .eq("page_key", "swipess_gate")
      .eq("section_key", "secret_code")
      .maybeSingle();
    return String((data as { text_value?: string } | null)?.text_value ?? "")
      .trim();
  } catch {
    return "";
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ valid: false, error: "method_not_allowed" }, 405);
  }

  let submitted = "";
  try {
    const body = await req.json();
    submitted = typeof body?.code === "string" ? body.code : "";
  } catch {
    submitted = "";
  }

  const candidate = normalizeCode(submitted);
  if (candidate.length < 4 || candidate.length > 128) {
    return json({ valid: false, role: null });
  }

  const db = serviceClient();

  if (db) {
    const cms = normalizeCode(await cmsCode(db));
    if (cms && constantTimeEqual(candidate, cms)) {
      return json({ valid: true, role: "client" });
    }
  }

  const envNorm = normalizeCode(ENV_CODE);
  if (envNorm && constantTimeEqual(candidate, envNorm)) {
    return json({ valid: true, role: "client" });
  }

  if (db) {
    try {
      const codeHash = await sha256Hex(candidate);
      const { data: keys, error } = await db
        .from("portal_access_keys")
        .select("code_hash")
        .eq("is_active", true);
      if (!error) {
        const hit = (keys ?? []).some((row) =>
          constantTimeEqual(String(row.code_hash ?? ""), codeHash),
        );
        if (hit) return json({ valid: true, role: "client" });
      }
    } catch (err) {
      console.warn(
        "[validate-access-code] portal key lookup failed",
        err instanceof Error ? err.message : err,
      );
    }
  }

  return json({ valid: false, role: null });
});
