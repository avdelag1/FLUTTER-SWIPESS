import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const ALLOWED_ORIGIN = Deno.env.get('ALLOWED_ORIGIN') || '*';
const corsHeaders = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") || "";
const MAX_NARRATIVE_BYTES = 50 * 1024;

function json(status: number, payload: unknown) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function requirePremium(req: Request): Promise<Response | null> {
  const authorization = req.headers.get("authorization") || "";
  if (!authorization || !SUPABASE_URL || !SUPABASE_ANON_KEY) {
    return json(401, { error: "Sign in required." });
  }
  const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: { user }, error: userError } = await client.auth.getUser();
  if (userError || !user) return json(401, { error: "Sign in required." });
  const { data: allowed, error } = await client.rpc("rpc_has_premium_feature_access");
  if (error) {
    console.error("[ai-profile-extract] entitlement error", error.message);
    return json(503, { error: "Could not verify Premium access. Try again." });
  }
  if (allowed !== true) {
    return json(403, { error: "Premium membership required. AI is included during your 3-month welcome access and with Premium plans." });
  }
  return null;
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });

  const declaredLen = Number(req.headers.get("content-length") || "0");
  if (declaredLen > MAX_NARRATIVE_BYTES * 2) return json(413, { error: "Payload too large." });

  const denied = await requirePremium(req);
  if (denied) return denied;

  try {
    const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY");
    if (!GROQ_API_KEY) return json(500, { error: "GROQ_API_KEY not configured" });

    const { mode, narrative } = await req.json();
    if (!narrative || typeof narrative !== "string" || narrative.trim().length < 5) {
      return json(400, { error: "Provide a longer narrative (min 5 chars)." });
    }
    if (narrative.length > MAX_NARRATIVE_BYTES) return json(413, { error: "Narrative too long." });

    const isOwner = mode === "owner";
    const systemPrompt = isOwner
      ? `You are a profile architect for Swipess hosts/owners. Extract structured fields from the user's description and write a polished business description. Stay faithful to the user's input. Leave fields null/empty if not mentioned. Return ONLY valid JSON with these exact keys:
{
  "business_name": string or null,
  "business_description": string (2-3 sentence polished description),
  "business_location": string or null,
  "contact_email": string or null,
  "contact_phone": string or null,
  "service_offerings": string[]
}`
      : `You are a profile architect for Swipess users. Extract structured fields from the user's description and write a cinematic first-person bio (2-3 sentences). Stay faithful to the user's input. Leave fields null/empty if not mentioned. Return ONLY valid JSON with these exact keys:
{
  "name": string or null,
  "age": number or null,
  "gender": string or null,
  "bio": string (cinematic 2-3 sentence first-person bio),
  "intentions": string[],
  "city": string or null,
  "neighborhood": string or null,
  "country": string or null,
  "nationality": string or null,
  "languages": string[],
  "interests": string[],
  "lifestyle_tags": string[],
  "occupation": string or null,
  "relationship_status": string or null,
  "smoking_habit": string or null,
  "drinking_habit": string or null
}`;

    const resp = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${GROQ_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "openai/gpt-oss-120b",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: narrative },
        ],
        temperature: 0.2,
        max_tokens: 1000,
        response_format: { type: "json_object" },
      }),
    });

    if (!resp.ok) {
      const t = await resp.text();
      console.error("[ai-profile-extract] groq error", resp.status, t);
      return json(500, { error: "Extraction failed" });
    }

    const data = await resp.json();
    const text = data?.choices?.[0]?.message?.content?.trim() ?? "";
    let profile: Record<string, unknown> | null = null;
    try {
      profile = JSON.parse(text);
    } catch {
      console.error("[ai-profile-extract] failed to parse JSON:", text);
      return json(500, { error: "Could not parse profile from response" });
    }

    if (!isOwner && profile?.bio) {
      const bio = profile.bio as string;
      if (bio.length > 240) profile.bio = bio.slice(0, 237) + "...";
    }

    return json(200, { profile });
  } catch (err) {
    console.error("[ai-profile-extract]", err);
    return json(500, { error: err instanceof Error ? err.message : "Unknown error" });
  }
});
