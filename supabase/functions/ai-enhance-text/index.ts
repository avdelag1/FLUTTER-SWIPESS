import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const ALLOWED_ORIGIN = Deno.env.get("ALLOWED_ORIGIN") || "*";
const corsHeaders = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Expose-Headers": "X-AI-Provider",
};

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") || "";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") || "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") || "";
const MAX_TEXT_BYTES = 50 * 1024;

function json(status: number, payload: unknown, provider = "swipess") {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      "X-AI-Provider": provider,
    },
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
  const { data: allowed, error } = await client.rpc(
    "rpc_has_premium_feature_access",
  );
  if (error) {
    console.error("[ai-enhance-text-v10] entitlement error", error.message);
    return json(503, { error: "Could not verify Premium access. Try again." });
  }
  if (allowed !== true) {
    return json(403, {
      error:
        "Premium membership required. AI is included during your 3-month welcome access and with Premium plans.",
    });
  }
  return null;
}

function promptFor(type: string): string {
  if (type === "profile") {
    return "You are an expert profile optimizer for Swipess. Rewrite the user's draft profile description so it is clear, professional, engaging, and easy to read. Do not invent new facts. Keep it concise. Return ONLY the polished text without conversational filler.";
  }
  if (type === "legal") {
    return "You are a legal-document editor for Swipess lease and rental agreements. Improve the provided contract draft for clarity, grammar, spelling, and consistent formatting ONLY. Do NOT remove, weaken, or invent legal clauses, parties, dates, amounts, or obligations. Preserve every substantive term exactly, keep headings and structure, and leave fill-in blanks intact. Return ONLY the cleaned-up document text.";
  }
  if (type === "legal_draft") {
    return `You are the drafting assistant inside Swipess Sign. Create a neutral, professional, editable agreement from the user's description.
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
  }
  return "You are an expert real estate and service listing copywriter for Swipess. Rewrite the user's draft into a clear, professional, highly appealing, well-structured listing description. Do not invent facts. Return ONLY the polished description without conversational filler.";
}

function temperatureFor(type: string): number {
  if (type === "legal_draft") return 0.25;
  if (type === "legal") return 0.2;
  return 0.5;
}

async function groqEnhance(
  systemPrompt: string,
  text: string,
  maxTokens: number,
  temperature: number,
): Promise<string> {
  if (!GROQ_API_KEY) throw new Error("missing GROQ_API_KEY");
  const response = await fetch(
    "https://api.groq.com/openai/v1/chat/completions",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${GROQ_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: text },
        ],
        temperature,
        max_tokens: maxTokens,
      }),
    },
  );
  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`Groq ${response.status}: ${detail.slice(0, 240)}`);
  }
  const data = await response.json();
  const polished = data?.choices?.[0]?.message?.content?.toString().trim() || "";
  if (!polished) throw new Error("Groq returned empty output");
  return polished;
}

async function geminiEnhance(
  systemPrompt: string,
  text: string,
  maxTokens: number,
  temperature: number,
): Promise<string> {
  if (!GEMINI_API_KEY) throw new Error("missing GEMINI_API_KEY");
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: systemPrompt }] },
        contents: [{ role: "user", parts: [{ text }] }],
        generationConfig: {
          maxOutputTokens: maxTokens,
          temperature,
        },
      }),
    },
  );
  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`Gemini ${response.status}: ${detail.slice(0, 240)}`);
  }
  const data = await response.json();
  const polished = data?.candidates?.[0]?.content?.parts
    ?.map((part: any) => part?.text || "")
    .join("")
    .trim() || "";
  if (!polished) throw new Error("Gemini returned empty output");
  return polished;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { error: "POST required." });
  }

  const declaredLen = Number(req.headers.get("content-length") || "0");
  if (declaredLen > MAX_TEXT_BYTES * 2) {
    return json(413, { error: "Text payload too large." });
  }

  const denied = await requirePremium(req);
  if (denied) return denied;

  try {
    const body = await req.json();
    const text = typeof body?.text === "string" ? body.text.trim() : "";
    const type = typeof body?.type === "string" ? body.type : "profile";
    if (!text) return json(400, { error: "No text provided." });
    if (text.length > MAX_TEXT_BYTES) {
      return json(413, { error: "Text too long." });
    }

    const systemPrompt = promptFor(type);
    const legalMode = type === "legal" || type === "legal_draft";
    const maxTokens = legalMode ? 4000 : 1000;
    const temperature = temperatureFor(type);
    const failures: string[] = [];

    try {
      const polished = await groqEnhance(
        systemPrompt,
        text,
        maxTokens,
        temperature,
      );
      return json(200, { text: polished }, "groq");
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      failures.push(message);
      console.error("[ai-enhance-text-v10] groq failed", message);
    }

    try {
      const polished = await geminiEnhance(
        systemPrompt,
        text,
        maxTokens,
        temperature,
      );
      return json(200, { text: polished }, "gemini");
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      failures.push(message);
      console.error("[ai-enhance-text-v10] gemini failed", message);
    }

    console.error(
      "[ai-enhance-text-v10] all providers failed",
      failures.join(" | "),
    );
    return json(503, {
      error: "AI enhancement temporarily unavailable. Please retry.",
    });
  } catch (error) {
    console.error(
      "[ai-enhance-text-v10] fatal",
      error instanceof Error ? error.message : String(error),
    );
    return json(400, { error: "Invalid enhancement request." });
  }
});
