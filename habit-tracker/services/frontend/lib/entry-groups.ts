// [review:need-review] PHASE-01/22-category-page-entries-cards
// summary: pure helper groupEntriesByDate extracted from app/entries/page.tsx for reuse on the category page

import type { Entry } from './api';

/** Group entries by entry_date, preserving first-seen date order and entry order within a date. */
export function groupEntriesByDate(entries: Entry[]): Array<[string, Entry[]]> {
  const groups = new Map<string, Entry[]>();
  for (const entry of entries) {
    const existing = groups.get(entry.entry_date);
    if (existing) {
      existing.push(entry);
    } else {
      groups.set(entry.entry_date, [entry]);
    }
  }
  return Array.from(groups.entries());
}
