// [review:need-review] PHASE-01/27-streak-mode-endpoint, PHASE-01/28-today-avoid-card
// summary: pure label helpers for the avoid-streak block (day count, clean badge, last relapse date)

const RELAPSE_DATE_FORMAT: Intl.DateTimeFormatOptions = {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
};

/** Streak length with the correct English day form, e.g. "1 day" / "42 days". */
export function formatDays(days: number): string {
  return `${days} ${days === 1 ? 'day' : 'days'}`;
}

/** Avoid-streak badge text, e.g. "1 day clean" / "42 days clean". */
export function formatCleanDays(days: number): string {
  return `${formatDays(days)} clean`;
}

/**
 * Readable last-relapse day; "never" when the streak was never broken.
 * The ISO date is parsed as UTC so the rendered day never shifts by timezone.
 */
export function formatLastRelapse(isoDate: string | null): string {
  if (!isoDate) return 'never';
  const parsed = new Date(`${isoDate}T00:00:00Z`);
  if (Number.isNaN(parsed.getTime())) return isoDate;
  return new Intl.DateTimeFormat('en-GB', {
    ...RELAPSE_DATE_FORMAT,
    timeZone: 'UTC',
  }).format(parsed);
}
