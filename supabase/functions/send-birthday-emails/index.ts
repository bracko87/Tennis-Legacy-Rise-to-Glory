import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const DEFAULT_FROM = "Tennis Legacy <no-reply@propelotonmanager.com>";

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    return new Response(JSON.stringify({ error: "Supabase service configuration is unavailable" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch {
    // Unauthorized below.
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: authorized, error: authError } = await admin.rpc(
    "validate_birthday_email_cron_token_v1",
    { p_token: typeof body.cron_token === "string" ? body.cron_token : "" },
  );

  if (authError || authorized !== true) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const resendApiKey = Deno.env.get("RESEND_API_KEY");
  const fromAddress = DEFAULT_FROM;

  if (!resendApiKey) {
    return new Response(JSON.stringify({
      status: "email_provider_not_configured",
      detail: "RESEND_API_KEY is not configured.",
    }), {
      status: 503,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: claimed, error: claimError } = await admin.rpc("claim_birthday_email_outbox_v1", {
    p_limit: 20,
  });

  if (claimError) {
    return new Response(JSON.stringify({ error: claimError.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const jobs = Array.isArray(claimed) ? claimed : [];
  let sent = 0;
  let failed = 0;

  for (const job of jobs) {
    try {
      const providerResponse = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${resendApiKey}`,
          "Content-Type": "application/json",
          "Idempotency-Key": `birthday-email-${job.id}`,
        },
        body: JSON.stringify({
          from: fromAddress,
          to: [job.recipient_email],
          subject: job.subject,
          text: job.text_body,
          html: job.html_body,
        }),
      });

      const providerBody = await providerResponse.json().catch(() => ({}));

      if (!providerResponse.ok) {
        throw new Error(providerBody?.message || `Email provider returned HTTP ${providerResponse.status}`);
      }

      const sentAt = new Date().toISOString();
      const { error: outboxError } = await admin
        .from("birthday_email_outbox")
        .update({
          status: "sent",
          sent_at: sentAt,
          provider_message_id: providerBody?.id ?? null,
          last_error: null,
          updated_at: sentAt,
        })
        .eq("id", job.id);

      if (outboxError) throw outboxError;

      await admin
        .from("birthday_rewards")
        .update({ email_sent_at: sentAt, updated_at: sentAt })
        .eq("id", job.birthday_reward_id);

      sent += 1;
    } catch (error) {
      failed += 1;
      const attempts = Number(job.attempts ?? 1);
      const delayMinutes = Math.min(15 * Math.max(attempts, 1), 120);
      const nextAttemptAt = new Date(Date.now() + delayMinutes * 60_000).toISOString();

      await admin
        .from("birthday_email_outbox")
        .update({
          status: "failed",
          next_attempt_at: nextAttemptAt,
          last_error: error instanceof Error ? error.message : String(error),
          updated_at: new Date().toISOString(),
        })
        .eq("id", job.id);
    }
  }

  return new Response(JSON.stringify({
    status: "processed",
    claimed: jobs.length,
    sent,
    failed,
  }), {
    headers: { "Content-Type": "application/json" },
  });
});
