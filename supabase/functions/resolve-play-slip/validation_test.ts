import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { validateLegs } from "./validation.ts";

const firstLeg = "11111111-1111-4111-8111-111111111111";

Deno.test("validateLegs accepts bounded, finite odds inputs", () => {
  assertEquals(
    validateLegs([{
      legId: firstLeg,
      choiceLabel: "Over",
      oddsDecimalAtSubmit: 2,
    }]),
    [{
      legId: firstLeg,
      choiceLabel: "Over",
      oddsDecimalAtSubmit: 2,
    }],
  );
});

Deno.test("validateLegs rejects duplicate, invalid, and unbounded legs", () => {
  assertEquals(validateLegs([
    { legId: firstLeg, choiceLabel: "Over", oddsDecimalAtSubmit: 2 },
    { legId: firstLeg, choiceLabel: "Under", oddsDecimalAtSubmit: 2 },
  ]), null);
  assertEquals(validateLegs([
    { legId: firstLeg, choiceLabel: "Over", oddsDecimalAtSubmit: Number.NaN },
  ]), null);
  assertEquals(validateLegs([
    { legId: firstLeg, choiceLabel: "Over", oddsDecimalAtSubmit: 1 },
  ]), null);
});
