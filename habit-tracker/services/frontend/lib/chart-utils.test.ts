// [review:need-review] PHASE-01/21-chart-cumulative-mode
// summary: unit tests for cumulate() - running sums per series, empty input, day gaps, multiple independent lines

import { describe, expect, it } from 'bun:test';
import type { ChartPoint } from './chart-data';
import { cumulate } from './chart-utils';

describe('cumulate', () => {
  it('returns an empty array for an empty series', () => {
    expect(cumulate([])).toEqual([]);
  });

  it('produces a monotonically non-decreasing running sum for one line', () => {
    const points: ChartPoint[] = [
      { date: '2026-07-01', f1: 2 },
      { date: '2026-07-02', f1: 3 },
      { date: '2026-07-03', f1: 1 },
    ];
    expect(cumulate(points)).toEqual([
      { date: '2026-07-01', f1: 2 },
      { date: '2026-07-02', f1: 5 },
      { date: '2026-07-03', f1: 6 },
    ]);
  });

  it('keeps null gaps as null without breaking the running total', () => {
    const points: ChartPoint[] = [
      { date: '2026-07-01', f1: null },
      { date: '2026-07-02', f1: 4 },
      { date: '2026-07-03', f1: null },
      { date: '2026-07-04', f1: 6 },
    ];
    expect(cumulate(points)).toEqual([
      { date: '2026-07-01', f1: null },
      { date: '2026-07-02', f1: 4 },
      { date: '2026-07-03', f1: null },
      { date: '2026-07-04', f1: 10 },
    ]);
  });

  it('accumulates multiple lines independently', () => {
    const points: ChartPoint[] = [
      { date: '2026-07-01', f1: 1, f2: 10 },
      { date: '2026-07-02', f1: 2, f2: null },
      { date: '2026-07-03', f1: 3, f2: 30 },
    ];
    expect(cumulate(points)).toEqual([
      { date: '2026-07-01', f1: 1, f2: 10 },
      { date: '2026-07-02', f1: 3, f2: null },
      { date: '2026-07-03', f1: 6, f2: 40 },
    ]);
  });

  it('does not mutate the input points', () => {
    const points: ChartPoint[] = [
      { date: '2026-07-01', f1: 2 },
      { date: '2026-07-02', f1: 3 },
    ];
    cumulate(points);
    expect(points[1].f1).toBe(3);
  });
});
