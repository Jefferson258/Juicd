import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  actualForProp,
  espnPath,
  fetchScoreboard,
  fetchSummary,
  gradeMoneyline,
  gradeOverUnder,
  matchEvent,
  parseBoxPlayers,
  parseMatchup,
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

type GradeLeg = {
  legId: string;
  sportKey?: string;
  homeTeam?: string;
  awayTeam?: string;
  commenceTime?: string;
  pickLabel?: string;
  athleteOrTeam?: string;
  propDescription?: string;
  pointLine?: number;
  eventId?: string;
  matchup?: string;
};

async function gradeLeg(leg: GradeLeg): Promise<{
  status: "pending" | "won" | "lost";
  actual: number | null;
}> {
  const path = espnPath(leg.sportKey ?? "");
  if (!path) return { status: "pending", actual: null };
  const body = await fetchScoreboard(path, leg.commenceTime);
  if (!body) return { status: "pending", actual: null };
  const events = parseScoreboardEvents(body);
  const parsed = parseMatchup(leg.matchup ?? "");
  const home = (leg.homeTeam || parsed?.home || "").trim();
  const away = (leg.awayTeam || parsed?.away || "").trim();
  const event = matchEvent(events, home, away) ??
    events.find((e) => e.id && e.id === String(leg.eventId ?? ""));
  if (!event || !event.isFinal) return { status: "pending", actual: null };
  if (!Number.isFinite(event.homeScore) || !Number.isFinite(event.awayScore)) {
    return { status: "pending", actual: null };
  }

  const desc = (leg.propDescription ?? "").toLowerCase();
  const pick = leg.pickLabel || leg.athleteOrTeam || "";
  const isMoneyline = desc.includes("moneyline") || desc.includes("h2h") ||
    desc.includes("head-to-head");
  if (isMoneyline) {
    return {
      status: gradeMoneyline(event, pick),
      actual: event.homeScore + event.awayScore,
    };
  }

  const summary = await fetchSummary(path, event.id || String(leg.eventId ?? ""));
  const players = summary ? parseBoxPlayers(summary) : [];
  const actual = actualForProp({
    description: `${leg.propDescription ?? ""} ${leg.pickLabel ?? ""}`,
    player: leg.athleteOrTeam || pick,
    players,
    homeScore: event.homeScore,
    awayScore: event.awayScore,
  });
  if (actual == null || leg.pointLine == null) {
    return { status: "pending", actual };
  }
  return {
    status: gradeOverUnder(actual, leg.pointLine, pick),
    actual,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceRole) return json({ error: "server_configuration_missing" }, 500);
  const admin = createClient(supabaseUrl, serviceRole);
  const header = req.headers.get("Authorization") ?? "";
  const token = header.match(/^Bearer\s+(.+)$/i)?.[1]?.trim();
  if (!token) return json({ error: "authentication_required" }, 401);
  const { data: authData, error: authError } = await admin.auth.getUser(token);
  if (authError || !authData.user) return json({ error: "invalid_session" }, 401);

  const body = await req.json().catch(() => null) as { legs?: GradeLeg[] } | null;
  const legs = Array.isArray(body?.legs) ? body!.legs : [];
  const outcomes = [];
  for (const leg of legs.slice(0, 16)) {
    if (!leg?.legId) continue;
    const result = await gradeLeg(leg);
    outcomes.push({
      legId: leg.legId,
      status: result.status,
      didWin: result.status === "won" ? true : result.status === "lost" ? false : null,
      actual: result.actual,
    });
  }
  return json({ outcomes });
});
