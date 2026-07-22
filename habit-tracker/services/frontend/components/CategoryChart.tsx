'use client';
// [review:need-review] PHASE-01/21-chart-cumulative-mode
// summary: multi-line category chart - added Per day | Cumulative mode toggle (prefix sums via cumulate), mode survives period changes

import { useMemo, useState } from 'react';
import {
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { Category, TableDay } from '@/lib/api';
import {
  CHART_PERIODS,
  ChartPeriod,
  ChartSeries,
  PERIOD_LABELS,
  buildChartData,
  buildSeries,
  sliceByPeriod,
} from '@/lib/chart-data';
import { cumulate } from '@/lib/chart-utils';

type ChartMode = 'perDay' | 'cumulative';

const CHART_MODES: readonly ChartMode[] = ['perDay', 'cumulative'];

const MODE_LABELS: Record<ChartMode, string> = {
  perDay: 'Per day',
  cumulative: 'Cumulative',
};

const CHART_HEIGHT_PX = 360;
const DEFAULT_PERIOD: ChartPeriod = '30d';
const GRID_COLOR = 'rgba(255, 255, 255, 0.06)';
const AXIS_TICK_COLOR = '#8a8a8a';
const TOOLTIP_STYLE: React.CSSProperties = {
  backgroundColor: '#141414',
  border: '1px solid rgba(255, 255, 255, 0.1)',
  borderRadius: '12px',
  color: '#f5f5f5',
};

interface CategoryChartProps {
  category: Category;
  days: TableDay[];
}

export default function CategoryChart({ category, days }: CategoryChartProps) {
  const [period, setPeriod] = useState<ChartPeriod>(DEFAULT_PERIOD);
  const [mode, setMode] = useState<ChartMode>('perDay');
  const [hiddenKeys, setHiddenKeys] = useState<readonly string[]>([]);

  const series = useMemo(() => buildSeries(category.fields), [category.fields]);
  const data = useMemo(() => {
    const sliced = sliceByPeriod(
      buildChartData(days, category.id, category.fields),
      period
    );
    return mode === 'cumulative' ? cumulate(sliced) : sliced;
  }, [days, category.id, category.fields, period, mode]);

  const toggleSeries = (key: string) => {
    setHiddenKeys((prev) =>
      prev.includes(key) ? prev.filter((k) => k !== key) : [...prev, key]
    );
  };

  if (series.length === 0) {
    return (
      <div className="text-center py-16 bg-card border border-white/5 rounded-3xl">
        <p className="text-text-secondary">
          No number or time fields to chart in this category
        </p>
      </div>
    );
  }

  const leftUnit = series.find((s) => s.axis === 'left')?.unit ?? '';
  const rightSeries = series.find((s) => s.axis === 'right');
  const seriesByKey = new Map<string, ChartSeries>(series.map((s) => [s.key, s]));

  return (
    <div className="bg-card border border-white/5 rounded-3xl p-6 space-y-5">
      <div
        className="flex flex-wrap gap-2"
        role="group"
        aria-label="Chart period"
      >
        {CHART_PERIODS.map((p) => (
          <button
            key={p}
            onClick={() => setPeriod(p)}
            aria-pressed={p === period}
            className={`px-4 py-2 rounded-full text-sm font-medium transition-all duration-200 border ${
              p === period
                ? 'bg-lime text-background border-lime shadow-[0_0_18px_rgba(184,255,54,0.25)]'
                : 'bg-surface text-text-secondary border-white/10 hover:text-text-primary hover:bg-white/5'
            }`}
          >
            {PERIOD_LABELS[p]}
          </button>
        ))}
      </div>

      <div className="flex flex-wrap gap-2" role="group" aria-label="Chart mode">
        {CHART_MODES.map((m) => (
          <button
            key={m}
            onClick={() => setMode(m)}
            aria-pressed={m === mode}
            className={`px-4 py-2 rounded-full text-sm font-medium transition-all duration-200 border ${
              m === mode
                ? 'bg-lime text-background border-lime shadow-[0_0_18px_rgba(184,255,54,0.25)]'
                : 'bg-surface text-text-secondary border-white/10 hover:text-text-primary hover:bg-white/5'
            }`}
          >
            {MODE_LABELS[m]}
          </button>
        ))}
      </div>

      <div className="flex flex-wrap gap-2" role="group" aria-label="Series visibility">
        {series.map((s) => {
          const hidden = hiddenKeys.includes(s.key);
          return (
            <button
              key={s.key}
              onClick={() => toggleSeries(s.key)}
              aria-pressed={!hidden}
              className={`inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-sm border transition-all duration-200 ${
                hidden
                  ? 'bg-surface text-text-disabled border-white/5 line-through'
                  : 'bg-surface text-text-primary border-white/10'
              }`}
            >
              <span
                aria-hidden="true"
                className="w-2.5 h-2.5 rounded-full"
                style={{ backgroundColor: hidden ? '#3a3a3a' : s.color }}
              />
              {s.name}
              <span className="text-text-disabled">{s.unit}</span>
            </button>
          );
        })}
      </div>

      <div style={{ height: CHART_HEIGHT_PX }}>
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={data} margin={{ top: 8, right: 8, bottom: 0, left: 0 }}>
            <CartesianGrid stroke={GRID_COLOR} vertical={false} />
            <XAxis
              dataKey="date"
              tick={{ fill: AXIS_TICK_COLOR, fontSize: 12 }}
              tickLine={false}
              axisLine={{ stroke: GRID_COLOR }}
              minTickGap={24}
            />
            <YAxis
              yAxisId="left"
              tick={{ fill: AXIS_TICK_COLOR, fontSize: 12 }}
              tickLine={false}
              axisLine={false}
              width={44}
              label={{
                value: leftUnit,
                position: 'insideTopLeft',
                offset: -8,
                fill: AXIS_TICK_COLOR,
                fontSize: 12,
              }}
            />
            {rightSeries && (
              <YAxis
                yAxisId="right"
                orientation="right"
                tick={{ fill: AXIS_TICK_COLOR, fontSize: 12 }}
                tickLine={false}
                axisLine={false}
                width={44}
                label={{
                  value: rightSeries.unit,
                  position: 'insideTopRight',
                  offset: -8,
                  fill: AXIS_TICK_COLOR,
                  fontSize: 12,
                }}
              />
            )}
            <Tooltip
              contentStyle={TOOLTIP_STYLE}
              formatter={(value, name) => {
                const s = typeof name === 'string' ? seriesByKey.get(name) : undefined;
                const label = s?.name ?? name;
                const unit = s?.unit ?? '';
                return [`${value} ${unit}`.trim(), label];
              }}
              labelStyle={{ color: '#8a8a8a' }}
            />
            {series.map((s) => (
              <Line
                key={s.key}
                yAxisId={s.axis}
                type="monotone"
                dataKey={s.key}
                name={s.key}
                stroke={s.color}
                strokeWidth={2}
                dot={false}
                activeDot={{ r: 4, strokeWidth: 2, stroke: '#1a1a1a' }}
                connectNulls
                hide={hiddenKeys.includes(s.key)}
              />
            ))}
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
