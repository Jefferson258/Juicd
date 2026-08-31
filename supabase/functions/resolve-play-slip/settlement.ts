/** Pure virtual-point settlement math. Keep in sync with
 * `supabase/staging/AUTHORITATIVE_SETTLEMENT.sql`. Production must not import
 * this into a live migration. */

export type SettlementOutcome = { legId: string; didWin: boolean };

export function parlayDidWin(outcomes: SettlementOutcome[]): boolean {
  return outcomes.length > 0 && outcomes.every((row) => row.didWin === true);
}

/** Wallet credit on a win. Matches InMemoryJuicdRepository: stake 25 at 2.0 → 50. */
export function payoutPoints(stakePoints: number, combinedOdds: number): number {
  if (!Number.isInteger(stakePoints) || stakePoints <= 0) return 0;
  if (!Number.isFinite(combinedOdds) || combinedOdds <= 1) return 0;
  return Math.floor(stakePoints * combinedOdds);
}

export function seasonPointsOnWin(stakePoints: number, didWin: boolean): number {
  if (!didWin) return 0;
  if (!Number.isInteger(stakePoints) || stakePoints <= 0) return 0;
  return stakePoints;
}

export function ledgerDeltas(
  stakePoints: number,
  combinedOdds: number,
  didWin: boolean,
): { debit: number; credit: number } {
  const debit = (!Number.isInteger(stakePoints) || stakePoints <= 0) ? 0 : -stakePoints;
  const credit = didWin ? payoutPoints(stakePoints, combinedOdds) : 0;
  return { debit, credit };
}
