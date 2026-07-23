// [review:need-review] PHASE-01/27-streak-mode-endpoint
// summary: unit tests for streak label helpers (day pluralization, last relapse date)

import { describe, expect, it } from 'bun:test';
import { formatDays, formatLastRelapse } from './streak-format';

describe('formatDays', () => {
  it('uses the singular form for exactly one day', () => {
    expect(formatDays(1)).toBe('1 day');
  });

  it('uses the plural form for zero and many days', () => {
    expect(formatDays(0)).toBe('0 days');
    expect(formatDays(42)).toBe('42 days');
  });
});

describe('formatLastRelapse', () => {
  it('reports never when there was no relapse', () => {
    expect(formatLastRelapse(null)).toBe('never');
  });

  it('renders the ISO date as a readable day', () => {
    expect(formatLastRelapse('2026-03-05')).toBe('5 Mar 2026');
  });
});
