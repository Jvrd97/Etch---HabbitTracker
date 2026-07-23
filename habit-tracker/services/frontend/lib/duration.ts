// [review:need-review] PHASE-01/34-duration-field-type
// summary: pure helpers converting between elapsed seconds and human h:m text

const SECONDS_PER_MINUTE = 60;
const SECONDS_PER_HOUR = 3600;
const MINUTES_PER_HOUR = 60;

/**
 * Parse a user-typed duration into whole seconds, or null when it is empty or
 * malformed. Accepted forms:
 *   "1:20" / "01:20"  -> hours:minutes (minutes 0-59)  -> 4800
 *   "45"              -> bare minutes                   -> 2700
 * Negative parts, minutes >= 60, and non-numeric text all yield null so the
 * caller can refuse to store garbage.
 */
export function parseDurationToSeconds(input: string): number | null {
  const trimmed = input.trim();
  if (trimmed === '') return null;

  if (trimmed.includes(':')) {
    const parts = trimmed.split(':');
    if (parts.length !== 2) return null;
    const [hoursRaw, minutesRaw] = parts;
    if (!/^\d+$/.test(hoursRaw) || !/^\d+$/.test(minutesRaw)) return null;
    const hours = Number(hoursRaw);
    const minutes = Number(minutesRaw);
    if (minutes >= MINUTES_PER_HOUR) return null;
    return hours * SECONDS_PER_HOUR + minutes * SECONDS_PER_MINUTE;
  }

  if (!/^\d+$/.test(trimmed)) return null;
  return Number(trimmed) * SECONDS_PER_MINUTE;
}

/** Compact human label for a duration in seconds: "1h 20m", "45m", "2h", "0m". */
export function formatSecondsToHM(seconds: number): string {
  const total = Math.max(0, Math.round(seconds));
  const hours = Math.floor(total / SECONDS_PER_HOUR);
  const minutes = Math.floor((total % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE);
  if (hours === 0) return `${minutes}m`;
  if (minutes === 0) return `${hours}h`;
  return `${hours}h ${minutes}m`;
}

/** Duration in seconds as an editable "H:MM" string for the input field. */
export function secondsToInputValue(seconds: number): string {
  const total = Math.max(0, Math.round(seconds));
  const hours = Math.floor(total / SECONDS_PER_HOUR);
  const minutes = Math.floor((total % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE);
  return `${hours}:${String(minutes).padStart(2, '0')}`;
}
