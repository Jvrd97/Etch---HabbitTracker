// [review:need-review] PHASE-01/27-streak-mode-endpoint, PHASE-01/28-today-avoid-card
// summary: unit tests for streak label helpers (day pluralization, last relapse date, clean badge)

import { describe, expect, it } from 'bun:test';
import { formatCleanDays, formatDays, formatLastRelapse } from './streak-format';

describe('formatDays', () => {
  it('uses the singular form for exactly one day', () => {
    expect(formatDays(1)).toBe('1 day');
  });

  it('uses the plural form for zero and many days', () => {
    expect(formatDays(0)).toBe('0 days');
    expect(formatDays(42)).toBe('42 days');
  });
});

describe('formatCleanDays', () => {
  it('appends the clean label with the correct day form', () => {
    expect(formatCleanDays(0)).toBe('0 days clean');
    expect(formatCleanDays(1)).toBe('1 day clean');
    expect(formatCleanDays(42)).toBe('42 days clean');
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
