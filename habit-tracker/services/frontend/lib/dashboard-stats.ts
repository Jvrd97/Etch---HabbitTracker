// [review:need-review] PHASE-01/10-ios-dashboard
// summary: pure dashboard aggregation — real entries total + recent-activity feed (date desc, id desc, capped); parity with iOS DashboardViewModel.aggregate

import type { Entry } from './api';

/** How many entries the recent-activity feed surfaces (parity with the iOS dashboard). */
export const RECENT_ENTRIES_LIMIT = 5;

export interface DashboardStats {
  categoriesCount: number;
  entriesCount: number;
  journalCount: number;
  recentEntries: Entry[];
}

/**
 * Pure aggregation of the fetched dashboard data.
 *
 * `entriesCount` is the real length of the entries list (not a limit-capped
 * slice), matching the iOS dashboard. The recent-activity feed is newest first
 * (entry_date desc, id desc on ties) and capped at {@link RECENT_ENTRIES_LIMIT};
 * the explicit sort makes the feed order identical to iOS regardless of the
 * backend tie order.
 */
export function computeDashboardStats(
  categoriesCount: number,
  entries: Entry[],
  journalTotal: number,
): DashboardStats {
  const recentEntries = [...entries]
    .sort((a, b) => {
      if (a.entry_date !== b.entry_date) {
        return a.entry_date < b.entry_date ? 1 : -1;
      }
      return b.id - a.id;
    })
    .slice(0, RECENT_ENTRIES_LIMIT);

  return {
    categoriesCount,
    entriesCount: entries.length,
    journalCount: journalTotal,
    recentEntries,
  };
}
