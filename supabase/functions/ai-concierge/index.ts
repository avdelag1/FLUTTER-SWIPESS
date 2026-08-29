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
    console.error("[ai-concierge-v81] entitlement", entitlementError.message);
    return { error: json(503, { error: "Could not verify AI access. Please retry." }, "swipess", "entitlement-error") };
  }
  if (allowed !== true) {
    return { error: json(403, { error: "Premium membership required for AI." }, "swipess", "entitlement-denied") };
  }
  return { client, user };
}

type Msg = { role: "user" | "assistant" | "system"; content: string };


function extractSeenIds(history: Msg[]): Set<string> {
  const seen = new Set<string>();
  const tags = [
    /\[LISTINGS:(\[[\s\S]*?\])\]/g,
    /\[PROFILES:(\[[\s\S]*?\])\]/g,
    /\[EVENTS:(\[[\s\S]*?\])\]/g,
    /\[LOCAL_BRAIN:(\[[\s\S]*?\])\]/g,
    /\[DRAFT:local_brain:(\{[\s\S]*?\})\]/g
  ];

  for (const m of history) {
    if (m.role !== "assistant") continue;
    for (const regex of tags) {
      let match;
      while ((match = regex.exec(m.content)) !== null) {
        try {
          const raw = match[1];
          let parsed;
          if (raw.startsWith('{')) {
             const wrapper = JSON.parse(raw);
             if (wrapper.payload) {
                parsed = JSON.parse(atob(wrapper.payload));
             }
          } else {
             parsed = JSON.parse(raw);
          }
          if (Array.isArray(parsed)) {
            for (const item of parsed) {
              if (item && typeof item === "object" && item.id) {
                seen.add(item.id.toString());
              }
            }
          }
        } catch (e) {}
      }
    }
  }
  return seen;
}

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

type UserMemoryRow = {
  id?: string;
  category?: string;
  title?: string;
  content?: string;
  tags?: string[];
  source?: string;
};

function requestTopics(query: string): string[] {
  const s = query.toLowerCase();
  const topics: Array<[string, RegExp]> = [
    ["people", /\b(people|person|users|profiles|seekers|roommate|friends|contact|someone|alguien|persona|contacto)\b/],
    ["properties", /\b(property|properties|home|house|apartment|villa|condo|rent|rental|buy|sale|casa|departamento|renta)\b/],
    ["workers", /\b(worker|service|cleaner|chef|driver|plumber|electrician|handyman|mechanic|massage|servicio|ayuda)\b/],
    ["events", /\b(event|party|tonight|concert|festival|dj|rave|evento|fiesta)\b/],
    ["dining", /\b(pizza|burger|burgers|restaurant|food|dining|comida|restaurante)\b/],
    ["bicycles", /\b(bicycle|bike|bici|bicicleta)\b/],
    ["motorcycles", /\b(motorcycle|motorbike|moto|scooter)\b/],
    ["travel", /\b(airplane|airplanes|flight|flights|jet|jets|yacht|boat|avion|vuelos)\b/],
    ["fashion", /\b(fashion|clothes|clothing|stylist|jewelry|jewellery|joyeria|joyería)\b/],
    ["jobs", /\b(job|jobs|work|career|empleo|trabajo)\b/],
  ];
  return topics.filter(([, pattern]) => pattern.test(s)).map(([topic]) => topic);
}

async function loadUserMemory(client: any, userId: string): Promise<UserMemoryRow[]> {
  try {
    const { data, error } = await client
      .from("user_memories")
      .select("id,category,title,content,tags,source")
      .eq("user_id", userId)
      .order("updated_at", { ascending: false })
      .limit(12);
    if (error) {
      console.error("[ai-concierge-v81] user memory read", error.message);
      return [];
    }
    return Array.isArray(data) ? data : [];
  } catch (e) {
    console.error("[ai-concierge-v81] user memory read", String(e));
    return [];
  }
}

async function rememberRequest(client: any, userId: string, query: string): Promise<void> {
  const topics = requestTopics(query);
  if (!topics.length) return;
  try {
    const { data: existing } = await client
      .from("user_memories")
      .select("id,tags")
      .eq("user_id", userId)
      .eq("source", "ai-auto")
      .limit(1);
    const previousTags = Array.isArray(existing?.[0]?.tags) ? existing[0].tags : [];
    const tags = [...new Set([...previousTags, ...topics])].slice(-24);
    const row = {
      user_id: userId,
      category: "preference",
      title: "AI preference profile",
      content: `The user often searches for: ${tags.join(", ")}. Most recent request: ${query.replace(/\s+/g, " ").trim().slice(0, 240)}`,
      tags,
      source: "ai-auto",
    };
    if (existing?.[0]?.id) {
      const { error } = await client.from("user_memories").update(row).eq("id", existing[0].id).eq("user_id", userId);
      if (error) console.error("[ai-concierge-v81] user memory update", error.message);
    } else {
      const { error } = await client.from("user_memories").insert(row);
      if (error) console.error("[ai-concierge-v81] user memory insert", error.message);
    }
  } catch (e) {
    // Memory is an enhancement; it must never block the answer.
    console.error("[ai-concierge-v81] user memory write", String(e));
  }
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
  return /\b(people|person|persons|users|profiles|seekers|roommate|roommates|workers|professionals|friends|contacts?|someone|somebody|alguien|persona|personas|contacto|contactos|expert|experts|specialist|specialists|who can help|need help|looking for someone|busco a|busco alguien|necesito alguien|quien me puede ayudar|quién me puede ayudar|gente)\b/i.test(q);
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

function finiteOrNull(value: unknown): number | null {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

async function loadLocalBrain(client: any, query: string, body: any) {
  try {
    const city = body?.locationContext?.passportLabel?.toString().trim() || null;
    const lat = finiteOrNull(body?.locationContext?.userLatitude);
    const lon = finiteOrNull(body?.locationContext?.userLongitude);
    const { data, error } = await client.rpc("rpc_search_local_brain", {
      p_query: query,
      p_city: city,
      p_lat: lat,
      p_lon: lon,
      p_limit: body?.locationContext?.compactDashboard === true ? 5 : 8,
    });
    if (error) {
      console.error("[ai-concierge-v80] local brain context", error.message);
      return [];
    }
    const rows = Array.isArray(data) ? data : [];
    const normalize = (value: unknown) => String(value ?? "")
      .toLowerCase()
      .replace(/[^a-z0-9áéíóúñü\s-]/g, " ")
      .replace(/\s+/g, " ")
      .trim();
    const normalizedQuery = normalize(query);
    const exactNamed = rows.filter((row: any) => {
      const name = normalize(row?.name);
      return name.length >= 3 && normalizedQuery.includes(name);
    });
    if (exactNamed.length) return exactNamed.slice(0, 1);
    const maxRows = body?.locationContext?.compactDashboard === true ? 3 : 5;
    return rows.slice(0, maxRows);
  } catch (e) {
    console.error("[ai-concierge-v80] local brain context", String(e));
    return [];
  }
}

async function loadContext(client: any, query: string, body: any, seenIds: Set<string>) {
  const preferredIntent = body?.preferredIntent?.toString().trim().toLowerCase() || "";
  const compactDashboard = body?.locationContext?.compactDashboard === true;
  const peopleFirst = preferredIntent === "profiles" || wantsPeople(query);
  const category = peopleFirst ? null : detectCategory(query);
  let listings: any[] = [];
  let events: any[] = [];
  let profiles: any[] = [];

  const localBrain = await loadLocalBrain(client, query, body);

  const applyFilters = (queryBuilder: any) => {
    if (seenIds.size > 0) {
      // Supabase not.in expects a comma-separated list or an array depending on the SDK.
      queryBuilder = queryBuilder.not("id", "in", `(${Array.from(seenIds).map(id => `"${id}"`).join(",")})`);
    }
    return queryBuilder.limit(30);
  };

  if (category) {
    try {
      


      let queryBuilder = client
        .from("listings")
        .select("id,title,price,currency,listing_type,city,neighborhood,category,images")
        .eq("is_active", true)
        .eq("status", "active")
        .eq("category", category)
        .order("updated_at", { ascending: false });
      const { data, error } = await applyFilters(queryBuilder);
      if (!error && Array.isArray(data)) listings = data;
    } catch (e) {
      console.error("[ai-concierge-v80] listings context", String(e));
    }
  }

  if (!peopleFirst && wantsEvents(query)) {
    try {
      let queryBuilder = client
        .from("events")
        .select("id,title,description,event_date,location_name")
        .eq("is_published", true)
        .order("event_date", { ascending: true });
      const { data, error } = await applyFilters(queryBuilder);
      if (!error && Array.isArray(data)) events = data;
    } catch (e) {
      console.error("[ai-concierge-v80] events context", String(e));
    }
  }

  if (peopleFirst && localBrain.length === 0) {
    try {
      // profiles use user_id instead of id for PK, so applyFilters will fail on id not in
      const applyProfiles = (qb: any) => {
         if (seenIds.size > 0) {
            qb = qb.not("user_id", "in", `(${Array.from(seenIds).map(id => `"${id}"`).join(",")})`);
         }
         return qb.limit(30);
      };
      let queryBuilder = client
        .from("profiles")
        .select("user_id,full_name,city,neighborhood,active_mode,avatar_url")
        .eq("is_active", true)
        .order("updated_at", { ascending: false });
      const { data, error } = await applyProfiles(queryBuilder);
      if (!error && Array.isArray(data)) profiles = data;
    } catch (e) {
      console.error("[ai-concierge-v80] profiles context", String(e));
    }
  }

  return { category, listings, events, profiles, localBrain, peopleFirst, compactDashboard };
}

function contextPrompt(ctx: any, body: any, history: Msg[], lastUser: string) {
  const location = body?.locationContext?.passportLabel?.toString().trim();
  const character = body?.character?.toString().trim();
  const responseLanguage = body?.locationContext?.responseLanguage?.toString().trim();
  const compactDashboard = body?.locationContext?.compactDashboard === true;
  const casualCount = recentCasualCount(history);
  const fresh = needsFreshWeb(lastUser);

  return [
    "You are SWIPESS AI, the central concierge for the SWIPESS marketplace and a capable general-purpose assistant.",
    responseLanguage
      ? `LANGUAGE LOCK: Reply only in ${responseLanguage}. The user explicitly selected this language; do not auto-detect or switch languages unless they explicitly ask you to translate.`
      : "Reply in the same language as the user's latest message unless they ask for another language.",
    "Be concise, useful, conversational, friendly, and action-oriented.",
    compactDashboard
      ? "DASHBOARD COMPACT MODE: Keep the visible prose to 1-2 short sentences. Never dump every profile or every saved detail into prose. Contact cards render separately. If one person is clearly the best match, mention only that person in prose; otherwise briefly say there are a few good matches."
      : "",
    "You may answer normal general questions, explain things, tell an occasional joke, brainstorm, and chat naturally. Do not act like every message must be a marketplace search.",
    "If the user repeatedly asks low-value entertainment questions, answer briefly but gently redirect toward something useful after roughly the third repeated request. Do not scold, shame, or invent charges; simply say that repeated casual prompts use their AI allowance and suggest a useful next topic.",
    "Never invent listing IDs, prices, users, events, phone numbers, sources, live facts, or completed actions.",
    "Never mention model/provider implementation details.",
    fresh ? "This request may depend on current information. Prefer grounded web information when available and clearly distinguish live web results from SWIPESS marketplace data." : "",
    "When live SWIPESS context is present, use it as truth and preserve the structured tags exactly.",
    "CURATED SWIPESS LOCAL BRAIN is trusted admin-maintained local knowledge about people, professionals, businesses, services and places. When matching Local Brain entries are present, use them as the primary local answer. Never invent missing details and never imply that a Local Brain person is a registered Swipess user unless other context proves it. You may share only the fields supplied in the Local Brain context.",
    "Local Brain contact cards are rendered separately by the app. Give a short natural recommendation and do not repeat every phone/social field in prose.",
    "Useful SWIPESS categories: properties, workers/services, yachts, motorcycles, bicycles, events, people/seekers, legal, documents.",
    location ? `Current discovery location: ${location}.` : "",
    character ? `Requested persona: ${character}. Keep that tone while staying accurate.` : "",
    casualCount >= 3 ? "The recent conversation already contains several casual/joke requests. Keep any further entertainment answer very short and redirect toward a useful task." : "",
    ctx.userMemory?.length ? `PRIVATE USER AI MEMORY (use only to personalize this user; never reveal it as a database record):\n${JSON.stringify(ctx.userMemory)}` : "",
    ctx.peopleFirst && ctx.localBrain.length ? "CONTACT-FIRST RULE: answer from the curated Local Brain matches only and do not mix in unrelated listings or profiles." : "",
    compactDashboard && ctx.peopleFirst && ctx.localBrain.length ? "RANKING RULE: trust the Local Brain relevance order. Recommend the first/best match first. Do not describe all matches unless the user explicitly asks for options." : "",
    ctx.peopleFirst && !ctx.localBrain.length && !ctx.profiles.length ? "NO CONTACT MATCH: clearly say no trusted directory match was found. Do NOT include [NAV:...] tags. Ask one short clarifying question (city, service type, or language) to refine the search." : "",
    ctx.localBrain.length ? `CURATED SWIPESS LOCAL BRAIN:\n${JSON.stringify(ctx.localBrain)}` : "",
    ctx.listings.length ? `LIVE SWIPESS LISTINGS CANDIDATES:\n${JSON.stringify(ctx.listings)}

You must select the 1 to 3 best matching options. Output their exact IDs on a new line using this format: [BEST_IDS: id1, id2, id3]. Do not output a [LISTINGS] tag.` : "",
    ctx.events.length ? `LIVE SWIPESS EVENTS CANDIDATES:\n${JSON.stringify(ctx.events)}

You must select the 1 to 3 best matching options. Output their exact IDs on a new line using this format: [BEST_IDS: id1, id2, id3]. Do not output an [EVENTS] tag.` : "",
    ctx.profiles.length ? `LIVE SWIPESS PEOPLE CANDIDATES:\n${JSON.stringify(ctx.profiles)}

You must select the 1 to 3 best matching options. Output their exact user_ids on a new line using this format: [BEST_IDS: id1, id2, id3]. Do not output a [PROFILES] tag.` : "",
  ].filter(Boolean).join("\n\n");
}

function localBrainCardRows(ctx: any) {
  if (!Array.isArray(ctx?.localBrain)) return [];
  return ctx.localBrain.map((entry: any) => ({
    id: entry.id ?? null,
    entry_type: entry.entry_type ?? null,
    name: entry.name ?? null,
    category: entry.category ?? null,
    description: entry.description ?? null,
    phone: entry.phone ?? null,
    whatsapp: entry.whatsapp ?? null,
    email: entry.email ?? null,
    website: entry.website ?? null,
    instagram: entry.instagram ?? null,
    facebook: entry.facebook ?? null,
    tiktok: entry.tiktok ?? null,
    youtube: entry.youtube ?? null,
    x_url: entry.x_url ?? null,
    telegram: entry.telegram ?? null,
    photo_url: entry.photo_url ?? null,
    card_image_url: entry.card_image_url ?? null,
    address: entry.address ?? null,
    neighborhood: entry.neighborhood ?? null,
    city: entry.city ?? null,
    region: entry.region ?? null,
    country: entry.country ?? null,
    latitude: entry.latitude ?? null,
    longitude: entry.longitude ?? null,
    service_radius_km: entry.service_radius_km ?? null,
    hours: entry.hours ?? null,
    price_level: entry.price_level ?? null,
    recommendation_note: entry.recommendation_note ?? null,
    is_featured: entry.is_featured === true,
    is_verified: entry.is_verified === true,
    swipess_profile_user_id: entry.swipess_profile_user_id ?? null,
    swipess_listing_id: entry.swipess_listing_id ?? null,
    distance_km: entry.distance_km ?? null,
  }));
}

function base64Utf8(value: string) {
  const bytes = new TextEncoder().encode(value);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}


function withBestMatches(text: string, ctx: any) {
  let finalContent = text;
  const match = /\[BEST_IDS:([^\]]+)\]/.exec(finalContent);
  if (match) {
    // Remove the tag from the final prose
    finalContent = finalContent.replace(match[0], "").trim();
    
    // Parse the IDs
    const ids = match[1].split(",").map(i => i.trim()).filter(Boolean);
    
    // Find matching items in candidates
    if (ctx.listings && ctx.listings.length > 0) {
      const selected = ctx.listings.filter((l: any) => ids.includes(l.id?.toString()));
      if (selected.length > 0) {
        finalContent += `\n[LISTINGS:${JSON.stringify(selected)}]`;
      }
    }
    if (ctx.events && ctx.events.length > 0) {
      const selected = ctx.events.filter((e: any) => ids.includes(e.id?.toString()));
      if (selected.length > 0) {
        finalContent += `\n[EVENTS:${JSON.stringify(selected)}]`;
      }
    }
    if (ctx.profiles && ctx.profiles.length > 0) {
      const selected = ctx.profiles.filter((p: any) => ids.includes(p.user_id?.toString()));
      if (selected.length > 0) {
        finalContent += `\n[PROFILES:${JSON.stringify(selected)}]`;
      }
    }
  }
  return finalContent;
}

function withLocalBrainCards(text: string, ctx: any) {
  const rows = localBrainCardRows(ctx);
  if (!rows.length) return text.trim();
  const payload = base64Utf8(JSON.stringify(rows));
  return `${text.trim()}\n[DRAFT:local_brain:{"payload":"${payload}"}]`;
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
  const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=${GEMINI_API_KEY}`, {
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
  if (ctx.localBrain.length) {
    const first = ctx.localBrain[0];
    const intro = ctx.compactDashboard
      ? `Best match: ${first?.name || "this contact"}.`
      : ctx.localBrain.length === 1
      ? `I found a trusted local match: ${first?.name || "this contact"}.`
      : `I found ${ctx.localBrain.length} trusted local matches for you.`;
    return withLocalBrainCards(intro, ctx);
  }
  if (ctx.listings.length) {
    return `I found live ${ctx.category ?? "matching"} options for you.\n[LISTINGS:${JSON.stringify(ctx.listings)}]`;
  }
  if (ctx.events.length) {
    return `I found live events for you.\n[EVENTS:${JSON.stringify(ctx.events)}]`;
  }
  if (ctx.profiles.length) {
    return `I found people on SWIPESS that may match what you're looking for.\n[PROFILES:${JSON.stringify(ctx.profiles)}]`;
  }
  if (ctx.peopleFirst) {
    return "I couldn’t find a trusted directory contact yet. Tell me the city and what kind of help you need — plumber, jeweler, lawyer, cleaner, etc. — and I’ll search again.";
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
  if (req.method === "GET") return json(200, { status: "ready", service: "ai-concierge", mode: "grounded-compact-local-brain-cards-v3" }, "swipess", "health");
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

    const userId = access.user.id;
    // Read memory and marketplace context concurrently so personalization does
    // not add another startup round-trip to the user's AI request.
    const [userMemory, ctx] = await Promise.all([
      loadUserMemory(client, userId),
      loadContext(client, lastUser, body, extractSeenIds(history)),
    ]);
    ctx.userMemory = userMemory;
    // Preference capture is best-effort and never delays the first token.
    void rememberRequest(client, userId, lastUser);
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
        const content = withBestMatches(withLocalBrainCards(text, ctx), ctx);
        return json(200, { choices: [{ message: { content } }] }, provider, fresh ? "grounded-or-fallback" : "provider-json");
      } catch (e) {
        const message = e instanceof Error ? e.message : String(e);
        errors.push(`${provider}:${message}`);
        console.error(`[ai-concierge-v80] ${provider} failed`, message);
      }
    }

    console.error("[ai-concierge-v80] all providers failed", errors.join(" | "));
    const local = emergencyReply(lastUser, ctx);
    return json(200, { choices: [{ message: { content: local } }] }, "swipess-local", "emergency-local");
  } catch (e) {
    console.error("[ai-concierge-v80] fatal", e instanceof Error ? e.message : String(e));
    return json(200, {
      choices: [{ message: { content: "I’m here. Ask me normally, or tell me what you want to find on SWIPESS." } }],
    }, "swipess-local", "fatal-local");
  }
});
