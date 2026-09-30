import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

function hex(buffer: ArrayBuffer) {
  return Array.from(new Uint8Array(buffer)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function hmacSha256(secret: string, payload: string) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return hex(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload)));
}

function timingSafeEqual(a: string, b: string) {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i += 1) result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return result === 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRole) return new Response("Server configuration missing", { status: 500 });

  const supabase = createClient(supabaseUrl, serviceRole, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: cfg, error: cfgError } = await supabase
    .from("stripe_webhook_private_config")
    .select("signing_secret")
    .eq("id", true)
    .single();

  if (cfgError || !cfg?.signing_secret) return new Response("Webhook secret unavailable", { status: 503 });

  const raw = await req.text();
  const signatureHeader = req.headers.get("stripe-signature") ?? "";
  const parts = signatureHeader.split(",").map((x) => x.trim());
  const timestampPart = parts.find((x) => x.startsWith("t="));
  const signatures = parts.filter((x) => x.startsWith("v1=")).map((x) => x.slice(3));

  if (!timestampPart || signatures.length === 0) return new Response("Invalid signature header", { status: 400 });

  const timestamp = Number(timestampPart.slice(2));
  if (!Number.isFinite(timestamp) || Math.abs(Math.floor(Date.now() / 1000) - timestamp) > 300) {
    return new Response("Signature timestamp outside tolerance", { status: 400 });
  }

  const expected = await hmacSha256(cfg.signing_secret, `${timestamp}.${raw}`);
  if (!signatures.some((sig) => timingSafeEqual(sig, expected))) {
    return new Response("Invalid signature", { status: 400 });
  }

  let event: unknown;
  try {
    event = JSON.parse(raw);
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const { data, error } = await supabase.rpc("process_tennis_stripe_webhook_v1", { p_event: event });
  if (error) {
    console.error("Stripe fulfillment error", error);
    return new Response("Fulfillment error", { status: 500 });
  }

  return Response.json({ received: true, result: data });
});
