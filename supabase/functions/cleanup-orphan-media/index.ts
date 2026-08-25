import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.4";

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return new Response("Server configuration missing", { status: 500 });

  const supabase = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const supplied = req.headers.get("x-job-secret") ?? "";
  const { data: secretRow, error: secretError } = await supabase
    .from("internal_job_secrets")
    .select("secret")
    .eq("job_name", "cleanup-orphan-media")
    .maybeSingle();
  if (secretError || !secretRow || supplied !== secretRow.secret) {
    return new Response("Unauthorized", { status: 401 });
  }

  const { data, error } = await supabase.rpc("internal_orphan_media_candidates", {
    p_older_than_hours: 72,
    p_limit: 500,
  });
  if (error) return Response.json({ ok: false, error: error.message }, { status: 500 });

  const candidates = Array.isArray(data) ? data : [];
  const grouped = new Map<string, string[]>();
  for (const item of candidates) {
    const bucket = String(item.bucket ?? "");
    const path = String(item.path ?? "");
    if (!bucket || !path) continue;
    const list = grouped.get(bucket) ?? [];
    list.push(path);
    grouped.set(bucket, list);
  }

  let removed = 0;
  const failures: string[] = [];
  for (const [bucket, paths] of grouped.entries()) {
    for (let i = 0; i < paths.length; i += 100) {
      const batch = paths.slice(i, i + 100);
      const { error: removeError } = await supabase.storage.from(bucket).remove(batch);
      if (removeError) failures.push(`${bucket}: ${removeError.message}`);
      else removed += batch.length;
    }
  }

  await supabase.from("infrastructure_job_runs").insert({
    job_name: "cleanup-orphan-media",
    status: failures.length === 0 ? "success" : "partial",
    items_processed: candidates.length,
    items_removed: removed,
    details: { failures: failures.slice(0, 10), older_than_hours: 72 },
  });

  return Response.json({ ok: failures.length === 0, candidates: candidates.length, removed, failures });
});
