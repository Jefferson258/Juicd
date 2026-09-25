/** ESPN public scoreboard + boxscore helpers. No API key. Free; does not use Odds credits. */

export function espnPath(sportKey: string): string | null {
  const k = sportKey.toLowerCase();
  // CFB / NCAAF before the generic americanfootball → NFL fallback.
  if (k.includes("ncaaf") || k.includes("college-football") || k.includes("collegefootball") || k === "cfb") {
    return "football/college-football";
  }
  if (k.includes("nfl") || k.includes("americanfootball") || k === "football") {
    return "football/nfl";
  }
  if (k.includes("nba") || k.includes("basketball")) return "basketball/nba";
  if (k.includes("mlb") || k.includes("baseball")) return "baseball/mlb";
  if (k.includes("nhl") || k.includes("hockey")) return "hockey/nhl";
  return null;
}

export function yyyymmdd(iso?: string): string {
  const d = iso ? new Date(iso) : new Date();
  const ct = new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Chicago",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(d);
  return ct.replaceAll("-", "");
}

export function norm(s: string): string {
  return s.toLowerCase().replace(/[^a-z0-9]/g, "");
}

export function namesMatch(a: string, b: string): boolean {
  const na = norm(a);
  const nb = norm(b);
  return na.length > 0 && nb.length > 0 && (na === nb || na.includes(nb) || nb.includes(na));
}

/** "HOU @ SEA" / "HOU vs SEA" → away, home. */
export function parseMatchup(matchup: string): { away: string; home: string } | null {
  const raw = matchup.trim();
  const parts = raw.split(/\s+(?:@|vs\.?|at)\s+/i);
  if (parts.length !== 2) return null;
  const away = parts[0].trim();
  const home = parts[1].trim();
  if (!away || !home) return null;
  return { away, home };
}

export type ScoreboardEvent = {
  id: string;
  status: string;
  isFinal: boolean;
  homeName: string;
  awayName: string;
  homeAbbr: string;
  awayAbbr: string;
  homeShort: string;
  awayShort: string;
  homeScore: number;
  awayScore: number;
};

export type BoxPlayer = { name: string; stats: Record<string, number> };

function parseNum(raw: unknown): number | null {
  if (raw == null) return null;
  const s = String(raw).replace(/,/g, "").trim();
  if (!s || s.includes("/")) return null;
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}

function groupPrefix(groupName: string): string {
  const g = groupName.toLowerCase();
  if (g.includes("pass")) return "PASS_";
  if (g.includes("rush")) return "RUSH_";
  if (g.includes("receiv")) return "REC_";
  return "";
}

function teamLabels(c: any): { name: string; abbr: string; short: string } {
  const team = c?.team ?? {};
  return {
    name: String(team.displayName ?? team.name ?? ""),
    abbr: String(team.abbreviation ?? ""),
    short: String(team.shortDisplayName ?? team.name ?? ""),
  };
}

function sideNames(ev: ScoreboardEvent, side: "home" | "away"): string[] {
  return side === "home"
    ? [ev.homeName, ev.homeAbbr, ev.homeShort]
    : [ev.awayName, ev.awayAbbr, ev.awayShort];
}

export function teamMatches(ev: ScoreboardEvent, side: "home" | "away", name: string): boolean {
  if (!name.trim()) return false;
  return sideNames(ev, side).some((label) => namesMatch(label, name));
}

export function parseScoreboardEvents(body: any): ScoreboardEvent[] {
  const events = body?.events ?? [];
  return events.map((e: any) => {
    const comps = e?.competitions?.[0]?.competitors ?? [];
    const homeC = comps.find((c: any) => c.homeAway === "home");
    const awayC = comps.find((c: any) => c.homeAway === "away");
    const home = teamLabels(homeC);
    const away = teamLabels(awayC);
    const status = String(e?.status?.type?.name ?? e?.status?.type?.state ?? "");
    const isFinal = /final/i.test(status) || status === "post";
    return {
      id: String(e?.id ?? ""),
      status,
      isFinal,
      homeName: home.name,
      awayName: away.name,
      homeAbbr: home.abbr,
      awayAbbr: away.abbr,
      homeShort: home.short,
      awayShort: away.short,
      homeScore: Number(homeC?.score ?? NaN),
      awayScore: Number(awayC?.score ?? NaN),
    };
  });
}

export function matchEvent(
  events: ScoreboardEvent[],
  home: string,
  away: string,
): ScoreboardEvent | null {
  return events.find((ev) =>
    (teamMatches(ev, "home", home) && teamMatches(ev, "away", away)) ||
    (teamMatches(ev, "home", away) && teamMatches(ev, "away", home))
  ) ?? null;
}

export function gradeMoneyline(
  event: ScoreboardEvent,
  pick: string,
): "won" | "lost" {
  if (event.homeScore === event.awayScore) return "lost";
  const winner: "home" | "away" = event.homeScore > event.awayScore ? "home" : "away";
  return teamMatches(event, winner, pick) ? "won" : "lost";
}

export function parseBoxPlayers(summary: any): BoxPlayer[] {
  const players: BoxPlayer[] = [];
  const blocks = summary?.boxscore?.players ?? [];
  for (const teamBlock of blocks) {
    for (const group of teamBlock?.statistics ?? []) {
      const labels: string[] = group.names ?? group.labels ?? group.keys ?? [];
      const prefix = groupPrefix(String(group.name ?? group.type ?? group.text ?? ""));
      for (const ath of group.athletes ?? []) {
        const name = String(ath?.athlete?.displayName ?? ath?.athlete?.shortName ?? "");
        if (!name) continue;
        const raw: unknown[] = ath.stats ?? [];
        const stats: Record<string, number> = {};
        labels.forEach((label, i) => {
          const v = parseNum(raw[i]);
          if (v == null) return;
          const key = `${prefix}${String(label).toUpperCase()}`;
          stats[key] = v;
          const bare = String(label).toUpperCase();
          if (stats[bare] == null) stats[bare] = v;
        });
        const existing = players.find((p) => namesMatch(p.name, name));
        if (existing) Object.assign(existing.stats, stats);
        else players.push({ name, stats });
      }
    }
  }
  return players;
}

function firstStat(stats: Record<string, number>, keys: string[]): number | null {
  for (const k of keys) {
    if (stats[k] != null) return stats[k];
  }
  return null;
}

export function actualForProp(opts: {
  description: string;
  player: string;
  players: BoxPlayer[];
  homeScore?: number;
  awayScore?: number;
}): number | null {
  const d = `${opts.description} ${opts.player}`.toLowerCase();
  if (
    d.includes("combined") || d.includes("combined score") ||
    d.includes("total score") || d.includes("total points")
  ) {
    if (Number.isFinite(opts.homeScore) && Number.isFinite(opts.awayScore)) {
      return (opts.homeScore as number) + (opts.awayScore as number);
    }
    return null;
  }
  const p = opts.players.find((pl) => namesMatch(pl.name, opts.player));
  if (!p) return null;
  const s = p.stats;
  if (d.includes("pra") || d.includes("pts+reb") || d.includes("points + reb") || d.includes("reb + ast")) {
    const pts = s.PTS ?? 0;
    const reb = s.REB ?? s.TRB ?? 0;
    const ast = s.AST ?? 0;
    return pts + reb + ast;
  }
  if (d.includes("pass") && d.includes("yard")) {
    return firstStat(s, ["PASS_YDS", "YDS"]);
  }
  if (d.includes("rush") && d.includes("yard")) {
    return firstStat(s, ["RUSH_YDS"]);
  }
  if (d.includes("receiv") && d.includes("yard")) {
    return firstStat(s, ["REC_YDS"]);
  }
  if (d.includes("reception") || /\brec\b/.test(d) || d.includes("catches")) {
    return firstStat(s, ["REC", "RECEPTIONS"]);
  }
  if (d.includes("home run") || d.includes("homers") || /\bhr\b/.test(d)) {
    return firstStat(s, ["HR"]);
  }
  if (d.includes("strikeout") || d.includes("strike out") || (/\bk\b/.test(d) && d.includes("pitch"))) {
    return firstStat(s, ["K", "SO"]);
  }
  if (d.includes("rbi")) return firstStat(s, ["RBI"]);
  if (d.includes("hit") && !d.includes("hit by")) return firstStat(s, ["H"]);
  if (d.includes("rebound")) return firstStat(s, ["REB", "TRB"]);
  if (d.includes("assist")) return firstStat(s, ["AST", "A"]);
  if (d.includes("3-point") || d.includes("three") || d.includes("3pt")) {
    return firstStat(s, ["3PT", "3PM", "FG3M"]);
  }
  if (d.includes("goal") && !d.includes("goalie") && !d.includes("shot")) {
    return firstStat(s, ["G"]);
  }
  if (d.includes("shot")) return firstStat(s, ["SOG", "S", "SHOTS"]);
  if (d.includes("point") || d.includes("pts")) return firstStat(s, ["PTS", "P"]);
  if (d.includes("touchdown") || /\btd\b/.test(d)) {
    return firstStat(s, ["PASS_TD", "RUSH_TD", "REC_TD", "TD"]);
  }
  return null;
}

export function gradeOverUnder(
  actual: number,
  line: number,
  pickLabel: string,
): "won" | "lost" | "pending" {
  const over = /over/i.test(pickLabel);
  const under = /under/i.test(pickLabel);
  if (!over && !under) return "pending";
  if (actual === line) return "lost";
  if (over) return actual > line ? "won" : "lost";
  return actual < line ? "won" : "lost";
}

export async function fetchScoreboard(path: string, commenceTime?: string): Promise<any | null> {
  const date = yyyymmdd(commenceTime);
  const url = `https://site.api.espn.com/apis/site/v2/sports/${path}/scoreboard?dates=${date}`;
  const resp = await fetch(url);
  if (!resp.ok) return null;
  return await resp.json();
}

export async function fetchSummary(path: string, eventId: string): Promise<any | null> {
  const url =
    `https://site.api.espn.com/apis/site/v2/sports/${path}/summary?event=${encodeURIComponent(eventId)}`;
  const resp = await fetch(url);
  if (!resp.ok) return null;
  return await resp.json();
}
