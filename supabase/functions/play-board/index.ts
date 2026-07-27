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

type SnapshotRow = {
  slate_key: string;
  mode: string;
  source: string;
  board: Ribbon[];
  updated_at: string;
  refresh_started_at: string | null;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};

const UUID_NS = "juicd-play-board";
/** How long a refresh lock is considered active (stampede coalesce). */
const REFRESH_LOCK_MS = 15_000;
/** Max wait for another invoker to finish refreshing. */
const STAMPEDE_WAIT_MS = 12_000;
const STAMPEDE_POLL_MS = 400;
const DEFAULT_TTL_SECONDS = 1800;

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

/** Prefer in-season boards; NBA is often empty in summer. */
const LIVE_SPORT_CANDIDATES: Array<{ sport: string; leagueTag: string; label: string }> = [
  { sport: "basketball_nba", leagueTag: "NBA", label: "NBA" },
  { sport: "basketball_nba_summer_league", leagueTag: "NBA", label: "NBA Summer League" },
  { sport: "baseball_mlb", leagueTag: "MLB", label: "MLB" },
  { sport: "americanfootball_nfl", leagueTag: "NFL", label: "NFL" },
];

async function fetchSportEvents(
  apiKey: string,
  sport: string,
): Promise<any[] | null> {
  const url = new URL(`https://api.the-odds-api.com/v4/sports/${sport}/odds/`);
  url.searchParams.set("apiKey", apiKey);
  url.searchParams.set("regions", "us");
  url.searchParams.set("markets", "h2h");
  url.searchParams.set("oddsFormat", "decimal");

  const resp = await fetch(url.toString());
  if (!resp.ok) return null;
  const events = await resp.json();
  if (!Array.isArray(events) || events.length === 0) return [];
  return events;
}

async function liveBoardFromOddsApi(apiKey: string, slateKey: string): Promise<Ribbon[]> {
  for (const candidate of LIVE_SPORT_CANDIDATES) {
    const events = await fetchSportEvents(apiKey, candidate.sport);
    if (!events || events.length === 0) continue;

    const e = events[0];
    const outcome = e?.bookmakers?.[0]?.markets?.find((m: any) => m.key === "h2h")
      ?.outcomes?.[0];
    if (!outcome?.name || !outcome?.price) continue;

    const liveRibbon: Ribbon = {
      id: "live_api",
      title: "Live API",
      subtitle: `Shared live line · ${candidate.label}`,
      props: [{
        id: makeId(slateKey, "live_api", candidate.sport, "0"),
        leagueTag: candidate.leagueTag,
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

  return simulatedBoard(slateKey);
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function ageSeconds(iso: string | null | undefined): number | null {
  if (!iso) return null;
  const t = Date.parse(iso);
  if (Number.isNaN(t)) return null;
  return Math.max(0, Math.floor((Date.now() - t) / 1000));
}

function isFresh(updatedAt: string | null | undefined, ttlSeconds: number): boolean {
  const age = ageSeconds(updatedAt);
  return age !== null && age < ttlSeconds;
}

function refreshInFlight(row: SnapshotRow | null): boolean {
  if (!row?.refresh_started_at) return false;
  const started = Date.parse(row.refresh_started_at);
  if (Number.isNaN(started)) return false;
  return Date.now() - started < REFRESH_LOCK_MS;
}

function boardResponse(
  mode: string,
  source: string,
  slateKey: string,
  ribbons: Ribbon[],
  opts: { cached: boolean; ageSeconds: number | null; ttlSeconds: number },
) {
  return new Response(JSON.stringify({
    mode,
    source,
    slateKey,
    ribbons,
    cached: opts.cached,
    ageSeconds: opts.ageSeconds,
    ttlSeconds: opts.ttlSeconds,
  }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
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

  const url = new URL(req.url);
  const force = url.searchParams.get("force") === "1" ||
    url.searchParams.get("force") === "true";

  const admin = createClient(supabaseUrl, serviceRole);
  const slateKey = isoDay();

  const { data: configRows } = await admin
    .from("juicd_runtime_config")
    .select("key, value")
    .in("key", ["odds_mode", "odds_board_ttl_seconds"]);

  const config = Object.fromEntries(
    (configRows ?? []).map((r: { key: string; value: string }) => [r.key, r.value]),
  );
  const mode = config.odds_mode === "live" ? "live" : "simulated";
  const ttlSeconds = Math.max(
    60,
    Number.parseInt(config.odds_board_ttl_seconds ?? "", 10) || DEFAULT_TTL_SECONDS,
  );

  async function loadSnapshot(): Promise<SnapshotRow | null> {
    const { data } = await admin
      .from("juicd_play_board_snapshots")
      .select("slate_key, mode, source, board, updated_at, refresh_started_at")
      .eq("slate_key", slateKey)
      .maybeSingle();
    if (!data) return null;
    return data as SnapshotRow;
  }

  // --- Read-through cache (all modes; live mode is where Odds quota matters) ---
  let snapshot = await loadSnapshot();
  if (
    !force &&
    snapshot &&
    snapshot.mode === mode &&
    Array.isArray(snapshot.board) &&
    snapshot.board.length > 0 &&
    isFresh(snapshot.updated_at, ttlSeconds)
  ) {
    return boardResponse(mode, snapshot.source, slateKey, snapshot.board, {
      cached: true,
      ageSeconds: ageSeconds(snapshot.updated_at),
      ttlSeconds,
    });
  }

  // Stampede: another invoker is refreshing — wait briefly, then serve snapshot
  // (fresh or slightly stale) instead of calling Odds again.
  if (!force && refreshInFlight(snapshot)) {
    const deadline = Date.now() + STAMPEDE_WAIT_MS;
    while (Date.now() < deadline) {
      await sleep(STAMPEDE_POLL_MS);
      snapshot = await loadSnapshot();
      if (
        snapshot &&
        snapshot.mode === mode &&
        Array.isArray(snapshot.board) &&
        snapshot.board.length > 0 &&
        !refreshInFlight(snapshot)
      ) {
        return boardResponse(mode, snapshot.source, slateKey, snapshot.board, {
          cached: true,
          ageSeconds: ageSeconds(snapshot.updated_at),
          ttlSeconds,
        });
      }
    }
    // Timed out waiting — return stale board if any, else continue to refresh.
    if (snapshot && Array.isArray(snapshot.board) && snapshot.board.length > 0) {
      return boardResponse(mode, snapshot.source, slateKey, snapshot.board, {
        cached: true,
        ageSeconds: ageSeconds(snapshot.updated_at),
        ttlSeconds,
      });
    }
  }

  // Claim refresh lock (best-effort; concurrent writers may still race rarely).
  const lockAt = new Date().toISOString();
  await admin.from("juicd_play_board_snapshots").upsert({
    slate_key: slateKey,
    mode,
    source: snapshot?.source ?? "refreshing",
    board: snapshot?.board ?? [],
    updated_at: snapshot?.updated_at ?? lockAt,
    refresh_started_at: lockAt,
  });

  let ribbons: Ribbon[] = [];
  let source = "simulated";
  try {
    if (mode === "live" && oddsApiKey) {
      ribbons = await liveBoardFromOddsApi(oddsApiKey, slateKey);
      source = ribbons[0]?.id === "live_api" ? "odds_api" : "simulated_fallback";
    } else {
      ribbons = simulatedBoard(slateKey);
    }
  } catch (_e) {
    // Prefer last good board over failing the whole request.
    if (snapshot && Array.isArray(snapshot.board) && snapshot.board.length > 0) {
      await admin.from("juicd_play_board_snapshots").upsert({
        slate_key: slateKey,
        mode: snapshot.mode,
        source: snapshot.source,
        board: snapshot.board,
        updated_at: snapshot.updated_at,
        refresh_started_at: null,
      });
      return boardResponse(mode, snapshot.source, slateKey, snapshot.board, {
        cached: true,
        ageSeconds: ageSeconds(snapshot.updated_at),
        ttlSeconds,
      });
    }
    ribbons = simulatedBoard(slateKey);
    source = "simulated_error_fallback";
  }

  const updatedAt = new Date().toISOString();
  await admin.from("juicd_play_board_snapshots").upsert({
    slate_key: slateKey,
    mode,
    source,
    board: ribbons,
    updated_at: updatedAt,
    refresh_started_at: null,
  });

  return boardResponse(mode, source, slateKey, ribbons, {
    cached: false,
    ageSeconds: 0,
    ttlSeconds,
  });
});
