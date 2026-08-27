import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS, GET",
  "Access-Control-Expose-Headers": "X-AI-Provider, X-AI-Mode",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") || "";
const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") || "";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") || "";
const MOONSHOT_API_KEY = Deno.env.get("MOONSHOT_API_KEY") || "";
const MINIMAX_API_KEY = Deno.env.get("MINIMAX_API_KEY") || "";

function json(status: number, body: unknown, provider = "swipess", mode = "json") {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      "X-AI-Provider": provider,
      "X-AI-Mode": mode,
    },
  });
}

function timeout<T>(promise: Promise<T>, ms = 9000): Promise<T> {
  return Promise.race([
    promise,
    new Promise<T>((_, reject) => setTimeout(() => reject(new Error(`timeout ${ms}ms`)), ms)),
  ]);
}

function authClient(req: Request) {
  const authorization = req.headers.get("authorization") || "";
  return createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authorization } },
  });
}

async function requireAccess(req: Request) {
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    return { error: json(503, { error: "SWIPESS AI configuration unavailable." }, "swipess", "config-error") };
  }
  const authorization = req.headers.get("authorization") || "";
  if (!authorization) {
    return { error: json(401, { error: "Please sign in again to use AI." }, "swipess", "auth-error") };
  }
  const client = authClient(req);
  const { data: { user }, error: userError } = await client.auth.getUser();
  if (userError || !user) {
    return { error: json(401, { error: "Please sign in again to use AI." }, "swipess", "auth-error") };
  }
  const { data: allowed, error: entitlementError } = await client.rpc("rpc_has_premium_feature_access");
  if (entitlementError) {
    console.error("[ai-concierge-v75] entitlement", entitlementError.message);
    return { error: json(503, { error: "Could not verify AI access. Please retry." }, "swipess", "entitlement-error") };
  }
  if (allowed !== true) {
    return { error: json(403, { error: "Premium membership required for AI." }, "swipess", "entitlement-denied") };
  }
  return { client, user };
}

type Msg = { role: "user" | "assistant" | "system"; content: string };

function cleanMessages(raw: unknown): Msg[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((m: any) => m && ["user", "assistant", "system"].includes(m.role) && typeof m.content === "string")
    .slice(-12)
    .map((m: any) => ({
      role: m.role,
      content: m.content.replace(/\0/g, "").trim().slice(0, 4500),
    }))
    .filter((m: Msg) => m.content.length > 0);
}

function detectCategory(q: string): string | null {
  const s = q.toLowerCase();
  if (/\b(property|properties|home|homes|house|houses|apartment|apartments|villa|villas|condo|condos|rent|rental|buy|sale|casa|casas|departamento|departamentos|renta)\b/.test(s)) return "property";
  if (/\b(yacht|yachts|boat|boats|yate|yates)\b/.test(s)) return "yacht";
  if (/\b(motorcycle|motorcycles|motorbike|motorbikes|moto|motos|scooter|scooters)\b/.test(s)) return "motorcycle";
  if (/\b(bicycle|bicycles|bike|bikes|bici|bicicleta|bicicletas)\b/.test(s)) return "bicycle";
  if (/\b(worker|workers|service|services|cleaner|chef|driver|plumber|electrician|handyman|mechanic|massage|masseuse)\b/.test(s)) return "worker";
  return null;
}

function wantsEvents(q: string) {
  return /\b(event|events|party|parties|tonight|nightlife|concert|festival|dj|rave|happening)\b/i.test(q);
}

function wantsPeople(q: string) {
  return /\b(people|person|persons|users|profiles|seekers|roommate|roommates|workers|professionals|friends|nearby people)\b/i.test(q);
}

function needsFreshWeb(q: string) {
  return /\b(today|tonight|tomorrow|this weekend|latest|current|currently|right now|now|news|weather|score|open now|happening|event|events|concert|festival|dj|rave|schedule|price today|exchange rate|what time|time is it|recent|newest)\b/i.test(q);
}

function isCasualLowValue(q: string) {
  return /\b(joke|another joke|tell me something funny|meme|roast me|random joke|make me laugh)\b/i.test(q);
}

function recentCasualCount(history: Msg[]) {
  return history
    .filter((m) => m.role === "user")
    .slice(-6)
    .filter((m) => isCasualLowValue(m.content)).length;
}

async function loadContext(client: any, query: string) {
  const category = detectCategory(query);
  let listings: any[] = [];
  let events: any[] = [];
  let profiles: any[] = [];

  if (category) {
    try {
      const { data, error } = await client
        .from("listings")
        .select("id,title,price,currency,listing_type,city,neighborhood,category,images")
        .eq("is_active", true)
        .eq("status", "active")
        .eq("category", category)
        .order("updated_at", { ascending: false })
        .limit(3);
      if (!error && Array.isArray(data)) listings = data;
    } catch (e) {
      console.error("[ai-concierge-v75] listings context", String(e));
    }
  }

  if (wantsEvents(query)) {
    try {
      const { data, error } = await client
        .from("events")
        .select("id,title,description,event_date,location_name")
        .eq("is_published", true)
        .order("event_date", { ascending: true })
        .limit(3);
      if (!error && Array.isArray(data)) events = data;
    } catch (e) {
      console.error("[ai-concierge-v75] events context", String(e));
    }
  }

  if (wantsPeople(query)) {
    try {
      const { data, error } = await client
        .from("profiles")
        .select("user_id,full_name,city,neighborhood,active_mode,avatar_url")
        .eq("is_active", true)
        .order("updated_at", { ascending: false })
        .limit(3);
      if (!error && Array.isArray(data)) profiles = data;
    } catch (e) {
      console.error("[ai-concierge-v75] profiles context", String(e));
    }
  }

  return { category, listings, events, profiles };
}

function contextPrompt(ctx: any, body: any, history: Msg[], lastUser: string) {
  const location = body?.locationContext?.passportLabel?.toString().trim();
  const character = body?.character?.toString().trim();
  const casualCount = recentCasualCount(history);
  const fresh = needsFreshWeb(lastUser);

  return [
    "You are SWIPESS AI, the central concierge for the SWIPESS marketplace and a capable general-purpose assistant.",
    "Reply in the same language as the user's latest message unless they ask for another language.",
    "Be concise, useful, conversational, friendly, and action-oriented.",
    "You may answer normal general questions, explain things, tell an occasional joke, brainstorm, and chat naturally. Do not act like every message must be a marketplace search.",
    "If the user repeatedly asks low-value entertainment questions, answer briefly but gently redirect toward something useful after roughly the third repeated request. Do not scold, shame, or invent charges; simply say that repeated casual prompts use their AI allowance and suggest a useful next topic.",
    "Never invent listing IDs, prices, users, events, phone numbers, sources, live facts, or completed actions.",
    "Never mention model/provider implementation details.",
    fresh ? "This request may depend on current information. Prefer grounded web information when available and clearly distinguish live web results from SWIPESS marketplace data." : "",
    "When live SWIPESS context is present, use it as truth and preserve the structured tags exactly.",
    "Useful SWIPESS categories: properties, workers/services, yachts, motorcycles, bicycles, events, people/seekers, legal, documents.",
    location ? `Current discovery location: ${location}.` : "",
    character ? `Requested persona: ${character}. Keep that tone while staying accurate.` : "",
    casualCount >= 3 ? "The recent conversation already contains several casual/joke requests. Keep any further entertainment answer very short and redirect toward a useful task." : "",
    ctx.listings.length ? `LIVE SWIPESS LISTINGS:\n${JSON.stringify(ctx.listings)}` : "",
    ctx.events.length ? `LIVE SWIPESS EVENTS:\n${JSON.stringify(ctx.events)}` : "",
    ctx.profiles.length ? `LIVE SWIPESS PEOPLE:\n${JSON.stringify(ctx.profiles)}` : "",
  ].filter(Boolean).join("\n\n");
}

function openAiText(data: any): string {
  return data?.choices?.[0]?.message?.content?.toString().trim() || data?.choices?.[0]?.text?.toString().trim() || "";
}

async function groq(messages: Msg[]) {
  if (!GROQ_API_KEY) throw new Error("missing key");
  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${GROQ_API_KEY}` },
    body: JSON.stringify({ model: "openai/gpt-oss-120b", messages, max_tokens: 900, temperature: 0.55, stream: false }),
  });
  if (!res.ok) throw new Error(`http ${res.status}`);
  const text = openAiText(await res.json());
  if (!text) throw new Error("empty");
  return text;
}

async function gemini(system: string, history: Msg[], useGoogleSearch: boolean) {
  if (!GEMINI_API_KEY) throw new Error("missing key");
  const contents = history
    .filter((m) => m.role !== "system")
    .map((m) => ({ role: m.role === "assistant" ? "model" : "user", parts: [{ text: m.content }] }));
  const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: system }] },
      contents,
      ...(useGoogleSearch ? { tools: [{ google_search: {} }] } : {}),
      generationConfig: { maxOutputTokens: 900, temperature: 0.55 },
    }),
  });
  if (!res.ok) throw new Error(`http ${res.status}`);
  const data = await res.json();
  const text = data?.candidates?.[0]?.content?.parts?.map((p: any) => p?.text || "").join("").trim() || "";
  if (!text) throw new Error("empty");
  return text;
}

async function kimi(messages: Msg[]) {
  if (!MOONSHOT_API_KEY) throw new Error("missing key");
  const res = await fetch("https://api.moonshot.cn/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${MOONSHOT_API_KEY}` },
    body: JSON.stringify({ model: "moonshot-v1-8k", messages, max_tokens: 900, temperature: 0.5, stream: false }),
  });
  if (!res.ok) throw new Error(`http ${res.status}`);
  const text = openAiText(await res.json());
  if (!text) throw new Error("empty");
  return text;
}

async function minimax(messages: Msg[]) {
  if (!MINIMAX_API_KEY) throw new Error("missing key");
  const res = await fetch("https://api.minimaxi.chat/v1/text/chatcompletion_v2", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${MINIMAX_API_KEY}` },
    body: JSON.stringify({ model: "MiniMax-M2.7", messages, max_tokens: 900, temperature: 0.5, stream: false }),
  });
  if (!res.ok) throw new Error(`http ${res.status}`);
  const data = await res.json();
  const text = openAiText(data) || data?.reply?.toString().trim() || "";
  if (!text) throw new Error("empty");
  return text;
}

function emergencyReply(query: string, ctx: any) {
  if (ctx.listings.length) {
    return `I found live ${ctx.category ?? "matching"} options for you.\n[LISTINGS:${JSON.stringify(ctx.listings)}]`;
  }
  if (ctx.events.length) {
    return `I found live events for you.\n[EVENTS:${JSON.stringify(ctx.events)}]`;
  }
  if (ctx.profiles.length) {
    return `I found people on SWIPESS that may match what you're looking for.\n[PROFILES:${JSON.stringify(ctx.profiles)}]`;
  }
  if (/^\s*(hi|hey|hello|hola|buenas|yo|sup)\b/i.test(query)) {
    return "Hey — I’m here. Ask me normally, or tell me what you want to find on SWIPESS.";
  }
  if (/\b(joke|make me laugh)\b/i.test(query)) {
    return "Sure — one quick one: Why did the developer go broke? Because he used up all his cache. 😄 What do you actually want to find or solve next?";
  }
  return "I’m here. Ask me normally, or tell me what you want to find on SWIPESS — properties, workers, events, yachts, motorcycles, bicycles, people, legal help, or documents.";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method === "GET") return json(200, { status: "ready", service: "ai-concierge", mode: "grounded-flexible" }, "swipess", "health");
  if (req.method !== "POST") return json(405, { error: "POST required" });
  if (Number(req.headers.get("content-length") || "0") > 128 * 1024) return json(413, { error: "Request too large" });

  try {
    const access = await requireAccess(req);
    if (access.error) return access.error;
    const client = access.client;

    const body = await req.json();
    const history = cleanMessages(body?.messages);
    const lastUser = [...history].reverse().find((m) => m.role === "user")?.content || "";
    if (!lastUser) return json(400, { error: "At least one user message is required" });

    const ctx = await loadContext(client, lastUser);
    const fresh = needsFreshWeb(lastUser);
    const system = contextPrompt(ctx, body, history, lastUser);
    const modelMessages: Msg[] = [
      { role: "system", content: system },
      ...history.filter((m) => m.role !== "system"),
    ];

    const standardAttempts: Array<[string, () => Promise<string>]> = [
      ["groq", () => timeout(groq(modelMessages))],
      ["gemini", () => timeout(gemini(system, history, false), 12000)],
      ["kimi", () => timeout(kimi(modelMessages))],
      ["minimax", () => timeout(minimax(modelMessages))],
    ];
    const freshAttempts: Array<[string, () => Promise<string>]> = [
      ["gemini-google-search", () => timeout(gemini(system, history, true), 15000)],
      ["groq", () => timeout(groq(modelMessages))],
      ["kimi", () => timeout(kimi(modelMessages))],
      ["minimax", () => timeout(minimax(modelMessages))],
    ];
    const attempts = fresh ? freshAttempts : standardAttempts;

    const errors: string[] = [];
    for (const [provider, run] of attempts) {
      try {
        const text = (await run()).trim();
        if (!text || /^(AI )?temporarily unavailable/i.test(text)) throw new Error("provider returned outage text");
        return json(200, { choices: [{ message: { content: text } }] }, provider, fresh ? "grounded-or-fallback" : "provider-json");
      } catch (e) {
        const message = e instanceof Error ? e.message : String(e);
        errors.push(`${provider}:${message}`);
        console.error(`[ai-concierge-v75] ${provider} failed`, message);
      }
    }

    console.error("[ai-concierge-v75] all providers failed", errors.join(" | "));
    const local = emergencyReply(lastUser, ctx);
    return json(200, { choices: [{ message: { content: local } }] }, "swipess-local", "emergency-local");
  } catch (e) {
    console.error("[ai-concierge-v75] fatal", e instanceof Error ? e.message : String(e));
    return json(200, {
      choices: [{ message: { content: "I’m here. Ask me normally, or tell me what you want to find on SWIPESS." } }],
    }, "swipess-local", "fatal-local");
  }
});