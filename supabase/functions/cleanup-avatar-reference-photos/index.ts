import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const BUCKET = "avatar-replacement-submissions";
const BATCH_SIZE = 100;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "cache-control": "no-store",
    },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) return json({ error: "Cleanup service unavailable" }, 503);

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const nowIso = new Date().toISOString();
  const { data: due, error: dueError } = await admin
    .from("avatar_replacement_requests")
    .select("id,reference_storage_path")
    .is("reference_deleted_at", null)
    .not("reference_storage_path", "is", null)
    .lte("reference_delete_after", nowIso)
    .order("reference_delete_after", { ascending: true })
    .limit(BATCH_SIZE);

  if (dueError) return json({ error: dueError.message }, 500);
  if (!due?.length) return json({ ok: true, deleted: 0 });

  let deleted = 0;
  const failed: string[] = [];

  for (const row of due) {
    const path = String(row.reference_storage_path ?? "").trim();
    if (!path) continue;

    const { error: removeError } = await admin.storage.from(BUCKET).remove([path]);
    if (removeError) {
      failed.push(String(row.id));
      continue;
    }

    const now = new Date().toISOString();
    const { error: updateError } = await admin
      .from("avatar_replacement_requests")
      .update({ reference_deleted_at: now, updated_at: now })
      .eq("id", row.id)
      .is("reference_deleted_at", null);

    if (updateError) {
      failed.push(String(row.id));
      continue;
    }

    deleted += 1;
  }

  return json({ ok: true, deleted, failed: failed.length });
});
