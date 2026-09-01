// AI Listing Extractor — Premium/welcome-access gated structured listing helper.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const ALLOWED_ORIGIN = Deno.env.get("ALLOWED_ORIGIN") || "*";
const corsHeaders = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") || "";
const MAX_PROMPT_BYTES = 50 * 1024;

interface Body {
  task?: "extract" | "refine";
  category?: string;
  price?: string | number;
  currency?: string;
  city?: string;
  prompt?: string;
}

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
  const {
    data: { user },
    error: userError,
  } = await client.auth.getUser();
  if (userError || !user) return json(401, { error: "Sign in required." });

  const { data: allowed, error } = await client.rpc(
    "rpc_has_premium_feature_access",
  );
  if (error) {
    console.error("[ai-listing-extract] entitlement error", error.message);
    return json(503, {
      error: "Could not verify Premium access. Try again.",
    });
  }
  if (allowed !== true) {
    return json(403, {
      error:
        "Premium membership required. AI is included during your 3-month welcome access and with Premium plans.",
    });
  }
  return null;
}

const AMENITY_VOCAB: Record<string, string[]> = {
  property: [
    "Private Pool",
    "Shared Pool",
    "Gym",
    "Parking",
    "Garage",
    "Carport",
    "AC",
    "WiFi",
    "Security 24/7",
    "Security Cameras",
    "Garden",
    "Balcony",
    "Terrace",
    "Rooftop",
    "Elevator",
    "Storage",
    "Workspace",
    "Office Space",
    "2-in-1 Washer/Dryer",
    "Separate Washer & Dryer",
    "Laundry Room",
    "Washer",
    "Dishwasher",
    "Gas Stove",
    "Water Filter / Osmosis",
    "Smart-home",
    "Solar Panels",
    "Backup water",
    "Sea View",
    "Mountain View",
    "Garden View",
    "Outdoor Kitchen",
    "BBQ",
    "Hot Tub",
    "Sauna",
    "Walk-in Closet",
    "Fireplace",
    "Mosquito Net",
    "Sublease Option",
    "Water",
    "Electricity",
    "Gas",
    "Internet",
    "Cleaning",
    "Maintenance",
    "Trash",
    "Cable TV",
    "Quiet",
    "Lively",
    "Family-friendly",
    "Pet-friendly",
    "Beachfront",
    "Jungle",
    "Downtown",
    "Gated",
    "Eco",
  ],
  motorcycle: [
    "ABS",
    "ESC",
    "Traction control",
    "Heated grips",
    "Luggage rack",
    "Crash bars",
    "Quick-shifter",
    "Bluetooth",
    "Helmet",
    "Riding gear",
    "Lock",
    "Top case",
    "Charger",
    "Insurance",
    "Roadside assistance",
  ],
  bicycle: [
    "Front suspension",
    "Full suspension",
    "Disc brakes",
    "Carbon frame",
    "Aluminum frame",
    "Tubeless",
    "Dropper post",
    "Lock",
    "Lights",
    "Basket",
    "Pump",
    "Helmet",
    "Repair kit",
  ],
  yacht: [
    "Air conditioning",
    "WiFi",
    "Flybridge",
    "Watermaker",
    "Tender",
    "Stabilizers",
    "Solar panels",
    "Bow thruster",
    "GPS / Chartplotter",
    "Autopilot",
    "Sun deck",
    "Jacuzzi",
    "Captain",
    "Crew",
    "Fuel",
    "Insurance",
    "Snorkel gear",
    "Paddleboard",
    "Dinghy",
    "Safety equipment",
  ],
  worker: [
    "Punctual",
    "Detail-oriented",
    "English-speaking",
    "Spanish-speaking",
    "Insured",
    "Background-checked",
    "Own tools",
    "Own vehicle",
    "Emergency available",
  ],
};

const PROPERTY_TYPES = [
  "penthouse",
  "house",
  "apartment",
  "loft",
  "studio",
  "mobile_home",
  "camper",
  "land",
  "building",
  "glamping",
  "bungalow",
  "mezzanine",
  "room",
  "commercial",
];
const MOTORCYCLE_TYPES = [
  "Sport Bike",
  "Cruiser",
  "Touring",
  "Adventure",
  "Dual-Sport",
  "Dirt Bike",
  "Standard",
  "Cafe Racer",
  "Chopper",
  "Scooter",
  "Electric",
  "Other",
];
const BICYCLE_TYPES = [
  "road",
  "mountain",
  "hybrid",
  "electric",
  "cruiser",
  "bmx",
];
const YACHT_TYPES = [
  "Sailboat",
  "Catamaran",
  "Motor yacht",
  "Gulet",
  "Speedboat",
  "Trawler",
  "Pontoon",
  "Houseboat",
];
const SERVICE_CATEGORIES = [
  "house_cleaner",
  "handyman",
  "maintenance_tech",
  "house_painter",
  "plumber",
  "electrician",
  "gardener",
  "pool_cleaner",
  "massage_therapist",
  "yoga",
  "meditation_coach",
  "holistic_therapist",
  "personal_trainer",
  "beauty",
  "nutritionist",
  "nanny",
  "pet_care",
  "pet_groomer",
  "driver",
  "mechanic",
  "chef",
  "bartender",
  "event_planner",
  "language_teacher",
  "music_teacher",
  "dance_instructor",
  "scuba_instructor",
  "surf_instructor",
  "snorkeling_guide",
  "sailing_instructor",
  "fishing_guide",
  "photographer",
  "videographer",
  "graphic_designer",
  "it_support",
  "translator",
  "accountant",
  "security",
  "other",
];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  const declaredLen = Number(req.headers.get("content-length") || "0");
  if (declaredLen > MAX_PROMPT_BYTES * 2) {
    return json(413, { error: "Payload too large" });
  }

  const denied = await requirePremium(req);
  if (denied) return denied;

  try {
    const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY");
    if (!GROQ_API_KEY) {
      return json(500, { error: "GROQ_API_KEY not configured" });
    }

    const body = (await req.json().catch(() => ({}))) as Body;
    const task = body.task ?? "extract";
    const prompt = (body.prompt || "").trim();
    if (!prompt) return json(400, { error: "Missing prompt" });
    if (prompt.length > MAX_PROMPT_BYTES) {
      return json(413, { error: "Prompt too long" });
    }

    async function callGroq(
      systemContent: string,
      userContent: string,
      jsonMode = true,
    ) {
      const res = await fetch(
        "https://api.groq.com/openai/v1/chat/completions",
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${GROQ_API_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            model: "openai/gpt-oss-120b",
            messages: [
              { role: "system", content: systemContent },
              { role: "user", content: userContent },
            ],
            temperature: 0.2,
            max_tokens: 1900,
            ...(jsonMode
              ? { response_format: { type: "json_object" } }
              : {}),
          }),
        },
      );

      if (!res.ok) {
        const t = await res.text();
        console.error("[ai-listing-extract] groq error", res.status, t);
        throw new Error(
          res.status === 429 ? "Rate limit" : `Groq ${res.status}: ${t}`,
        );
      }

      const data = await res.json();
      return data?.choices?.[0]?.message?.content?.trim() ?? "";
    }

    if (task === "refine") {
      const text = await callGroq(
        "You are an elite listing copywriter for Swipess. Rewrite the user's raw spoken input into a sharp, professional, high-converting listing description. Keep it concise (2-4 sentences), confident, and factual. Do not invent details. Do not add placeholders. Return ONLY the rewritten description, no preamble.",
        prompt,
        false,
      );
      return json(200, { text: text || prompt });
    }

    const hintCategory = body.category || "property";
    const sys = `You parse natural-language marketplace listings for Swipess into structured JSON. The user may dictate in any language.

Detect exactly one category: property, motorcycle, bicycle, yacht, worker. The user pre-selected "${hintCategory}"; only override if their words clearly describe another category. Never invent facts. Use null for missing scalar values and [] for missing list values.

The explicit base price and base city are authoritative and must not be replaced by guesses.
Base price: ${body.price ?? "(unknown)"}
Base city: ${body.city ?? "(unknown)"}
Base currency: ${body.currency ?? "(read an explicit USD/MXN value from the user prompt if present)"}

Exact vocabularies:
mode: rent, sale, both
currency: USD, MXN
property_type: ${JSON.stringify(PROPERTY_TYPES)}
motorcycle_type: ${JSON.stringify(MOTORCYCLE_TYPES)}
bicycle_type: ${JSON.stringify(BICYCLE_TYPES)}
yacht_type: ${JSON.stringify(YACHT_TYPES)}
service_category: ${JSON.stringify(SERVICE_CATEGORIES)}
pricing_unit: hourly, daily, weekly, monthly, project
condition: excellent, good, fair, poor

Amenities must only use the matching canonical list:
property: ${JSON.stringify(AMENITY_VOCAB.property)}
motorcycle: ${JSON.stringify(AMENITY_VOCAB.motorcycle)}
bicycle: ${JSON.stringify(AMENITY_VOCAB.bicycle)}
yacht: ${JSON.stringify(AMENITY_VOCAB.yacht)}
worker: ${JSON.stringify(AMENITY_VOCAB.worker)}

Fill every filter that is clearly supported by the user's words. Do not leave a supported filter empty just because it was spoken casually. Examples: bedrooms/bathrooms, furnished, pets, rental duration, neighborhood, vehicle make/model/year/type/condition/features/included gear, yacht length/berths/passengers, worker service category/skills/traits/availability/languages/pricing unit.

Create an attractive factual title <= 70 chars and a concise professional English description.

Return ONLY valid JSON with all keys:
{
  "category":"property|motorcycle|bicycle|yacht|worker",
  "mode":"rent|sale|both|null",
  "title":string,
  "description":string,
  "price":number|null,
  "currency":"USD|MXN|null",
  "city":string|null,
  "country":string|null,
  "neighborhood":string|null,

  "adjectives":[],
  "sizes":[],
  "beds":number|string|null,
  "baths":number|null,
  "property_type":string|null,
  "furnished":boolean|null,
  "pet_friendly":boolean|null,
  "rental_duration":string|null,
  "vibe":[],
  "amenities":[],
  "included":[],
  "rules":[],

  "year":number|null,
  "make":string|null,
  "model":string|null,
  "engine_cc":number|null,
  "mileage":number|null,
  "motorcycle_type":string|null,
  "bicycle_type":string|null,
  "condition":string|null,
  "features":[],
  "vehicle_included":[],
  "frame_size":string|null,

  "yacht_type":string|null,
  "length_m":number|null,
  "berths":number|null,
  "max_passengers":number|null,

  "service_category":string|null,
  "pricing_unit":string|null,
  "traits":[],
  "skills":[],
  "availability":[],
  "languages":[]
}`;

    const result = await callGroq(sys, prompt);
    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(result);
    } catch {
      console.error(
        "[ai-listing-extract] failed to parse groq JSON:",
        result,
      );
      return json(500, { error: "Extract failed" });
    }

    const validCategories = [
      "property",
      "motorcycle",
      "bicycle",
      "yacht",
      "worker",
    ];
    if (!validCategories.includes(parsed.category as string)) {
      parsed.category = validCategories.includes(hintCategory)
        ? hintCategory
        : "property";
    }

    const userPrice = Number(body.price);
    if (Number.isFinite(userPrice) && userPrice > 0) {
      parsed.price = userPrice;
    }
    if (body.city) parsed.city = body.city;

    const requestedCurrency = String(body.currency || "").toUpperCase();
    if (requestedCurrency === "USD" || requestedCurrency === "MXN") {
      parsed.currency = requestedCurrency;
    } else {
      const parsedCurrency = String(parsed.currency || "").toUpperCase();
      if (parsedCurrency !== "USD" && parsedCurrency !== "MXN") {
        parsed.currency = null;
      } else {
        parsed.currency = parsedCurrency;
      }
    }

    return json(200, { data: parsed });
  } catch (err) {
    console.error("[ai-listing-extract] unexpected error", err);
    return json(500, {
      error: err instanceof Error ? err.message : "Unknown error",
    });
  }
});
