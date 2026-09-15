import {
  actualForProp,
  espnPath,
  gradeMoneyline,
  gradeOverUnder,
  matchEvent,
  parseBoxPlayers,
  parseMatchup,
  parseScoreboardEvents,
} from "./espn.ts";
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test("boxscore hits and PRA map to actuals", () => {
  const summary = {
    boxscore: {
      players: [{
        statistics: [
          {
            name: "batting",
            names: ["AB", "R", "H", "RBI", "HR"],
            athletes: [{
              athlete: { displayName: "Yordan Alvarez" },
              stats: ["4", "1", "2", "3", "1"],
            }],
          },
          {
            name: "batting",
            names: ["MIN", "PTS", "REB", "AST"],
            athletes: [{
              athlete: { displayName: "Nikola Jokic" },
              stats: ["34", "22", "11", "8"],
            }],
          },
        ],
      }],
    },
  };
  const players = parseBoxPlayers(summary);
  assertEquals(
    actualForProp({ description: "Hits", player: "Yordan Alvarez", players }),
    2,
  );
  assertEquals(
    actualForProp({
      description: "Points + reb + ast",
      player: "Nikola Jokic",
      players,
    }),
    41,
  );
});

Deno.test("over/under uses the line", () => {
  assertEquals(gradeOverUnder(49, 48.5, "Over"), "won");
  assertEquals(gradeOverUnder(47, 48.5, "Over"), "lost");
  assertEquals(gradeOverUnder(27, 27.5, "Under"), "won");
});

Deno.test("HOU @ SEA matches ESPN abbreviations", () => {
  const parsed = parseMatchup("HOU @ SEA");
  assertEquals(parsed?.away, "HOU");
  assertEquals(parsed?.home, "SEA");
  const events = parseScoreboardEvents({
    events: [{
      id: "401",
      status: { type: { name: "STATUS_FINAL" } },
      competitions: [{
        competitors: [
          {
            homeAway: "home",
            score: "3",
            team: { displayName: "Seattle Mariners", abbreviation: "SEA", shortDisplayName: "Mariners" },
          },
          {
            homeAway: "away",
            score: "5",
            team: { displayName: "Houston Astros", abbreviation: "HOU", shortDisplayName: "Astros" },
          },
        ],
      }],
    }],
  });
  const event = matchEvent(events, parsed!.home, parsed!.away);
  assertEquals(event?.isFinal, true);
  assertEquals(gradeMoneyline(event!, "HOU"), "won");
  assertEquals(gradeMoneyline(event!, "Houston Astros"), "won");
  assertEquals(gradeMoneyline(event!, "SEA"), "lost");
});

Deno.test("NHL shots map without requiring the word goal", () => {
  const players = parseBoxPlayers({
    boxscore: {
      players: [{
        statistics: [{
          name: "skaters",
          names: ["G", "A", "SOG"],
          athletes: [{
            athlete: { displayName: "Auston Matthews" },
            stats: ["1", "0", "6"],
          }],
        }],
      }],
    },
  });
  assertEquals(
    actualForProp({ description: "Shots", player: "Auston Matthews", players }),
    6,
  );
  assertEquals(espnPath("icehockey_nhl"), "hockey/nhl");
  assertEquals(espnPath("MLB"), "baseball/mlb");
});
