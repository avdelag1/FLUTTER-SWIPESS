import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const ALLOWED_ORIGIN = Deno.env.get('ALLOWED_ORIGIN') || '*';
const corsHeaders = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") || "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") || "";
const MAX_TEXT_BYTES = 50 * 1024;

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
    console.error("[ai-enhance-text] entitlement error", error.message);
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
  if (declaredLen > MAX_TEXT_BYTES * 2) return json(413, { error: "Text payload too large." });

  const denied = await requirePremium(req);
  if (denied) return denied;

  try {
    if (!GROQ_API_KEY) throw new Error("GROQ_API_KEY is not configured.");

    const { text, type = 'profile' } = await req.json();
    if (!text || text.trim().length === 0) throw new Error("No text provided.");
    if (typeof text !== "string" || text.length > MAX_TEXT_BYTES) {
      return json(413, { error: "Text too long." });
    }

    let systemPrompt: string;
    if (type === 'profile') {
      systemPrompt = "You are an expert profile optimizer for Swipess. The user has provided a draft profile description (often dictated via voice and messy). Rewrite it to be clear, professional, engaging, and easy to read. Do not invent new facts. Keep it concise. Return ONLY the polished text without any conversational filler.";
    } else if (type === 'legal') {
      systemPrompt = "You are a legal-document editor for Swipess lease and rental agreements. Improve the provided contract draft for CLARITY, grammar, spelling and consistent formatting ONLY. You MUST NOT remove, weaken, or invent legal clauses, parties, dates, amounts or obligations — preserve every substantive term exactly. Keep section headings and structure. Leave fill-in blanks (underscores) intact. Return ONLY the cleaned-up document text, no conversational filler.";
    } else if (type === 'legal_draft') {
      systemPrompt = `You are the drafting assistant inside Swipess Sign. Create a neutral, professional, editable agreement from the user's description.

STRICT RULES:
- Do NOT claim the draft is legally valid, enforceable, reviewed by a lawyer, notarized, or compliant with a specific jurisdiction.
- Never invent names, dates, prices, addresses, IDs, license numbers, governing law, or factual promises the user did not provide.
- For missing important facts, insert clear square-bracket placeholders such as [FULL LEGAL NAME], [DATE], [AMOUNT], [ADDRESS], [GOVERNING LAW], [NOTICE PERIOD].
- Preserve every concrete fact the user supplied.
- Use plain-text section headings and numbered clauses; no HTML, Markdown tables, code fences, commentary, or preamble.
- Include signature blocks for the relevant parties at the end.
- Add a final short line: "Drafting template — review local legal requirements before signing."
- Keep the document practical and readable; avoid unnecessary legalese.
Return ONLY the document text.`;
    } else {
      systemPrompt = "You are an expert real estate and service listing copywriter for Swipess. The user has provided a draft description (often dictated via voice and messy). Rewrite it to be clear, professional, highly appealing, and structured. Do not invent facts, but make it sound premium. Return ONLY the polished text without any conversational filler.";
    }

    const legalMode = type === 'legal' || type === 'legal_draft';
    const maxTokens = legalMode ? 4000 : 1000;
    const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${GROQ_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "llama-3.1-8b-instant",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: text }
        ],
        temperature: type === 'legal_draft' ? 0.25 : (type === 'legal' ? 0.2 : 0.5),
        max_tokens: maxTokens,
      }),
    });

    if (!response.ok) {
      const err = await response.text();
      console.error("Groq Chat API Error:", err);
      throw new Error("Enhancement failed: " + err);
    }

    const data = await response.json();
    const polishedText = data.choices[0]?.message?.content || text;
    return json(200, { text: polishedText.trim() });
  } catch (err: any) {
    console.error("AI Enhance error:", err);
    return json(500, { error: err.message || "Unknown error" });
  }
});
