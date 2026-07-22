// [review:need-review] PHASE-01/21-chart-cumulative-mode
// summary: cumulate() - prefix sums per series key over chart points; null gaps stay null and do not affect totals

import type { ChartPoint } from './chart-data';

/**
 * Running (prefix) sum for every series key, computed independently per line.
 * Null cells stay null (gap in the line) and leave the running total unchanged,
 * so the drawn curve is monotonically non-decreasing. Input is not mutated.
 */
export function cumulate(points: ChartPoint[]): ChartPoint[] {
  const totals = new Map<string, number>();
  return points.map((point) => {
    const out: ChartPoint = { date: point.date };
    for (const [key, value] of Object.entries(point)) {
      if (key === 'date') continue;
      if (typeof value !== 'number') {
        out[key] = value;
        continue;
      }
      const total = (totals.get(key) ?? 0) + value;
      totals.set(key, total);
      out[key] = total;
    }
    return out;
  });
}
