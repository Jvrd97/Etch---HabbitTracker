// [review:need-review] PHASE-01/10-ios-dashboard
// summary: unit tests for computeDashboardStats — real entries total (not limit-capped) + recent feed (date desc, id desc, capped)

import { describe, expect, it } from 'bun:test';
import type { Entry } from './api';
import { computeDashboardStats, RECENT_ENTRIES_LIMIT } from './dashboard-stats';

function makeEntry(id: number, entryDate: string): Entry {
  return {
    id,
    category_id: 1,
    entry_date: entryDate,
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
    values: [],
  };
}

describe('computeDashboardStats', () => {
  it('counts the real entries total, not a limited slice (parity with iOS)', () => {
    const entries = Array.from({ length: 12 }, (_, i) => makeEntry(i + 1, '2026-07-20'));

    const stats = computeDashboardStats(3, entries, 7);

    expect(stats.categoriesCount).toBe(3);
    expect(stats.entriesCount).toBe(12);
    expect(stats.journalCount).toBe(7);
  });

  it('caps the recent feed at RECENT_ENTRIES_LIMIT, newest first (date desc, id desc on ties)', () => {
    const entries = [
      makeEntry(3, '2026-07-18'),
      makeEntry(6, '2026-07-21'),
      makeEntry(1, '2026-07-20'),
      makeEntry(2, '2026-07-20'),
      makeEntry(4, '2026-07-19'),
      makeEntry(5, '2026-07-17'),
    ];

    const stats = computeDashboardStats(0, entries, 0);

    expect(stats.recentEntries.map((e) => e.id)).toEqual([6, 2, 1, 4, 3]);
    expect(stats.recentEntries.length).toBe(RECENT_ENTRIES_LIMIT);
  });

  it('does not mutate the input entries array', () => {
    const entries = [makeEntry(1, '2026-07-18'), makeEntry(2, '2026-07-20')];
    const snapshot = entries.map((e) => e.id);

    computeDashboardStats(0, entries, 0);

    expect(entries.map((e) => e.id)).toEqual(snapshot);
  });

  it('handles an empty entries list', () => {
    const stats = computeDashboardStats(0, [], 0);
    expect(stats.entriesCount).toBe(0);
    expect(stats.recentEntries).toEqual([]);
  });
});
