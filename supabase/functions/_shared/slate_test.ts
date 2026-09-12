import { slateKey, eventOnSlate, nflWeekKey, nextSlateKey, calendarWeekKey, nextCalendarWeekKey, isSundayEarlyWeeklyWindow } from "./slate.ts";
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

function chicago(year: number, month: number, day: number, hour: number, minute = 0): Date {
  // Build an instant whose America/Chicago wall time matches the args.
  for (const utcHour of [hour + 5, hour + 6, hour + 4]) {
    const d = new Date(Date.UTC(year, month - 1, day, utcHour, minute, 0));
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone: "America/Chicago",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    }).formatToParts(d);
    const map: Record<string, string> = {};
    for (const p of parts) if (p.type !== "literal") map[p.type] = p.value;
    if (
      Number(map.year) === year &&
      Number(map.month) === month &&
      Number(map.day) === day &&
      Number(map.hour) === hour &&
      Number(map.minute) === minute
    ) {
      return d;
    }
  }
  throw new Error("could not build chicago instant");
}

Deno.test("1am CT Aug 28 is Aug 27 slate", () => {
  const t = chicago(2026, 8, 28, 1, 0);
  assertEquals(slateKey(t), "2026-08-27");
});

Deno.test("4am CT Aug 28 is Aug 28 slate", () => {
  const t = chicago(2026, 8, 28, 4, 0);
  assertEquals(slateKey(t), "2026-08-28");
});

Deno.test("eventOnSlate uses commence, not now", () => {
  const commence = chicago(2026, 8, 28, 1, 0).toISOString();
  assertEquals(eventOnSlate(commence, "2026-08-27"), true);
  assertEquals(eventOnSlate(commence, "2026-08-28"), false);
});

Deno.test("weekly key is Monday of that Juicd week", () => {
  const friday = chicago(2026, 9, 11, 13, 0);
  assertEquals(calendarWeekKey(friday), "2026-09-07");
  assertEquals(nflWeekKey(friday), "2026-09-07");
});

Deno.test("next slate is the following 4am CT day", () => {
  const fridayNight = chicago(2026, 9, 11, 22, 0);
  assertEquals(slateKey(fridayNight), "2026-09-11");
  assertEquals(nextSlateKey(fridayNight), "2026-09-12");
});

Deno.test("Sunday is early-entry for next Monday week", () => {
  const sunday = chicago(2026, 9, 13, 16, 0);
  assertEquals(isSundayEarlyWeeklyWindow(sunday), true);
  assertEquals(calendarWeekKey(sunday), "2026-09-07");
  assertEquals(nextCalendarWeekKey(sunday), "2026-09-14");
  assertEquals(isSundayEarlyWeeklyWindow(chicago(2026, 9, 11, 22, 0)), false);
});
