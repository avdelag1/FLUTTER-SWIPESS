import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const ORIGIN = (Deno.env.get("APP_ORIGIN") ?? "https://www.swipess.com").replace(/\/$/, "");

function esc(value: string) {
  return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/\"/g, "&quot;").replace(/'/g, "&apos;");
}
function item(loc: string, lastmod?: string | null, priority = "0.7") {
  return `<url><loc>${esc(loc)}</loc>${lastmod ? `<lastmod>${esc(lastmod)}</lastmod>` : ""}<changefreq>daily</changefreq><priority>${priority}</priority></url>`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: { "Access-Control-Allow-Origin": "*" } });
  if (!SUPABASE_URL || !KEY) return new Response("Sitemap unavailable", { status: 503 });
  const db = createClient(SUPABASE_URL, KEY);
  const urls: string[] = [
    item(`${ORIGIN}/`, null, "1.0"),
    item(`${ORIGIN}/explore/events`, null, "0.8"),
    item(`${ORIGIN}/explore/services`, null, "0.8"),
  ];

  try {
    const { data: listings } = await db
      .from("listings")
      .select("id,updated_at,created_at")
      .eq("is_active", true)
      .in("status", ["active", "available"])
      .order("updated_at", { ascending: false })
      .limit(30000);
    for (const row of listings || []) {
      urls.push(item(`${ORIGIN}/listing/${row.id}`, row.updated_at || row.created_at, "0.9"));
    }
  } catch (e) { console.error("sitemap listings", e); }

  try {
    const { data: events } = await db
      .from("events")
      .select("id,updated_at,created_at")
      .order("updated_at", { ascending: false })
      .limit(10000);
    for (const row of events || []) {
      urls.push(item(`${ORIGIN}/explore/events/${row.id}`, row.updated_at || row.created_at, "0.8"));
    }
  } catch (e) { console.error("sitemap events", e); }

  try {
    const { data: profiles } = await db
      .from("profiles")
      .select("user_id,updated_at,created_at")
      .not("user_id", "is", null)
      .order("updated_at", { ascending: false })
      .limit(9000);
    for (const row of profiles || []) {
      urls.push(item(`${ORIGIN}/profile/${row.user_id}`, row.updated_at || row.created_at, "0.6"));
    }
  } catch (e) { console.error("sitemap profiles", e); }

  const xml = `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${urls.join("")}</urlset>`;
  return new Response(xml, {
    headers: {
      "Content-Type": "application/xml; charset=utf-8",
      "Cache-Control": "public, max-age=300, s-maxage=1800, stale-while-revalidate=3600",
      "Access-Control-Allow-Origin": "*",
    },
  });
});
