import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  MAX_ODDS_CREDITS_PER_DAY,
  calendarWeekKey,
  eventNotStarted,
  eventOnSlate,
  freezeAtIso,
  inNflWeek,
  isSundayEarlyWeeklyWindow,
  nextCalendarWeekKey,
  nextSlateKey,
  previousSlateKey,
  slateKey as juicdSlateKey,
} from "../_shared/slate.ts";

type Prop = {
  id: string;
  leagueTag: string;
  athleteOrTeam: string;
  matchup: string;
  propDescription: string;
  lineText: string;
  pickLabel: string;
  oddsDecimal: number;
  commenceTime?: string;
  eventId?: string;
  sportKey?: string;
  homeTeam?: string;
  awayTeam?: string;
  pointLine?: number;
  overOdds?: number;
  underOdds?: number;
};

type Ribbon = {
  id: string;
  title: string;
  subtitle?: string;
  props: Prop[];
};

type RoundSpec = {
  round: number;
  propLabel: string;
  statSummary: string;
  line?: number;
  eventId: string;
  matchup: string;
  player: string;
  commenceTime: string;
  sportKey: string;
};

type TourneyDiag = {
  kind: "daily" | "weekly";
  ok: boolean;
  fallback: string;
  detail: string;
};

type TourneyPayload = {
  kind: "daily" | "weekly";
  periodKey: string;
  title: string;
  gameLabel: string;
  commenceTime: string;
  freezeAt: string;
  roundSpecs: RoundSpec[];
};

type SnapshotBoard = {
  version: 2;
  ribbons: Ribbon[];
  tomorrowRibbons?: Ribbon[];
  dailyTourney: TourneyPayload | null;
  weeklyTourney: TourneyPayload | null;
  nextDailyTourney?: TourneyPayload | null;
  nextWeeklyTourney?: TourneyPayload | null;
  creditsSpent: number;
  tourneyDiagnostics?: { daily: TourneyDiag; weekly: TourneyDiag };
};

type SnapshotRow = {
  slate_key: string;
  mode: string;
  source: string;
  board: unknown;
  updated_at: string;
  refresh_started_at: string | null;
};

type BoardSport = {
  sport: string;
  leagueTag: string;
  label: string;
  propMarket: string;
  propLabel: string;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};

const UUID_NS = "juicd-play-board";
const REFRESH_LOCK_MS = 15_000;
const STAMPEDE_WAIT_MS = 12_000;
const STAMPEDE_POLL_MS = 400;
const ODDS_MIN_REMAINING = 40;
const PROP_GAMES_PER_SPORT = 3;
const PROP_MAX_PER_EVENT = 8;

const BOARD_SPORTS: BoardSport[] = [
  { sport: "americanfootball_nfl", leagueTag: "NFL", label: "NFL", propMarket: "player_pass_yds", propLabel: "Pass yards" },
  { sport: "basketball_nba", leagueTag: "NBA", label: "NBA", propMarket: "player_points", propLabel: "Points" },
  { sport: "icehockey_nhl", leagueTag: "NHL", label: "NHL", propMarket: "player_shots_on_goal", propLabel: "Shots" },
  { sport: "baseball_mlb", leagueTag: "MLB", label: "MLB", propMarket: "batter_hits", propLabel: "Hits" },
];

function fnv1a(str: string): number {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function makeId(...parts: string[]): string {
  const base = parts.join("|");
  const a = fnv1a(`${UUID_NS}|${base}|a`).toString(16).padStart(8, "0");
  const b = fnv1a(`${UUID_NS}|${base}|b`).toString(16).padStart(8, "0");
  const c = fnv1a(`${UUID_NS}|${base}|c`).toString(16).padStart(8, "0");
  const d = fnv1a(`${UUID_NS}|${base}|d`).toString(16).padStart(8, "0");
  return `${a}-${b.slice(0, 4)}-4${b.slice(5, 8)}-a${c.slice(1, 4)}-${c.slice(4, 8)}${d}`;
}

function parseRemaining(resp: Response): number | null {
  const raw = resp.headers.get("x-requests-remaining");
  const n = raw != null ? Number.parseInt(raw, 10) : NaN;
  return Number.isFinite(n) ? n : null;
}

function parseLastCost(resp: Response): number {
  const raw = resp.headers.get("x-requests-last");
  const n = raw != null ? Number.parseInt(raw, 10) : NaN;
  return Number.isFinite(n) ? n : 0;
}

function commenceOf(event: any): string {
  return String(event?.commence_time ?? "");
}

function filterUpcomingOnSlate(events: any[], targetSlate: string, now: Date): any[] {
  return [...events]
    .filter((e) => eventOnSlate(commenceOf(e), targetSlate) && eventNotStarted(commenceOf(e), now))
    .sort((a, b) => (Date.parse(commenceOf(a)) || 0) - (Date.parse(commenceOf(b)) || 0));
}

function tourneyHasBannedPlaceholder(payload: TourneyPayload | null | undefined): boolean {
  if (!payload?.roundSpecs?.length) return false;
  const blob = (payload.gameLabel + payload.roundSpecs.map((r) => r.matchup).join("")).toUpperCase();
  if (blob.includes("HOU @ SEA")) return true;
  return payload.roundSpecs.some((spec) =>
    `${spec.propLabel} ${spec.statSummary} ${spec.player}`.toLowerCase().includes("combined score") &&
    spec.line != null
  );
}

function reusableTourney(
  existing: TourneyPayload | null | undefined,
  periodKey: string,
): TourneyPayload | null {
  if (!existing || existing.periodKey !== periodKey) return null;
  if (!existing.roundSpecs || existing.roundSpecs.length < 2) return null;
  if (tourneyHasBannedPlaceholder(existing)) return null;
  return existing;
}

async function oddsSportsCatalog(apiKey: string): Promise<{
  sports: any[];
  remaining: number | null;
}> {
  const resp = await fetch(
    `https://api.the-odds-api.com/v4/sports/?apiKey=${encodeURIComponent(apiKey)}`,
  );
  const remaining = parseRemaining(resp);
  if (!resp.ok) return { sports: [], remaining };
  const sports = await resp.json();
  return { sports: Array.isArray(sports) ? sports : [], remaining };
}

async function fetchSportH2h(
  apiKey: string,
  sport: string,
): Promise<{ events: any[]; billed: number; remaining: number | null }> {
  const url = new URL(`https://api.the-odds-api.com/v4/sports/${sport}/odds/`);
  url.searchParams.set("apiKey", apiKey);
  url.searchParams.set("regions", "us");
  url.searchParams.set("markets", "h2h");
  url.searchParams.set("oddsFormat", "decimal");
  const resp = await fetch(url.toString());
  const remaining = parseRemaining(resp);
  if (!resp.ok) return { events: [], billed: 0, remaining };
  const events = await resp.json();
  if (!Array.isArray(events) || events.length === 0) {
    return { events: [], billed: 0, remaining };
  }
  return { events, billed: parseLastCost(resp) || 1, remaining };
}

async function fetchEventIds(apiKey: string, sport: string): Promise<any[]> {
  const url = new URL(`https://api.the-odds-api.com/v4/sports/${sport}/events`);
  url.searchParams.set("apiKey", apiKey);
  const resp = await fetch(url.toString());
  if (!resp.ok) return [];
  const events = await resp.json();
  return Array.isArray(events) ? events : [];
}

async function fetchEventProps(
  apiKey: string,
  sport: string,
  eventId: string,
  market: string,
): Promise<{ event: any | null; billed: number; remaining: number | null }> {
  const url = new URL(
    `https://api.the-odds-api.com/v4/sports/${sport}/events/${eventId}/odds`,
  );
  url.searchParams.set("apiKey", apiKey);
  url.searchParams.set("regions", "us");
  url.searchParams.set("markets", market);
  url.searchParams.set("oddsFormat", "decimal");
  const resp = await fetch(url.toString());
  const remaining = parseRemaining(resp);
  if (!resp.ok) return { event: null, billed: 0, remaining };
  const event = await resp.json();
  if (!event || (Array.isArray(event) && event.length === 0)) {
    return { event: null, billed: 0, remaining };
  }
  return { event, billed: parseLastCost(resp) || 1, remaining };
}

function h2hProps(event: any, sport: BoardSport, slate: string): Prop[] {
  const market = event?.bookmakers?.[0]?.markets?.find((m: any) => m.key === "h2h");
  const outcomes = Array.isArray(market?.outcomes) ? market.outcomes : [];
  const home = String(event?.home_team ?? "Home");
  const away = String(event?.away_team ?? "Away");
  const matchup = `${away} @ ${home}`;
  const eventId = String(event?.id ?? matchup);
  const commenceTime = commenceOf(event);
  const props: Prop[] = [];
  for (const outcome of outcomes) {
    if (!outcome?.name || outcome?.price == null) continue;
    const price = Number(outcome.price);
    if (!Number.isFinite(price) || price <= 1.001) continue;
    props.push({
      id: makeId(slate, "h2h", sport.sport, eventId, String(outcome.name)),
      leagueTag: sport.leagueTag,
      athleteOrTeam: String(outcome.name),
      matchup,
      propDescription: "Moneyline",
      lineText: "H2H",
      pickLabel: String(outcome.name),
      oddsDecimal: Number(price.toFixed(2)),
      commenceTime,
      eventId,
      sportKey: sport.sport,
      homeTeam: home,
      awayTeam: away,
    });
  }
  return props;
}

function overProps(event: any, sport: BoardSport, slate: string): Prop[] {
  const home = String(event?.home_team ?? "Home");
  const away = String(event?.away_team ?? "Away");
  const matchup = `${away} @ ${home}`;
  const eventId = String(event?.id ?? matchup);
  const commenceTime = commenceOf(event);
  const market = event?.bookmakers?.[0]?.markets?.find((m: any) => m.key === sport.propMarket);
  const outcomes = Array.isArray(market?.outcomes) ? market.outcomes : [];
  const byPlayer = new Map<string, { Over?: { price: number; point: number }; Under?: { price: number; point: number } }>();
  for (const outcome of outcomes) {
    const side = String(outcome?.name ?? "");
    if (side !== "Over" && side !== "Under") continue;
    const player = String(outcome?.description ?? "").trim();
    if (!player) continue;
    const price = Number(outcome.price);
    if (!Number.isFinite(price) || price <= 1.001) continue;
    const point = outcome.point != null ? Number(outcome.point) : NaN;
    const rec = byPlayer.get(player) ?? {};
    rec[side as "Over" | "Under"] = { price, point };
    byPlayer.set(player, rec);
  }
  const props: Prop[] = [];
  for (const [player, sides] of byPlayer) {
    const over = sides.Over;
    const under = sides.Under;
    const primary = over ?? under;
    if (!primary) continue;
    const line = Number.isFinite(primary.point) ? String(primary.point) : "O/U";
    const pickLabel = over && under ? "O/U" : (over ? "Over" : "Under");
    props.push({
      id: makeId(slate, "prop", sport.sport, eventId, player),
      leagueTag: sport.leagueTag,
      athleteOrTeam: player,
      matchup,
      propDescription: sport.propLabel,
      lineText: line,
      pickLabel,
      oddsDecimal: Number(primary.price.toFixed(2)),
      commenceTime,
      eventId,
      sportKey: sport.sport,
      homeTeam: home,
      awayTeam: away,
      pointLine: Number.isFinite(primary.point) ? primary.point : undefined,
      overOdds: over ? Number(over.price.toFixed(2)) : undefined,
      underOdds: under ? Number(under.price.toFixed(2)) : undefined,
    });
    if (props.length >= PROP_MAX_PER_EVENT) return props;
  }
  return props;
}

function numericRoundsFromProps(props: Prop[], take: number): RoundSpec[] {
  const withLine = props.filter((p) => typeof p.pointLine === "number" && p.eventId && p.commenceTime);
  return withLine.slice(0, take).map((p, i) => ({
    round: i + 1,
    propLabel: `${p.athleteOrTeam} — ${p.propDescription}`,
    statSummary: `Closest to actual ${p.propDescription.toLowerCase()} (${p.matchup}). Line ${p.lineText}.`,
    line: p.pointLine as number,
    eventId: p.eventId as string,
    matchup: p.matchup,
    player: p.athleteOrTeam,
    commenceTime: p.commenceTime as string,
    sportKey: p.sportKey ?? "",
  }));
}

function oversWithLine(allProps: Prop[]): Prop[] {
  return allProps.filter((p) =>
    (p.pickLabel === "Over" || p.pickLabel === "O/U") &&
    typeof p.pointLine === "number" && p.eventId && p.commenceTime
  );
}

function groupByEvent(props: Prop[]): Map<string, Prop[]> {
  const m = new Map<string, Prop[]>();
  for (const p of props) {
    const id = String(p.eventId);
    const list = m.get(id) ?? [];
    list.push(p);
    m.set(id, list);
  }
  return m;
}

function combinedScoreRound(p: Prop, round: number): RoundSpec | null {
  if (!p.eventId || !p.commenceTime) return null;
  return {
    round,
    propLabel: `${p.matchup} — combined score`,
    statSummary: "Closest to the final combined score (both teams).",
    eventId: p.eventId,
    matchup: p.matchup,
    player: "Combined score",
    commenceTime: p.commenceTime,
    sportKey: p.sportKey ?? "",
  };
}

function uniqueMoneylineProps(allProps: Prop[], skipEventIds: Set<string>): Prop[] {
  const out: Prop[] = [];
  const used = new Set<string>();
  for (const p of allProps) {
    const desc = (p.propDescription ?? "").toLowerCase();
    if (!desc.includes("moneyline") && !desc.includes("h2h")) continue;
    const id = p.eventId;
    if (!id || !p.commenceTime || used.has(id) || skipEventIds.has(id)) continue;
    used.add(id);
    out.push(p);
  }
  return out;
}

function payloadFromRounds(
  kind: "daily" | "weekly",
  periodKey: string,
  title: string,
  rounds: RoundSpec[],
): TourneyPayload {
  const numbered = rounds.slice(0, 4).map((r, i) => ({ ...r, round: i + 1 }));
  const same = numbered.every((r) => r.matchup === numbered[0].matchup);
  return {
    kind,
    periodKey,
    title,
    gameLabel: same ? numbered[0].matchup : `${numbered.length} games`,
    commenceTime: numbered[0].commenceTime,
    freezeAt: freezeAtIso(numbered[0].commenceTime),
    roundSpecs: numbered,
  };
}

function dailyTourneyFromProps(
  allProps: Prop[],
  slate: string,
): { payload: TourneyPayload | null; diag: TourneyDiag } {
  const overs = oversWithLine(allProps);
  const byEvent = groupByEvent(overs);
  let bestId = "";
  let best: Prop[] = [];
  for (const [id, list] of byEvent) {
    if (list.length > best.length) {
      best = list;
      bestId = id;
    }
  }
  let fallback = "same_game_4_props";
  let rounds = numericRoundsFromProps(best, 4);
  if (rounds.length < 4) {
    const fill = overs.filter((p) => p.eventId !== bestId);
    rounds = numericRoundsFromProps([...best, ...fill], 4);
    fallback = best.length > 0 ? "same_game_plus_other_props" : "any_over_props";
  }
  if (rounds.length < 4) {
    const skip = new Set(rounds.map((r) => r.eventId));
    for (const p of uniqueMoneylineProps(allProps, skip)) {
      const extra = combinedScoreRound(p, rounds.length + 1);
      if (!extra) continue;
      rounds.push(extra);
      if (rounds.length >= 4) break;
    }
    fallback = "mixed_props_and_combined_score";
  }
  const counts =
    `overs=${overs.length} eventsWithOvers=${byEvent.size} moneylineEvents=${uniqueMoneylineProps(allProps, new Set()).length} rounds=${rounds.length}`;
  if (rounds.length < 2) {
    return {
      payload: null,
      diag: {
        kind: "daily",
        ok: false,
        fallback,
        detail: `Could not build daily tourney. ${counts}`,
      },
    };
  }
  if (rounds.length < 4) {
    fallback = `${fallback}_short_${rounds.length}`;
  }
  return {
    payload: payloadFromRounds("daily", slate, "Daily closest-pick", rounds),
    diag: {
      kind: "daily",
      ok: true,
      fallback,
      detail: `Built daily tourney. ${counts} fallback=${fallback}`,
    },
  };
}

function pickOnePerEvent(eventsOrdered: string[], byEvent: Map<string, Prop[]>, take: number): Prop[] {
  const picked: Prop[] = [];
  const used = new Set<string>();
  for (const id of eventsOrdered) {
    if (used.has(id)) continue;
    const list = byEvent.get(id);
    if (!list?.[0]) continue;
    picked.push(list[0]);
    used.add(id);
    if (picked.length >= take) break;
  }
  if (picked.length < take) {
    for (const [id, list] of byEvent) {
      if (used.has(id) || !list[0]) continue;
      picked.push(list[0]);
      used.add(id);
      if (picked.length >= take) break;
    }
  }
  return picked;
}

function weeklyTourneyFromBoard(
  allProps: Prop[],
  nflEvents: any[],
  weekKey: string,
  now: Date,
): { payload: TourneyPayload | null; diag: TourneyDiag } {
  const overs = oversWithLine(allProps);
  const byEvent = groupByEvent(overs);
  const nflUpcoming = [...nflEvents]
    .filter((e) => inNflWeek(commenceOf(e), weekKey) && eventNotStarted(commenceOf(e), now))
    .sort((a, b) => (Date.parse(commenceOf(a)) || 0) - (Date.parse(commenceOf(b)) || 0));
  const nflIds = nflUpcoming.map((e) => String(e?.id ?? "")).filter(Boolean);
  const nflOvers = overs.filter((p) => (p.sportKey ?? "").includes("nfl"));
  const otherOvers = overs.filter((p) => !(p.sportKey ?? "").includes("nfl"));

  let fallback = "nfl_props_multi_game";
  let picked = pickOnePerEvent(nflIds, groupByEvent(nflOvers), 4);
  if (picked.length < 4) {
    const restIds = [...byEvent.keys()].sort((a, b) => {
      const ta = Date.parse(byEvent.get(a)?.[0]?.commenceTime ?? "") || 0;
      const tb = Date.parse(byEvent.get(b)?.[0]?.commenceTime ?? "") || 0;
      return ta - tb;
    });
    picked = pickOnePerEvent(
      [...nflIds, ...restIds],
      groupByEvent([...nflOvers, ...otherOvers]),
      4,
    );
    fallback = nflUpcoming.length > 0 ? "nfl_plus_other_sports_props" : "multi_sport_props";
  }

  let rounds = numericRoundsFromProps(picked, 4);
  if (rounds.length < 4 && nflUpcoming.length > 0) {
    const skip = new Set(rounds.map((r) => r.eventId));
    for (const e of nflUpcoming) {
      const id = String(e?.id ?? "");
      if (!id || skip.has(id)) continue;
      const home = String(e?.home_team ?? "Home");
      const away = String(e?.away_team ?? "Away");
      const commenceTime = commenceOf(e);
      if (!commenceTime) continue;
      rounds.push({
        round: rounds.length + 1,
        propLabel: `${away} @ ${home} — combined score`,
        statSummary: "Closest to the final combined score (both teams).",
        eventId: id,
        matchup: `${away} @ ${home}`,
        player: "Combined score",
        commenceTime,
        sportKey: "americanfootball_nfl",
      });
      skip.add(id);
      if (rounds.length >= 4) break;
    }
    fallback = "nfl_combined_score_no_synthetic_line";
  }
  if (rounds.length < 4) {
    const skip = new Set(rounds.map((r) => r.eventId));
    for (const p of uniqueMoneylineProps(allProps, skip)) {
      const extra = combinedScoreRound(p, rounds.length + 1);
      if (!extra) continue;
      rounds.push(extra);
      if (rounds.length >= 4) break;
    }
    fallback = "weekly_mixed_props_and_combined_score";
  }

  const counts =
    `nflUpcoming=${nflUpcoming.length} overs=${overs.length} nflOvers=${nflOvers.length} otherOvers=${otherOvers.length} rounds=${rounds.length}`;
  if (rounds.length < 2) {
    return {
      payload: null,
      diag: {
        kind: "weekly",
        ok: false,
        fallback,
        detail: `Could not build weekly tourney. ${counts}`,
      },
    };
  }
  if (rounds.length < 4) fallback = `${fallback}_short_${rounds.length}`;
  const inNfl = nflUpcoming.length >= 2 && rounds.every((r) => (r.sportKey ?? "").includes("nfl"));
  return {
    payload: payloadFromRounds(
      "weekly",
      weekKey,
      inNfl ? "Weekly NFL closest-pick" : "Weekly closest-pick",
      rounds,
    ),
    diag: {
      kind: "weekly",
      ok: true,
      fallback,
      detail: `Built weekly tourney. ${counts} fallback=${fallback}`,
    },
  };
}

async function liveBoardFromOddsApi(
  apiKey: string,
  slate: string,
  now: Date,
  keep: {
    daily?: TourneyPayload | null;
    weekly?: TourneyPayload | null;
    nextDaily?: TourneyPayload | null;
    nextWeekly?: TourneyPayload | null;
  } = {},
): Promise<{
  ribbons: Ribbon[];
  tomorrowRibbons: Ribbon[];
  dailyTourney: TourneyPayload | null;
  weeklyTourney: TourneyPayload | null;
  nextDailyTourney: TourneyPayload | null;
  nextWeeklyTourney: TourneyPayload | null;
  creditsSpent: number;
  tourneyDiagnostics: { daily: TourneyDiag; weekly: TourneyDiag };
}> {
  const nextSlate = nextSlateKey(now);
  const weekKey = calendarWeekKey(now);
  const nextWeekKey = nextCalendarWeekKey(now);
  const sundayEarly = isSundayEarlyWeeklyWindow(now);

  const catalog = await oddsSportsCatalog(apiKey);
  if (catalog.remaining != null && catalog.remaining < ODDS_MIN_REMAINING) {
    const empty = {
      kind: "daily" as const,
      ok: false,
      fallback: "quota_reserve",
      detail: `Skipped tourney build; Odds remaining ${catalog.remaining} below reserve ${ODDS_MIN_REMAINING}.`,
    };
    return {
      ribbons: [],
      tomorrowRibbons: [],
      dailyTourney: reusableTourney(keep.daily, slate),
      weeklyTourney: reusableTourney(keep.weekly, weekKey),
      nextDailyTourney: reusableTourney(keep.nextDaily, nextSlate),
      nextWeeklyTourney: sundayEarly ? reusableTourney(keep.nextWeekly, nextWeekKey) : null,
      creditsSpent: 0,
      tourneyDiagnostics: {
        daily: empty,
        weekly: { ...empty, kind: "weekly" },
      },
    };
  }

  const activeKeys = new Set(
    catalog.sports.filter((s) => s.active && typeof s.key === "string").map((s) => s.key as string),
  );

  let remaining = catalog.remaining;
  let spent = 0;
  const ribbons: Ribbon[] = [];
  const tomorrowRibbons: Ribbon[] = [];
  const allProps: Prop[] = [];
  const tomorrowProps: Prop[] = [];
  let nflAllUpcoming: any[] = [];
  const sportsWithToday: BoardSport[] = [];
  const todayEventsBySport = new Map<string, any[]>();

  for (const sport of BOARD_SPORTS) {
    if (!activeKeys.has(sport.sport)) continue;
    if (spent >= MAX_ODDS_CREDITS_PER_DAY) break;
    const { events, billed, remaining: nextRemaining } = await fetchSportH2h(apiKey, sport.sport);
    if (nextRemaining != null) remaining = nextRemaining;
    spent += billed;
    if (remaining != null && remaining < ODDS_MIN_REMAINING) break;
    if (sport.sport === "americanfootball_nfl") nflAllUpcoming = events;
    const today = filterUpcomingOnSlate(events, slate, now);
    const tomorrow = filterUpcomingOnSlate(events, nextSlate, now);
    if (today.length > 0) {
      sportsWithToday.push(sport);
      todayEventsBySport.set(sport.sport, today);
      const props = today.flatMap((e) => h2hProps(e, sport, slate));
      if (props.length > 0) {
        allProps.push(...props);
        ribbons.push({
          id: `live_${sport.leagueTag.toLowerCase()}`,
          title: sport.label,
          subtitle: `Today · ${sport.label} moneylines`,
          props,
        });
      }
    }
    if (tomorrow.length > 0) {
      const props = tomorrow.flatMap((e) => h2hProps(e, sport, nextSlate));
      if (props.length > 0) {
        tomorrowProps.push(...props);
        tomorrowRibbons.push({
          id: `live_tomorrow_${sport.leagueTag.toLowerCase()}`,
          title: sport.label,
          subtitle: `Tomorrow · ${sport.label} moneylines`,
          props,
        });
      }
    }
  }

  for (const sport of sportsWithToday) {
    if (spent >= MAX_ODDS_CREDITS_PER_DAY) break;
    const today = todayEventsBySport.get(sport.sport) ?? [];
    const take = today.slice(0, PROP_GAMES_PER_SPORT);
    const freeEvents = filterUpcomingOnSlate(await fetchEventIds(apiKey, sport.sport), slate, now);
    const pool = (freeEvents.length > 0 ? freeEvents : take).slice(0, PROP_GAMES_PER_SPORT);
    for (const ev of pool) {
      if (spent >= MAX_ODDS_CREDITS_PER_DAY) break;
      const id = ev?.id;
      if (!id) continue;
      const { event, billed, remaining: nextRemaining } = await fetchEventProps(
        apiKey,
        sport.sport,
        String(id),
        sport.propMarket,
      );
      if (nextRemaining != null) remaining = nextRemaining;
      spent += billed;
      if (remaining != null && remaining < ODDS_MIN_REMAINING) break;
      if (!event) continue;
      const props = overProps(event, sport, slate);
      if (props.length === 0) continue;
      allProps.push(...props);
      ribbons.push({
        id: `live_props_${sport.leagueTag.toLowerCase()}_${String(id).slice(0, 8)}`,
        title: `${sport.label} props`,
        subtitle: `${sport.propLabel} · ${props[0].matchup}`,
        props,
      });
    }
  }

  const frozenDaily = reusableTourney(keep.daily, slate);
  const daily = frozenDaily
    ? {
      payload: frozenDaily,
      diag: {
        kind: "daily" as const,
        ok: true,
        fallback: "frozen_existing",
        detail: `Kept existing daily tourney for ${slate}.`,
      },
    }
    : dailyTourneyFromProps(allProps, slate);

  const frozenWeekly = reusableTourney(keep.weekly, weekKey);
  const weekly = frozenWeekly
    ? {
      payload: frozenWeekly,
      diag: {
        kind: "weekly" as const,
        ok: true,
        fallback: "frozen_existing",
        detail: `Kept existing weekly tourney for ${weekKey}.`,
      },
    }
    : weeklyTourneyFromBoard(allProps, nflAllUpcoming, weekKey, now);

  const nextDaily = reusableTourney(keep.nextDaily, nextSlate) ??
    dailyTourneyFromProps(tomorrowProps, nextSlate).payload;

  let nextWeekly: TourneyPayload | null = null;
  if (sundayEarly) {
    nextWeekly = reusableTourney(keep.nextWeekly, nextWeekKey) ??
      weeklyTourneyFromBoard(tomorrowProps, nflAllUpcoming, nextWeekKey, now).payload;
  }

  return {
    ribbons,
    tomorrowRibbons,
    dailyTourney: daily.payload,
    weeklyTourney: weekly.payload,
    nextDailyTourney: nextDaily,
    nextWeeklyTourney: nextWeekly,
    creditsSpent: spent,
    tourneyDiagnostics: { daily: daily.diag, weekly: weekly.diag },
  };
}

function parseStoredBoard(board: unknown): SnapshotBoard | null {
  if (!board) return null;
  if (Array.isArray(board)) {
    return { version: 2, ribbons: board as Ribbon[], dailyTourney: null, weeklyTourney: null, creditsSpent: 0 };
  }
  if (typeof board === "object") {
    const obj = board as Record<string, unknown>;
    if (Array.isArray(obj.ribbons)) {
      return {
        version: 2,
        ribbons: obj.ribbons as Ribbon[],
        tomorrowRibbons: Array.isArray(obj.tomorrowRibbons) ? obj.tomorrowRibbons as Ribbon[] : undefined,
        dailyTourney: (obj.dailyTourney as TourneyPayload) ?? null,
        weeklyTourney: (obj.weeklyTourney as TourneyPayload) ?? null,
        nextDailyTourney: (obj.nextDailyTourney as TourneyPayload) ?? null,
        nextWeeklyTourney: (obj.nextWeeklyTourney as TourneyPayload) ?? null,
        creditsSpent: Number(obj.creditsSpent) || 0,
        tourneyDiagnostics: obj.tourneyDiagnostics as SnapshotBoard["tourneyDiagnostics"],
      };
    }
  }
  return null;
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

function bearerToken(req: Request): string | null {
  const header = req.headers.get("Authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function logTourneyGaps(
  admin: ReturnType<typeof createClient>,
  diags: TourneyDiag[] | undefined,
  slate: string,
  source: string,
) {
  if (!diags?.length) return;
  for (const diag of diags) {
    const severity = diag.ok ? "info" : "error";
    console[diag.ok ? "log" : "error"](`tourney ${diag.kind}: ${diag.detail}`);
    if (diag.ok) continue;
    await admin.from("juicd_app_errors").insert({
      severity,
      message: diag.detail.slice(0, 500),
      screen: "tourney",
      extra: {
        kind: "tourney_generation",
        tourneyKind: diag.kind,
        fallback: diag.fallback,
        ok: diag.ok,
        slate,
        source,
      },
      platform: "edge",
      app_version: "play-board",
    });
  }
}

function liveFilter(ribbons: Ribbon[], slate: string, now: Date): Ribbon[] {
  return ribbons.flatMap((ribbon) => {
    const props = (ribbon.props ?? []).filter((p) =>
      eventOnSlate(p.commenceTime, slate) && eventNotStarted(p.commenceTime, now)
    );
    if (props.length === 0) return [];
    return [{ ...ribbon, props }];
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "GET") return json({ error: "method_not_allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const oddsApiKey = Deno.env.get("ODDS_API_KEY") ?? "";
  if (!supabaseUrl || !serviceRole) return json({ error: "Missing Supabase env vars" }, 500);

  const url = new URL(req.url);
  if (url.searchParams.get("quota") === "1" || url.searchParams.get("quota") === "true") {
    if (!oddsApiKey) return json({ error: "missing_odds_api_key" }, 500);
    const sportsResp = await fetch(
      `https://api.the-odds-api.com/v4/sports/?apiKey=${encodeURIComponent(oddsApiKey)}`,
    );
    return json({
      used: sportsResp.headers.get("x-requests-used"),
      remaining: sportsResp.headers.get("x-requests-remaining"),
      last: sportsResp.headers.get("x-requests-last"),
      httpStatus: sportsResp.status,
      countsAgainstQuota: false,
    });
  }

  const force = url.searchParams.get("force") === "1" || url.searchParams.get("force") === "true";
  if (force && bearerToken(req) !== serviceRole) {
    return json({ error: "internal_refresh_required" }, 403);
  }

  const admin = createClient(supabaseUrl, serviceRole);
  const now = new Date();
  const slate = juicdSlateKey(now);

  const { data: configRows } = await admin
    .from("juicd_runtime_config")
    .select("key, value")
    .in("key", ["odds_mode"]);
  const config = Object.fromEntries(
    (configRows ?? []).map((r: { key: string; value: string }) => [r.key, r.value]),
  );
  const mode = config.odds_mode === "live" ? "live" : "simulated";

  async function loadSnapshot(): Promise<SnapshotRow | null> {
    const { data } = await admin
      .from("juicd_play_board_snapshots")
      .select("slate_key, mode, source, board, updated_at, refresh_started_at")
      .eq("slate_key", slate)
      .maybeSingle();
    return (data as SnapshotRow) ?? null;
  }

  function respond(source: string, stored: SnapshotBoard, cached: boolean, updatedAt: string | null) {
    const nextSlate = nextSlateKey(now);
    const ribbons = liveFilter(stored.ribbons, slate, now);
    const tomorrowRibbons = liveFilter(stored.tomorrowRibbons ?? [], nextSlate, now);
    return json({
      mode,
      source,
      slateKey: slate,
      nextSlateKey: nextSlate,
      weekKey: calendarWeekKey(now),
      nextWeekKey: nextCalendarWeekKey(now),
      ribbons,
      tomorrowRibbons,
      dailyTourney: stored.dailyTourney,
      weeklyTourney: stored.weeklyTourney,
      nextDailyTourney: stored.nextDailyTourney ?? null,
      nextWeeklyTourney: isSundayEarlyWeeklyWindow(now) ? (stored.nextWeeklyTourney ?? null) : null,
      creditsSpent: stored.creditsSpent,
      tourneyDiagnostics: stored.tourneyDiagnostics,
      cached,
      ageSeconds: ageSeconds(updatedAt),
      ttlSeconds: 60,
    });
  }

  let snapshot = await loadSnapshot();
  const stored = snapshot ? parseStoredBoard(snapshot.board) : null;
  function boardHasUnderSides(stored: SnapshotBoard): boolean {
    const props = (stored.ribbons ?? []).flatMap((r) => r.props ?? []);
    if (props.some((p) => typeof p.underOdds === "number" || p.pickLabel === "O/U")) return true;
    const overs = props.filter((p) => p.pickLabel === "Over").length;
    if (overs === 0) return true;
    return props.some((p) => p.pickLabel === "Under");
  }

  const sameSlateFresh = !force && snapshot && snapshot.mode === mode && stored &&
    snapshot.slate_key === slate && stored.tomorrowRibbons !== undefined && boardHasUnderSides(stored);

  if (sameSlateFresh) {
    return respond(snapshot!.source, stored!, true, snapshot!.updated_at);
  }

  const lockActive = snapshot?.refresh_started_at &&
    Date.now() - Date.parse(snapshot.refresh_started_at) < REFRESH_LOCK_MS;
  if (!force && lockActive) {
    const deadline = Date.now() + STAMPEDE_WAIT_MS;
    while (Date.now() < deadline) {
      await sleep(STAMPEDE_POLL_MS);
      snapshot = await loadSnapshot();
      const again = snapshot ? parseStoredBoard(snapshot.board) : null;
      if (snapshot && again && snapshot.mode === mode && !snapshot.refresh_started_at) {
        return respond(snapshot.source, again, true, snapshot.updated_at);
      }
    }
    if (stored) return respond(snapshot?.source ?? "odds_api", stored, true, snapshot?.updated_at ?? null);
  }

  const lockAt = new Date().toISOString();
  await admin.from("juicd_play_board_snapshots").upsert({
    slate_key: slate,
    mode,
    source: snapshot?.source ?? "refreshing",
    board: snapshot?.board ?? {
      version: 2,
      ribbons: [],
      tomorrowRibbons: [],
      dailyTourney: null,
      weeklyTourney: null,
      nextDailyTourney: null,
      nextWeeklyTourney: null,
      creditsSpent: 0,
    },
    updated_at: snapshot?.updated_at ?? lockAt,
    refresh_started_at: lockAt,
  });

  let payload: SnapshotBoard = {
    version: 2,
    ribbons: [],
    tomorrowRibbons: [],
    dailyTourney: null,
    weeklyTourney: null,
    nextDailyTourney: null,
    nextWeeklyTourney: null,
    creditsSpent: 0,
  };
  let source = "odds_api";
  try {
    if (mode === "live" && oddsApiKey) {
      const { data: prevRow } = await admin
        .from("juicd_play_board_snapshots")
        .select("board")
        .eq("slate_key", previousSlateKey(now))
        .maybeSingle();
      const prevBoard = prevRow ? parseStoredBoard(prevRow.board) : null;
      const weekKey = calendarWeekKey(now);
      const live = await liveBoardFromOddsApi(oddsApiKey, slate, now, {
        daily: reusableTourney(stored?.dailyTourney, slate) ??
          reusableTourney(prevBoard?.nextDailyTourney, slate),
        weekly: reusableTourney(stored?.weeklyTourney, weekKey) ??
          reusableTourney(prevBoard?.nextWeeklyTourney, weekKey),
        nextDaily: stored?.nextDailyTourney ?? prevBoard?.nextDailyTourney,
        nextWeekly: stored?.nextWeeklyTourney ?? prevBoard?.nextWeeklyTourney,
      });
      payload = {
        version: 2,
        ribbons: live.ribbons,
        tomorrowRibbons: live.tomorrowRibbons,
        dailyTourney: live.dailyTourney,
        weeklyTourney: live.weeklyTourney,
        nextDailyTourney: live.nextDailyTourney,
        nextWeeklyTourney: live.nextWeeklyTourney,
        creditsSpent: live.creditsSpent,
        tourneyDiagnostics: live.tourneyDiagnostics,
      };
      source = live.ribbons.length > 0 || live.tomorrowRibbons.length > 0 ? "odds_api" : "odds_api_empty";
      await logTourneyGaps(admin, [live.tourneyDiagnostics.daily, live.tourneyDiagnostics.weekly], slate, source);
    } else {
      source = "simulated_disabled";
      payload.tourneyDiagnostics = {
        daily: {
          kind: "daily",
          ok: false,
          fallback: "simulated_disabled",
          detail: "Could not build daily tourney because odds_mode is not live.",
        },
        weekly: {
          kind: "weekly",
          ok: false,
          fallback: "simulated_disabled",
          detail: "Could not build weekly tourney because odds_mode is not live.",
        },
      };
      await logTourneyGaps(admin, [payload.tourneyDiagnostics.daily, payload.tourneyDiagnostics.weekly], slate, source);
    }
  } catch (_e) {
    if (stored) {
      const patched: SnapshotBoard = {
        ...stored,
        tomorrowRibbons: stored.tomorrowRibbons ?? [],
      };
      await admin.from("juicd_play_board_snapshots").upsert({
        slate_key: slate,
        mode: snapshot!.mode,
        source: snapshot!.source,
        board: patched,
        updated_at: snapshot!.updated_at,
        refresh_started_at: null,
      });
      return respond(snapshot!.source, patched, true, snapshot!.updated_at);
    }
    source = "odds_api_error";
  }

  const updatedAt = new Date().toISOString();
  await admin.from("juicd_play_board_snapshots").upsert({
    slate_key: slate,
    mode,
    source,
    board: payload,
    updated_at: updatedAt,
    refresh_started_at: null,
  });

  return respond(source, payload, false, updatedAt);
});
