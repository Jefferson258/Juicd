import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  ledgerDeltas,
  parlayDidWin,
  payoutPoints,
  seasonPointsOnWin,
} from "./settlement.ts";

Deno.test("parlay wins only when every leg wins", () => {
  assertEquals(parlayDidWin([]), false);
  assertEquals(parlayDidWin([{ legId: "a", didWin: true }]), true);
  assertEquals(
    parlayDidWin([
      { legId: "a", didWin: true },
      { legId: "b", didWin: false },
    ]),
    false,
  );
});

Deno.test("payout matches local repository: 25 at 2.0 credits 50", () => {
  assertEquals(payoutPoints(25, 2), 50);
  assertEquals(payoutPoints(25, 2.9), 72);
  assertEquals(payoutPoints(0, 2), 0);
  assertEquals(payoutPoints(25, 1), 0);
});

Deno.test("ledger is stake debit then optional payout credit", () => {
  assertEquals(ledgerDeltas(25, 2, true), { debit: -25, credit: 50 });
  assertEquals(ledgerDeltas(25, 2, false), { debit: -25, credit: 0 });
  assertEquals(seasonPointsOnWin(25, true), 25);
  assertEquals(seasonPointsOnWin(25, false), 0);
});
