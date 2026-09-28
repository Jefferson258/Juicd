import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { h2hMatchup, h2hSeparator } from "./matchup_label.ts";

Deno.test("UFC and MMA H2H matchups use vs", () => {
  assertEquals(h2hSeparator("mma_mixed_martial_arts", "UFC"), " vs ");
  assertEquals(h2hSeparator("mma_mixed_martial_arts"), " vs ");
  assertEquals(h2hSeparator("ufc", "MMA"), " vs ");
  assertEquals(
    h2hMatchup("Islam Makhachev", "Arman Tsarukyan", "mma_mixed_martial_arts", "UFC"),
    "Islam Makhachev vs Arman Tsarukyan",
  );
});

Deno.test("other sports keep @", () => {
  for (const [sport, tag] of [
    ["americanfootball_nfl", "NFL"],
    ["americanfootball_ncaaf", "CFB"],
    ["basketball_nba", "NBA"],
    ["baseball_mlb", "MLB"],
    ["icehockey_nhl", "NHL"],
    ["soccer_usa_mls", "MLS"],
    ["basketball_wnba", "WNBA"],
  ] as const) {
    assertEquals(h2hSeparator(sport, tag), " @ ");
    assertEquals(h2hMatchup("Away", "Home", sport, tag), "Away @ Home");
  }
});
