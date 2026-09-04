import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { encode } from "https://deno.land/std@0.168.0/encoding/base64.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const PROJECT_HOST = "vplgtcguxujxwrgguxqq.supabase.co";
const MAX_IMAGE_BYTES = 12 * 1024 * 1024;

const PROMPT = `You are the strict media-safety moderator for Swipess, a property, vehicle, jobs and events marketplace.
Inspect the entire image, including small text, signs, screenshots, watermarks and QR codes.

REJECT the image when it contains any of the following:
1. Explicit nudity, exposed genitals, pornography, sexual acts, sexually explicit solicitation, graphic gore, extreme violence, or clearly illegal content.
2. A phone number or WhatsApp number intended as contact information.
3. An email address.
4. A social-media username/handle intended to move contact outside Swipess, including @handles.
5. A URL, website/domain, wa.me link, social-media link, or similar external-contact link.
6. A QR code or scannable code that can redirect/contact outside Swipess.
7. An outside advertisement or promotional watermark whose purpose is to redirect users off-platform.

DO NOT reject ordinary property/unit/street numbers, prices, dates, license plates, appliance model numbers, decorative text, or a business name by itself unless it clearly functions as external contact information.

Return ONLY valid JSON with this exact shape:
{"safe":true|false,"reasons":["short reason"],"categories":["nudity|sexual|violence|illegal|phone|email|social_handle|url|qr_code|outside_ad"],"confidence":0.0}
Use safe=false if any prohibited item is clearly present. If genuinely uncertain, use safe=true with confidence below 0.65 rather than inventing a violation.`;

type Verdict = {
  safe: boolean;
  reasons: string[];
  categories: string[];
  confidence: number;
};

function response(payload: Verdict) {
  return new Response(JSON.stringify(payload), {
    headers: { ...corsHeaders, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

function cleanList(value: unknown) {
  return Array.isArray(value)
    ? value.map((v) => String(v).trim()).filter(Boolean).slice(0, 12)
    : [];
}

function parseVerdict(text: string): Verdict {
  const jsonText = text.replace(/```json/gi, "").replace(/```/g, "").trim();
  const parsed = JSON.parse(jsonText);
  return {
    safe: parsed?.safe !== false,
    reasons: cleanList(parsed?.reasons),
    categories: cleanList(parsed?.categories),
    confidence: Math.max(0, Math.min(1, Number(parsed?.confidence ?? 0.9) || 0.9)),
  };
}

async function moderateWithGroq(apiKey: string, dataUri: string) {
  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "meta-llama/llama-4-scout-17b-16e-instruct",
      messages: [{
        role: "user",
        content: [
          { type: "text", text: PROMPT },
          { type: "image_url", image_url: { url: dataUri } },
        ],
      }],
      temperature: 0.05,
      max_tokens: 420,
      response_format: { type: "json_object" },
    }),
  });
  if (!res.ok) throw new Error(`Groq vision ${res.status}: ${await res.text()}`);
  const data = await res.json();
  return parseVerdict(data?.choices?.[0]?.message?.content?.trim() ?? "");
}

async function moderateWithGemini(apiKey: string, base64: string, mimeType: string) {
  const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{
        role: "user",
        parts: [
          { text: PROMPT },
          { inlineData: { mimeType, data: base64 } },
        ],
      }],
      generationConfig: {
        temperature: 0.05,
        responseMimeType: "application/json",
      },
    }),
  });
  if (!res.ok) throw new Error(`Gemini ${res.status}: ${await res.text()}`);
  const data = await res.json();
  return parseVerdict(data?.candidates?.[0]?.content?.parts?.[0]?.text?.trim?.() ?? "");
}

async function loadImage(body: Record<string, unknown>) {
  const suppliedBase64 = String(body.imageBase64 ?? "").trim();
  const suppliedMime = String(body.mimeType ?? "image/jpeg").trim() || "image/jpeg";
  if (suppliedBase64) {
    const estimatedBytes = Math.ceil((suppliedBase64.length * 3) / 4);
    if (estimatedBytes > MAX_IMAGE_BYTES) throw new Error("image_too_large");
    return { base64: suppliedBase64, mimeType: suppliedMime };
  }

  const imageUrl = String(body.imageUrl ?? "").trim();
  if (!imageUrl) return null;
  const parsed = new URL(imageUrl);
  if (parsed.protocol !== "https:" || parsed.host !== PROJECT_HOST) {
    throw new Error("image_host_not_allowed");
  }
  const imgRes = await fetch(imageUrl, { redirect: "follow" });
  if (!imgRes.ok) throw new Error(`image_fetch_${imgRes.status}`);
  const declared = Number(imgRes.headers.get("content-length") ?? 0);
  if (declared > MAX_IMAGE_BYTES) throw new Error("image_too_large");
  const bytes = new Uint8Array(await imgRes.arrayBuffer());
  if (bytes.byteLength > MAX_IMAGE_BYTES) throw new Error("image_too_large");
  return {
    base64: encode(bytes),
    mimeType: imgRes.headers.get("content-type") || "image/jpeg",
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  if (req.method !== "POST") return response({ safe: true, reasons: [], categories: [], confidence: 1 });

  try {
    const body = await req.json() as Record<string, unknown>;
    const image = await loadImage(body);
    if (!image) return response({ safe: true, reasons: [], categories: [], confidence: 1 });

    const groq = Deno.env.get("GROQ_API_KEY");
    const gemini = Deno.env.get("GEMINI_API_KEY");
    if (!groq && !gemini) {
      console.error("[moderate-image] no moderation provider configured");
      return response({ safe: true, reasons: [], categories: [], confidence: 0 });
    }

    if (groq) {
      try {
        return response(await moderateWithGroq(groq, `data:${image.mimeType};base64,${image.base64}`));
      } catch (error) {
        console.warn("[moderate-image] Groq failed; trying Gemini", error);
      }
    }

    if (gemini) {
      return response(await moderateWithGemini(gemini, image.base64, image.mimeType));
    }

    return response({ safe: true, reasons: [], categories: [], confidence: 0 });
  } catch (error) {
    console.error("[moderate-image]", error);
    return response({ safe: true, reasons: [], categories: [], confidence: 0 });
  }
});
