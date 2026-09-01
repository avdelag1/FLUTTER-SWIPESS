// Public edge function for share links.
// Crawlers receive Open Graph/Twitter HTML. Real people receive an HTTP redirect
// to the actual Swipess route so Instagram/WhatsApp/TikTok in-app browsers never
// display the preview HTML as source text.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
  "";
const DEFAULT_APP_ORIGIN = (Deno.env.get("APP_ORIGIN") ?? "https://www.swipess.com").replace(/\/$/, "");

if (!SUPABASE_URL) {
  throw new Error("SUPABASE_URL environment variable is required");
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function escapeHtml(s: string): string {
  return String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function isBrowserNavigation(req: Request): boolean {
  const mode = (req.headers.get("sec-fetch-mode") ?? "").toLowerCase();
  const dest = (req.headers.get("sec-fetch-dest") ?? "").toLowerCase();
  if (mode === "navigate" || dest === "document") return true;

  // Some social WebViews omit Sec-Fetch headers. Their real browser UA still
  // contains Mozilla/5.0, while link-preview fetchers generally do not.
  const ua = (req.headers.get("user-agent") ?? "").toLowerCase();
  return ua.includes("mozilla/5.0") &&
    /instagram|whatsapp|tiktok|bytedance|fban|fbav|messenger|telegram|snapchat|line\/|wechat/.test(ua);
}

function isCrawler(req: Request): boolean {
  if (isBrowserNavigation(req)) return false;
  const ua = (req.headers.get("user-agent") ?? "").toLowerCase();
  if (!ua) return false;
  return /whatsapp|instagram|tiktok|bytedance|telegrambot|facebookexternalhit|facebot|twitterbot|slackbot|slack-imgproxy|discordbot|linkedinbot|skypeuripreview|applebot|googlebot|bingbot|embedly|redditbot|pinterestbot|vkshare|tumblr|w3c_validator|yahoo|duckduckbot|imessagepreview|messengerbot|kakaotalk|viber|baiduspider|yandex|qwantify|petalbot|mastodon|fediverse|iframely|opengraph/.test(ua);
}

function absolutize(maybeUrl: string | null | undefined, base: string): string | null {
  if (!maybeUrl) return null;
  const s = String(maybeUrl).trim();
  if (!s) return null;
  if (/^https?:\/\//i.test(s)) return s;
  if (s.startsWith("//")) return `https:${s}`;
  if (s.startsWith("/")) return `${base}${s}`;
  return `${base}/${s}`;
}

function truncate(value: unknown, max = 220): string {
  const text = String(value ?? "").replace(/\s+/g, " ").trim();
  if (text.length <= max) return text;
  return `${text.slice(0, Math.max(0, max - 1)).trimEnd()}…`;
}

function cleanPart(value: unknown): string | null {
  const s = String(value ?? "").replace(/\s+/g, " ").trim();
  return s ? s : null;
}

function formatPrice(value: unknown, currencyValue: unknown): string | null {
  if (value === null || value === undefined || value === "") return null;
  const n = Number(value);
  if (!Number.isFinite(n)) return cleanPart(value);
  const currency = cleanPart(currencyValue)?.toUpperCase() || "USD";
  try {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency,
      maximumFractionDigits: n % 1 === 0 ? 0 : 2,
    }).format(n);
  } catch (_) {
    return `${n.toLocaleString("en-US")} ${currency}`;
  }
}

function renderHtml(opts: {
  title: string;
  description: string;
  image: string;
  url: string;
}): string {
  const { title, description, image, url } = opts;
  const t = escapeHtml(title);
  const d = escapeHtml(description);
  const i = escapeHtml(image);
  const u = escapeHtml(url);

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>${t}</title>
<meta name="description" content="${d}" />

<meta property="og:type" content="website" />
<meta property="og:site_name" content="Swipess" />
<meta property="og:title" content="${t}" />
<meta property="og:description" content="${d}" />
<meta property="og:image" content="${i}" />
<meta property="og:image:secure_url" content="${i}" />
<meta property="og:image:alt" content="${t}" />
<meta property="og:url" content="${u}" />
<meta property="og:locale" content="en_US" />

<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:url" content="${u}" />
<meta name="twitter:title" content="${t}" />
<meta name="twitter:description" content="${d}" />
<meta name="twitter:image" content="${i}" />
<meta name="twitter:image:alt" content="${t}" />
<meta name="theme-color" content="#050505" />

<link rel="canonical" href="${u}" />
</head>
<body style="margin:0;background:#000;color:#fff;font-family:-apple-system,system-ui,sans-serif;">
<div style="display:flex;flex-direction:column;align-items:center;justify-content:center;min-height:100vh;padding:24px;text-align:center;gap:16px;">
<img src="${i}" alt="${t}" style="max-width:100%;max-height:60vh;border-radius:24px;box-shadow:0 20px 60px rgba(0,0,0,0.5);" />
<h1 style="font-size:20px;font-weight:900;margin:0;">${t}</h1>
<p style="opacity:0.7;font-size:14px;margin:0;">${d}</p>
<a href="${u}" style="margin-top:8px;padding:14px 28px;border-radius:32px;background:linear-gradient(180deg,#FF4D4D,#E01E2A);color:#fff;font-weight:900;text-decoration:none;letter-spacing:0.15em;text-transform:uppercase;font-size:12px;">Open in Swipess</a>
</div>
</body>
</html>`;
}

function pickFirstImage(images: unknown): string | null {
  if (!Array.isArray(images)) return null;
  for (const v of images) {
    if (typeof v === "string" && v.trim()) return v;
    if (v && typeof v === "object") {
      const record = v as Record<string, unknown>;
      for (const key of ["url", "image_url", "src"]) {
        const candidate = record[key];
        if (typeof candidate === "string" && candidate.trim()) return candidate;
      }
    }
  }
  return null;
}

function pickImageFromRecord(record: Record<string, unknown>, keys: string[]): string | null {
  for (const key of keys) {
    const value = record[key];
    if (typeof value === "string" && value.trim()) return value;
    const picked = pickFirstImage(value);
    if (picked) return picked;
  }
  return null;
}

function getFallbackImage(appOrigin: string): string {
  return `${appOrigin}/favicon.png`;
}

function listingDescription(record: Record<string, unknown>, fallback: string): string {
  const bedrooms = record.bedrooms ?? record.beds;
  const bathrooms = record.bathrooms ?? record.baths;
  const location = [record.neighborhood, record.city, record.state, record.country]
    .map(cleanPart)
    .filter(Boolean)
    .filter((v, i, a) => a.indexOf(v) === i)
    .join(", ") || cleanPart(record.location) || cleanPart(record.address);

  const price = formatPrice(record.price ?? record.hourly_rate, record.currency);
  const unit = cleanPart(record.pricing_unit);
  const detailParts = [
    bedrooms ? `${bedrooms} bedroom${Number(bedrooms) === 1 ? "" : "s"}` : null,
    bathrooms ? `${bathrooms} bathroom${Number(bathrooms) === 1 ? "" : "s"}` : null,
    location || null,
    price ? `${price}${unit ? ` / ${unit}` : ""}` : null,
  ].filter(Boolean) as string[];

  const rawDescription = cleanPart(record.description);
  const descriptionIsOnlyLocation = rawDescription && location && rawDescription.toLowerCase() === location.toLowerCase();
  const parts: string[] = [];
  if (detailParts.length) parts.push(detailParts.join(" · "));
  if (rawDescription && !descriptionIsOnlyLocation) parts.push(rawDescription);
  parts.push("View photos and details on Swipess.");

  return truncate(parts.filter(Boolean).join(" — ") || fallback, 240);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const forwardedHost = req.headers.get("x-forwarded-host") || req.headers.get("x-original-host") || "";
  const forwardedProto = req.headers.get("x-forwarded-proto") || "https";
  const appOrigin = forwardedHost && !forwardedHost.includes("supabase.co")
    ? `${forwardedProto}://${forwardedHost}`.replace(/\/$/, "")
    : DEFAULT_APP_ORIGIN;

  const parts = url.pathname.split("/").filter(Boolean);
  const kind = parts[1];
  const id = parts[2];

  const fallbackImage = getFallbackImage(appOrigin);
  const fallbackTitle = "Swipess | Find Your Best Deal";
  const fallbackDesc = "Swipe through properties, vehicles, services, events, and more on Swipess.";

  let title = fallbackTitle;
  let description = fallbackDesc;
  let image = fallbackImage;
  let canonical = appOrigin;

  try {
    if (!id) throw new Error("missing id");
    if (!SUPABASE_KEY) throw new Error("missing Supabase key");
    const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

    if (kind === "listing") {
      // Shared listings must be guest-readable in the browser. Native /s/*
      // links still open the installed app through Universal/App Links.
      canonical = `${appOrigin}/preview/listing/${id}`;
      const { data, error } = await supabase
        .from("listings")
        .select("title, description, city, neighborhood, state, country, location, address, price, currency, hourly_rate, pricing_unit, beds, baths, bedrooms, bathrooms, images, category, listing_type, property_type, vehicle_brand, vehicle_model, year, custom_service_name, service_category")
        .eq("id", id)
        .maybeSingle();

      if (error) throw error;
      if (data) {
        const record = data as Record<string, unknown>;
        const first = pickImageFromRecord(record, ["images"]);
        if (first) image = first;
        const listingTitle = cleanPart(record.title) || cleanPart(record.custom_service_name);
        title = listingTitle ? `${listingTitle} | Swipess` : fallbackTitle;
        description = listingDescription(record, fallbackDesc);
      }
    } else if (kind === "profile") {
      canonical = `${appOrigin}/preview/profile/${id}`;
      const { data: prof } = await supabase
        .from("profiles")
        .select("full_name, bio, avatar_url, user_id")
        .eq("user_id", id)
        .maybeSingle();
      if (prof) {
        const record = prof as Record<string, unknown>;
        const name = cleanPart(record.full_name);
        title = name ? `${name} on Swipess` : fallbackTitle;
        description = truncate(record.bio || "Discover this profile on Swipess.", 240);
        if (record.avatar_url) image = String(record.avatar_url);
      }
      const { data: pi } = await supabase
        .from("profile_images")
        .select("image_url")
        .eq("user_id", id)
        .order("position", { ascending: true })
        .limit(1);
      if (pi && pi[0]?.image_url) image = pi[0].image_url;
    } else if (kind === "event") {
      // Correct Flutter route. The old /explore/eventos/:id path was not a
      // GoRouter destination and could dead-end after a shared event click.
      canonical = `${appOrigin}/explore/events/${id}`;
      const { data } = await supabase
        .from("events")
        .select("title, description, image_url, image_urls, video_url")
        .eq("id", id)
        .maybeSingle();
      if (data) {
        const record = data as Record<string, unknown>;
        const eventTitle = cleanPart(record.title);
        title = eventTitle ? `${eventTitle} | Swipess` : fallbackTitle;
        description = truncate(record.description || fallbackDesc, 240);
        image = pickImageFromRecord(record, ["image_url", "image_urls"]) || fallbackImage;
      }
    }
  } catch (error) {
    console.error("link-preview metadata lookup failed", error);
  }

  image = absolutize(image, appOrigin) || fallbackImage;

  const qs = url.searchParams.toString();
  if (qs) canonical += (canonical.includes("?") ? "&" : "?") + qs;

  if (!isCrawler(req)) {
    return new Response(null, {
      status: 302,
      headers: {
        ...corsHeaders,
        "Location": canonical,
        "Cache-Control": "no-store, max-age=0",
        "Vary": "User-Agent, Sec-Fetch-Mode, Sec-Fetch-Dest",
      },
    });
  }

  const html = renderHtml({ title, description, image, url: canonical });
  return new Response(html, {
    headers: {
      ...corsHeaders,
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "public, max-age=60, s-maxage=300, stale-while-revalidate=600",
      "Vary": "User-Agent, Sec-Fetch-Mode, Sec-Fetch-Dest",
      "X-Content-Type-Options": "nosniff",
    },
  });
});
