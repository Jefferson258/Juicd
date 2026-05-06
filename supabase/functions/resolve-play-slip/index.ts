import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type ResolveLeg = {
  legId: string;
  choiceLabel: string;
  oddsDecimalAtSubmit: number;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};

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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "POST required" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceRole) {
    return new Response(JSON.stringify({ error: "Missing Supabase env vars" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  const admin = createClient(supabaseUrl, serviceRole);

  const body = await req.json().catch(() => null);
  const legs = (body?.legs ?? []) as ResolveLeg[];
  if (!Array.isArray(legs) || legs.length === 0) {
    return new Response(JSON.stringify({ error: "legs required" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const slateKey = isoDay();
  const normalizedSlip = legs
    .map((l) => `${l.choiceLabel}|${Number(l.oddsDecimalAtSubmit).toFixed(4)}`)
    .sort()
    .join(";");
  const slipKey = `${slateKey}|${normalizedSlip}`;

  const { data: existing } = await admin
    .from("juicd_play_slip_outcomes")
    .select("outcomes")
    .eq("slip_key", slipKey)
    .maybeSingle();

  if (existing?.outcomes) {
    return new Response(JSON.stringify({
      slateKey,
      outcomes: existing.outcomes,
      cached: true,
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const outcomes = legs.map((leg) => {
    const p = impliedProbability(Number(leg.oddsDecimalAtSubmit));
    const roll = random01(`${slateKey}|${leg.choiceLabel}|${Number(leg.oddsDecimalAtSubmit).toFixed(4)}`);
    return { legId: leg.legId, didWin: roll < p };
  });

  await admin.from("juicd_play_slip_outcomes").upsert({
    slip_key: slipKey,
    slate_key: slateKey,
    outcomes,
  });

  return new Response(JSON.stringify({ slateKey, outcomes, cached: false }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});

