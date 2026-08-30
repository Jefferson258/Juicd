export type ResolveLeg = {
  legId: string;
  choiceLabel: string;
  oddsDecimalAtSubmit: number;
};

export function isUuid(value: unknown): value is string {
  return typeof value === "string"
    && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

export function validateLegs(value: unknown): ResolveLeg[] | null {
  if (!Array.isArray(value) || value.length === 0 || value.length > 8) return null;

  const seenLegIds = new Set<string>();
  const validated: ResolveLeg[] = [];
  for (const candidate of value) {
    if (!candidate || typeof candidate !== "object") return null;
    const leg = candidate as Record<string, unknown>;
    const legId = leg.legId;
    const choiceLabel = leg.choiceLabel;
    const odds = leg.oddsDecimalAtSubmit;
    if (!isUuid(legId)
      || seenLegIds.has(legId.toLowerCase())
      || typeof choiceLabel !== "string"
      || choiceLabel.trim().length === 0
      || choiceLabel.length > 256
      || typeof odds !== "number"
      || !Number.isFinite(odds)
      || odds <= 1
      || odds > 1000) {
      return null;
    }
    seenLegIds.add(legId.toLowerCase());
    validated.push({ legId, choiceLabel, oddsDecimalAtSubmit: odds });
  }
  return validated;
}
