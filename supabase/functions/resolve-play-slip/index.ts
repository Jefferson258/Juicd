import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { isUuid, validateLegs, type ResolveLeg } from "./validation.ts";
import { parlayDidWin } from "./settlement.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function bearerToken(req: Request): string | null {
  const header = req.headers.get("Authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

function fnv1a(str: string): number {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function random01(seed: string): number {
  return fnv1a(seed) / 0xffffffff;
}

function isoDay(d = new Date()): string {
  return d.toISOString().slice(0, 10);
}

function impliedProbability(oddsDecimal: number): number {
  const p = 1 / Math.max(1.01, oddsDecimal);
  return Math.max(0.05, Math.min(0.95, p));
}

function outcomeForLeg(slateKey: string, leg: ResolveLeg): { legId: string; didWin: boolean } {
  const p = impliedProbability(leg.oddsDecimalAtSubmit);
  const roll = random01(`${slateKey}|${leg.choiceLabel}|${leg.oddsDecimalAtSubmit.toFixed(4)}`);
  return { legId: leg.legId, didWin: roll < p };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const token = bearerToken(req);
  if (!token) return json({ error: "authentication_required" }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceRole) {
    return json({ error: "server_configuration_missing" }, 500);
  }
  const admin = createClient(supabaseUrl, serviceRole);

  const { data: authData, error: authError } = await admin.auth.getUser(token);
  if (authError || !authData.user) return json({ error: "invalid_session" }, 401);

  const body = await req.json().catch(() => null) as Record<string, unknown> | null;
  if (!body || typeof body.userId !== "string" || !isUuid(body.userId)) {
    return json({ error: "user_id_required" }, 400);
  }
  if (body.userId.toLowerCase() !== authData.user.id.toLowerCase()) {
    return json({ error: "identity_mismatch" }, 403);
  }

  const legs = validateLegs(body.legs);
  if (!legs) return json({ error: "invalid_legs" }, 400);

  const slateKey = isoDay();
  const normalizedSlip = legs
    .map((l) => `${l.choiceLabel}|${l.oddsDecimalAtSubmit.toFixed(4)}`)
    .sort()
    .join(";");
  const slipKey = `${slateKey}|${normalizedSlip}`;

  const { data: existing } = await admin
    .from("juicd_play_slip_outcomes")
    .select("outcomes")
    .eq("slip_key", slipKey)
    .maybeSingle();

  if (existing?.outcomes) {
    // Cached rows predate the request's generated leg IDs. Recompute the same
    // deterministic simulated result while returning the current IDs so a
    // repeated equivalent slip cannot resolve every leg as an unknown loss.
    const outcomes = legs.map((leg) => outcomeForLeg(slateKey, leg));
    return await maybeAuthoritativeSettle(
      admin,
      authData.user.id,
      body,
      slateKey,
      outcomes,
      true,
    );
  }

  const outcomes = legs.map((leg) => outcomeForLeg(slateKey, leg));

  const { error: upsertError } = await admin.from("juicd_play_slip_outcomes").upsert({
    slip_key: slipKey,
    slate_key: slateKey,
    outcomes,
  });

  if (upsertError) return json({ error: "outcome_persistence_failed" }, 503);
  return await maybeAuthoritativeSettle(
    admin,
    authData.user.id,
    body,
    slateKey,
    outcomes,
    false,
  );
});

async function maybeAuthoritativeSettle(
  admin: ReturnType<typeof createClient>,
  userId: string,
  body: Record<string, unknown>,
  slateKey: string,
  outcomes: { legId: string; didWin: boolean }[],
  cached: boolean,
): Promise<Response> {
  if (Deno.env.get("JUICD_AUTHORITATIVE_SETTLEMENT") !== "1") {
    return json({ slateKey, outcomes, cached });
  }

  const slipId = body.slipId;
  if (typeof slipId !== "string" || !isUuid(slipId)) {
    return json({ error: "slip_id_required" }, 400);
  }

  const { data, error } = await admin.rpc("juicd_staging_settle_slip", {
    p_user_id: userId,
    p_slip_id: slipId,
    p_outcomes: outcomes,
    p_slate_key: slateKey,
  });

  if (error) return json({ error: "authoritative_settlement_failed", detail: error.message }, 503);
  return json({
    slateKey,
    outcomes,
    cached,
    didWin: parlayDidWin(outcomes),
    settlement: data,
  });
}

