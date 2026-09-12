import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  actualForProp,
  espnPath,
  fetchScoreboard,
  fetchSummary,
  matchEvent,
  parseBoxPlayers,
  parseScoreboardEvents,
} from "../_shared/espn.ts";

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

type RoundSpec = {
  round: number;
  propLabel: string;
  statSummary: string;
  line: number;
  eventId: string;
  matchup: string;
  player: string;
  commenceTime: string;
  sportKey: string;
};

type Payload = {
  kind: string;
  periodKey: string;
  title: string;
  gameLabel: string;
  commenceTime: string;
  freezeAt: string;
  roundSpecs: RoundSpec[];
};

const ADJ = [
  "Amazing", "Sneaky", "Clutch", "Icy", "Bold", "Lucky", "Wild", "Sunny",
  "Rapid", "Quiet", "Dusty", "Frosty", "Prime", "Nifty", "Gritty",
];
const NOUNS = [
  "Tackler", "Shooter", "Slugger", "Blitzer", "Closer", "Dunker", "Goalie",
  "Jammer", "Slider", "Hammer", "Rocket", "Comet", "Ranger", "Ace", "Captain",
];

function fnv(s: string): number {
  let h = 2166136261;
  for (const u of new TextEncoder().encode(s)) {
    h ^= u;
    h = Math.imul(h, 16777619);
  }
  return Math.abs(h);
}

function botName(periodKey: string, slot: number): string {
  const a = ADJ[fnv(periodKey + "|a|" + slot) % ADJ.length];
  const n = NOUNS[fnv(periodKey + "|n|" + slot) % NOUNS.length];
  const num = 10 + (fnv(periodKey + "|#|" + slot) % 90);
  return `${a}${n}${num}`;
}

function botPicks(periodKey: string, rounds: RoundSpec[], slot: number): number[] {
  return rounds.map((round) => {
    const jitter = ((fnv(periodKey + "|" + slot + "|" + round.round) % 17) - 8) * 0.5;
    return Math.round(Math.max(0, round.line + jitter) * 10) / 10;
  });
}

function dbKind(kind: string): string {
  return kind === "weekly" ? "weekly" : "daily";
}

async function actualsFor(rounds: RoundSpec[]): Promise<(number | null)[]> {
  const out: (number | null)[] = [];
  for (const round of rounds) {
    const path = espnPath(round.sportKey ?? "");
    if (!path) {
      out.push(null);
      continue;
    }
    const body = await fetchScoreboard(path, round.commenceTime);
    if (!body) {
      out.push(null);
      continue;
    }
    const events = parseScoreboardEvents(body);
    const parts = (round.matchup || "").split("@").map((s) => s.trim());
    const away = parts[0] ?? "";
    const home = parts[1] ?? "";
    const event = matchEvent(events, home, away) ??
      events.find((e) => e.id && e.id === String(round.eventId ?? ""));
    if (!event?.isFinal) {
      out.push(null);
      continue;
    }
    const summary = await fetchSummary(path, event.id || round.eventId);
    const players = summary ? parseBoxPlayers(summary) : [];
    out.push(actualForProp({
      description: `${round.propLabel} ${round.statSummary}`,
      player: round.player,
      players,
      homeScore: event.homeScore,
      awayScore: event.awayScore,
    }));
  }
  return out;
}

function closestEliminations(
  entries: { id: string; slot: number; picks: number[] }[],
  actuals: (number | null)[],
): Map<string, number> {
  const elim = new Map<string, number>();
  let alive = [...entries].sort((a, b) => a.slot - b.slot);
  for (let r = 0; r < actuals.length; r++) {
    const actual = actuals[r];
    if (actual == null) break;
    const next: typeof alive = [];
    for (let i = 0; i < alive.length; i += 2) {
      const a = alive[i];
      const b = alive[i + 1];
      if (!b) {
        next.push(a);
        continue;
      }
      const da = Math.abs((a.picks[r] ?? 0) - actual);
      const db = Math.abs((b.picks[r] ?? 0) - actual);
      if (da < db || (da === db && a.slot < b.slot)) {
        next.push(a);
        elim.set(b.id, r + 1);
      } else {
        next.push(b);
        elim.set(a.id, r + 1);
      }
    }
    alive = next;
  }
  return elim;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceRole) return json({ error: "server_configuration_missing" }, 500);
  const admin = createClient(supabaseUrl, serviceRole);
  const header = req.headers.get("Authorization") ?? "";
  const token = header.match(/^Bearer\s+(.+)$/i)?.[1]?.trim();
  if (!token) return json({ error: "authentication_required" }, 401);
  const { data: authData, error: authError } = await admin.auth.getUser(token);
  if (authError || !authData.user) return json({ error: "invalid_session" }, 401);
  const userId = authData.user.id;

  if (req.method === "POST") {
    const body = await req.json().catch(() => null) as {
      payload?: Payload;
      picks?: number[];
    } | null;
    const payload = body?.payload;
    const picks = Array.isArray(body?.picks) ? body!.picks.map(Number) : [];
    if (!payload?.kind || !payload.periodKey || picks.length === 0) {
      return json({ error: "invalid_body" }, 400);
    }
    if (new Date() >= new Date(payload.freezeAt)) {
      return json({ error: "frozen" }, 409);
    }
    const kind = dbKind(payload.kind);
    const start = new Date(payload.commenceTime);
    const end = new Date(start.getTime() + 6 * 3600 * 1000);
    const { data: existing } = await admin
      .from("juicd_tournaments")
      .select("id")
      .eq("kind", kind)
      .eq("period_key", payload.periodKey)
      .maybeSingle();
    let tournamentId = existing?.id as string | undefined;
    if (!tournamentId) {
      const { data: created, error } = await admin.from("juicd_tournaments").insert({
        kind,
        status: "active",
        start_at: payload.commenceTime,
        end_at: end.toISOString(),
        stage_count: payload.roundSpecs?.length ?? 4,
        period_key: payload.periodKey,
        payload,
      }).select("id").single();
      if (error || !created) return json({ error: error?.message ?? "create_failed" }, 500);
      tournamentId = created.id;
    }
    const { data: profile } = await admin
      .from("juicd_profiles")
      .select("display_name")
      .eq("id", userId)
      .maybeSingle();
    const { data: existingEntry } = await admin
      .from("juicd_tournament_entries")
      .select("user_slot")
      .eq("tournament_id", tournamentId)
      .eq("user_id", userId)
      .maybeSingle();
    let slot = Number(existingEntry?.user_slot ?? 0);
    if (!existingEntry) {
      const { data: taken } = await admin
        .from("juicd_tournament_entries")
        .select("user_slot")
        .eq("tournament_id", tournamentId);
      const used = new Set((taken ?? []).map((row: { user_slot?: number }) => Number(row.user_slot)));
      slot = 0;
      while (used.has(slot) && slot < 15) slot += 1;
    }
    const { error: upsertErr } = await admin.from("juicd_tournament_entries").upsert({
      tournament_id: tournamentId,
      user_id: userId,
      day_iso: payload.periodKey,
      game_label: payload.gameLabel,
      tournament_name: payload.title,
      bracket_size: 16,
      user_slot: slot,
      picks,
      display_name: profile?.display_name ?? "Player",
      round_specs: payload.roundSpecs ?? [],
      updated_at: new Date().toISOString(),
    }, { onConflict: "tournament_id,user_id" });
    if (upsertErr) return json({ error: upsertErr.message }, 500);
    return json({ ok: true, tournamentId });
  }

  if (req.method !== "GET") return json({ error: "method_not_allowed" }, 405);
  const url = new URL(req.url);
  const kindIn = url.searchParams.get("kind") ?? "daily";
  const periodKey = url.searchParams.get("periodKey") ?? "";
  const kind = dbKind(kindIn);
  if (!periodKey) return json({ error: "periodKey_required" }, 400);

  const { data: tourney } = await admin
    .from("juicd_tournaments")
    .select("id, payload, start_at")
    .eq("kind", kind)
    .eq("period_key", periodKey)
    .maybeSingle();
  const payload = (tourney?.payload ?? null) as Payload | null;
  const rounds = payload?.roundSpecs ?? [];
  const freezeAt = payload?.freezeAt ? new Date(payload.freezeAt) : null;
  const frozen = freezeAt ? new Date() >= freezeAt : false;

  const { data: rows } = tourney?.id
    ? await admin
      .from("juicd_tournament_entries")
      .select("user_id, picks, display_name, user_slot")
      .eq("tournament_id", tourney.id)
    : { data: [] as any[] };

  const humans = (rows ?? []).map((r: any, i: number) => ({
    id: r.user_id,
    displayName: r.display_name || "Player",
    isBot: false,
    slot: Number(r.user_slot ?? i),
    picks: Array.isArray(r.picks) ? r.picks.map(Number) : [],
  }));

  const entries = [...humans];
  if (frozen) {
    let slot = humans.length;
    while (entries.length < 16) {
      entries.push({
        id: `bot-${periodKey}-${slot}`,
        displayName: botName(periodKey, slot),
        isBot: true,
        slot,
        picks: botPicks(periodKey, rounds, slot),
      });
      slot += 1;
    }
  } else {
    while (entries.length < 16) {
      const slot = entries.length;
      entries.push({
        id: `open-${slot}`,
        displayName: "Open",
        isBot: false,
        slot,
        picks: [],
      });
    }
  }

  const actuals = rounds.length ? await actualsFor(rounds) : [];
  const elim = closestEliminations(entries.slice(0, 16), actuals);
  return json({
    payload,
    frozen,
    actuals,
    entries: entries.slice(0, 16).map((e) => ({
      ...e,
      eliminatedRound: elim.get(e.id) ?? null,
    })),
    you: userId,
  });
});
