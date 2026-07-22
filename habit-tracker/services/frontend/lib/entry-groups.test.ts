// [review:need-review] PHASE-01/22-category-page-entries-cards
// summary: unit tests for groupEntriesByDate (order preservation, grouping, empty input)

import { describe, expect, it } from 'bun:test';
import type { Entry } from './api';
import { groupEntriesByDate } from './entry-groups';

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

describe('groupEntriesByDate', () => {
  it('returns empty array for no entries', () => {
    expect(groupEntriesByDate([])).toEqual([]);
  });

  it('groups entries by entry_date preserving first-seen date order', () => {
    const entries = [
      makeEntry(1, '2026-07-20'),
      makeEntry(2, '2026-07-19'),
      makeEntry(3, '2026-07-20'),
    ];
    const grouped = groupEntriesByDate(entries);
    expect(grouped.map(([date]) => date)).toEqual(['2026-07-20', '2026-07-19']);
    expect(grouped[0][1].map((e) => e.id)).toEqual([1, 3]);
    expect(grouped[1][1].map((e) => e.id)).toEqual([2]);
  });
});
