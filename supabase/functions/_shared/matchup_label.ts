/** UFC/MMA head-to-head uses " vs ". Every other sport uses " @ ". */
export function h2hSeparator(sportKey: string, leagueTag?: string | null): " vs " | " @ " {
  const key = (sportKey ?? "").toLowerCase();
  const tag = (leagueTag ?? "").toUpperCase();
  if (tag === "UFC" || tag === "MMA" || key.includes("mma") || key.includes("ufc")) {
    return " vs ";
  }
  return " @ ";
}

export function h2hMatchup(
  away: string,
  home: string,
  sportKey: string,
  leagueTag?: string | null,
): string {
  return `${away}${h2hSeparator(sportKey, leagueTag)}${home}`;
}
