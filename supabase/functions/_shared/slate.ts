/** Juicd day: America/Chicago, rolls at 04:00. A 1:00 CT Aug 28 game is the Aug 27 slate. */

export const JUICD_TZ = "America/Chicago";
export const SLATE_HOUR = 4;
export const MAX_ODDS_CREDITS_PER_DAY = 16;

type ZoneParts = { year: number; month: number; day: number; hour: number; minute: number };

function zoneParts(date: Date, timeZone = JUICD_TZ): ZoneParts {
  const fmt = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  });
  const map: Record<string, string> = {};
  for (const part of fmt.formatToParts(date)) {
    if (part.type !== "literal") map[part.type] = part.value;
  }
  return {
    year: Number(map.year),
    month: Number(map.month),
    day: Number(map.day),
    hour: Number(map.hour),
    minute: Number(map.minute),
  };
}

function pad2(n: number): string {
  return String(n).padStart(2, "0");
}

export function ymd(parts: { year: number; month: number; day: number }): string {
  return `${parts.year}-${pad2(parts.month)}-${pad2(parts.day)}`;
}

function addDays(parts: { year: number; month: number; day: number }, days: number): {
  year: number;
  month: number;
  day: number;
} {
  const utc = new Date(Date.UTC(parts.year, parts.month - 1, parts.day + days));
  return { year: utc.getUTCFullYear(), month: utc.getUTCMonth() + 1, day: utc.getUTCDate() };
}

/** Slate key for an instant (game start or "now"). */
export function slateKey(date: Date = new Date()): string {
  const parts = zoneParts(date);
  if (parts.hour < SLATE_HOUR) {
    return ymd(addDays(parts, -1));
  }
  return ymd(parts);
}

export function eventOnSlate(commenceIso: string | null | undefined, currentSlate: string): boolean {
  if (!commenceIso) return false;
  const t = Date.parse(commenceIso);
  if (Number.isNaN(t)) return false;
  return slateKey(new Date(t)) === currentSlate;
}

export function eventNotStarted(commenceIso: string | null | undefined, now: Date = new Date()): boolean {
  if (!commenceIso) return false;
  const t = Date.parse(commenceIso);
  if (Number.isNaN(t)) return false;
  return t > now.getTime();
}

/** Seconds from `now` until the next 4:00 CT. */
export function secondsUntilNextSlate(now: Date = new Date()): number {
  const parts = zoneParts(now);
  const startToday = parts.hour < SLATE_HOUR ? 0 : 1;
  const next = addDays(parts, startToday);
  // Approximate next 4am CT via ISO in Chicago offset from a probe.
  const guess = new Date(now.getTime() + 60_000);
  for (let i = 0; i < 36 * 60; i++) {
    const p = zoneParts(guess);
    if (ymd(p) === ymd(next) && p.hour === SLATE_HOUR && p.minute === 0) {
      return Math.max(60, Math.floor((guess.getTime() - now.getTime()) / 1000));
    }
    guess.setTime(guess.getTime() + 60_000);
  }
  return 12 * 3600;
}

export function freezeAtIso(commenceIso: string): string {
  const t = Date.parse(commenceIso);
  return new Date(t - 60 * 60 * 1000).toISOString();
}

export function previousSlateKey(date: Date = new Date()): string {
  const key = slateKey(date);
  const [y, m, d] = key.split("-").map(Number);
  return ymd(addDays({ year: y, month: m, day: d }, -1));
}

export function nextSlateKey(date: Date = new Date()): string {
  const key = slateKey(date);
  const [y, m, d] = key.split("-").map(Number);
  return ymd(addDays({ year: y, month: m, day: d }, 1));
}

/**
 * Juicd weekly: Monday 4:00am CT through Sunday night (next Monday 4:00am).
 * The key is that Monday's slate date. Sunday is still this week; next week
 * opens for early entry on Sunday.
 */
export function calendarWeekKey(date: Date = new Date()): string {
  const key = slateKey(date);
  const [y, m, d] = key.split("-").map(Number);
  const noon = chicagoNoon(y, m, d);
  const dow = zoneWeekday(noon); // 0 Sun … 1 Mon … 6 Sat
  const daysFromMonday = (dow + 6) % 7; // Mon=0 … Sun=6
  const mon = addDays({ year: y, month: m, day: d }, -daysFromMonday);
  return ymd(mon);
}

export function nextCalendarWeekKey(date: Date = new Date()): string {
  const key = calendarWeekKey(date);
  const [y, m, d] = key.split("-").map(Number);
  return ymd(addDays({ year: y, month: m, day: d }, 7));
}

export function isSundayEarlyWeeklyWindow(date: Date = new Date()): boolean {
  const key = slateKey(date);
  const [y, m, d] = key.split("-").map(Number);
  return zoneWeekday(chicagoNoon(y, m, d)) === 0;
}

/** @deprecated alias — weekly is Monday–Sunday, not Thursday NFL week. */
export function nflWeekKey(date: Date = new Date()): string {
  return calendarWeekKey(date);
}

function chicagoNoon(year: number, month: number, day: number): Date {
  // 12:00 CT is 17:00 or 18:00 UTC; probe both.
  for (const utcHour of [17, 18, 16, 19]) {
    const d = new Date(Date.UTC(year, month - 1, day, utcHour, 0, 0));
    const p = zoneParts(d);
    if (p.year === year && p.month === month && p.day === day && p.hour === 12) return d;
  }
  return new Date(Date.UTC(year, month - 1, day, 17, 0, 0));
}

function zoneWeekday(date: Date): number {
  const fmt = new Intl.DateTimeFormat("en-US", { timeZone: JUICD_TZ, weekday: "short" });
  const map: Record<string, number> = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 };
  return map[fmt.format(date)] ?? 0;
}

export function inNflWeek(commenceIso: string, weekKey: string): boolean {
  const t = Date.parse(commenceIso);
  if (Number.isNaN(t)) return false;
  return calendarWeekKey(new Date(t)) === weekKey;
}
