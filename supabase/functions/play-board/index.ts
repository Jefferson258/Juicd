import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Prop = {
  id: string;
  leagueTag: string;
  athleteOrTeam: string;
  matchup: string;
  propDescription: string;
  lineText: string;
  pickLabel: string;
  oddsDecimal: number;
};

type Ribbon = {
  id: string;
  title: string;
  subtitle?: string;
  props: Prop[];
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};

const UUID_NS = "juicd-play-board";

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

function clamp(v: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, v));
}

function makeId(...parts: string[]): string {
  const base = parts.join("|");
  const a = fnv1a(`${UUID_NS}|${base}|a`).toString(16).padStart(8, "0");
  const b = fnv1a(`${UUID_NS}|${base}|b`).toString(16).padStart(8, "0");
  const c = fnv1a(`${UUID_NS}|${base}|c`).toString(16).padStart(8, "0");
  const d = fnv1a(`${UUID_NS}|${base}|d`).toString(16).padStart(8, "0");
  return `${a}-${b.slice(0, 4)}-4${b.slice(5, 8)}-a${c.slice(1, 4)}-${c.slice(4, 8)}${d}`;
}

function simulatedBoard(slateKey: string): Ribbon[] {
  const seeds: Array<[string, string, string, string]> = [
    ["popular_nba", "Popular NBA", "NBA prop board", "NBA"],
    ["popular_nfl", "Popular NFL", "NFL prop board", "NFL"],
    ["popular_mlb", "Popular MLB", "MLB prop board", "MLB"],
  ];

  return seeds.map(([ribbonId, title, subtitle, league]) => {
    const props: Prop[] = Array.from({ length: 6 }).map((_, i) => {
      const pSeed = `${slateKey}|${ribbonId}|${i}`;
      const odds = clamp(1.5 + random01(`${pSeed}|odds`) * 1.15, 1.4, 3.2);
      const line = (18 + Math.floor(random01(`${pSeed}|line`) * 14)).toFixed(1);
      const player = `${league} Player ${i + 1}`;
      return {
        id: makeId(slateKey, ribbonId, String(i)),
        leagueTag: league,
        athleteOrTeam: player,
        matchup: `${league} Matchup ${1 + (i % 3)}`,
        propDescription: "Points",
        lineText: `${line}`,
        pickLabel: "Over",
        oddsDecimal: Number(odds.toFixed(2)),
      };
    });
    return { id: ribbonId, title, subtitle, props };
  });
}

async function liveBoardFromOddsApi(apiKey: string, slateKey: string): Promise<Ribbon[]> {
  const url = new URL("https://api.the-odds-api.com/v4/sports/basketball_nba/odds/");
  url.searchParams.set("apiKey", apiKey);
  url.searchParams.set("regions", "us");
  url.searchParams.set("markets", "h2h");
  url.searchParams.set("oddsFormat", "decimal");

  const resp = await fetch(url.toString());
  if (!resp.ok) return simulatedBoard(slateKey);
  const events = await resp.json();
  if (!Array.isArray(events) || events.length === 0) return simulatedBoard(slateKey);
  const e = events[0];
  const outcome = e?.bookmakers?.[0]?.markets?.find((m: any) => m.key === "h2h")?.outcomes?.[0];
  if (!outcome?.name || !outcome?.price) return simulatedBoard(slateKey);

  const liveRibbon: Ribbon = {
    id: "live_api",
    title: "Live API",
    subtitle: "Shared live line from Odds API",
    props: [{
      id: makeId(slateKey, "live_api", "0"),
      leagueTag: "NBA",
      athleteOrTeam: outcome.name,
      matchup: `${e?.away_team ?? "Away"} @ ${e?.home_team ?? "Home"}`,
      propDescription: "Moneyline",
      lineText: "H2H",
      pickLabel: outcome.name,
      oddsDecimal: Number(Number(outcome.price).toFixed(2)),
    }],
  };
  return [liveRibbon, ...simulatedBoard(slateKey)];
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const oddsApiKey = Deno.env.get("ODDS_API_KEY") ?? "";

  if (!supabaseUrl || !serviceRole) {
    return new Response(JSON.stringify({ error: "Missing Supabase env vars" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const admin = createClient(supabaseUrl, serviceRole);
  const slateKey = isoDay();

  const { data: modeRow } = await admin
    .from("juicd_runtime_config")
    .select("value")
    .eq("key", "odds_mode")
    .maybeSingle();

  const mode = modeRow?.value === "live" ? "live" : "simulated";

  let ribbons: Ribbon[] = [];
  let source = "simulated";
  if (mode === "live" && oddsApiKey) {
    ribbons = await liveBoardFromOddsApi(oddsApiKey, slateKey);
    source = ribbons[0]?.id === "live_api" ? "odds_api" : "simulated_fallback";
  } else {
    ribbons = simulatedBoard(slateKey);
  }

  await admin.from("juicd_play_board_snapshots").upsert({
    slate_key: slateKey,
    mode,
    source,
    board: ribbons,
    updated_at: new Date().toISOString(),
  });

  return new Response(JSON.stringify({
    mode,
    source,
    slateKey,
    ribbons,
  }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});

