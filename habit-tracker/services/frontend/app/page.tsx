'use client';
// [review:need-review] PHASE-01/adhoc-lime-redesign
// summary: Dashboard restyled as Lime Tech hero score card, KPI row, recent activity and quick actions

import { useEffect, useState } from 'react';
import { categoriesAPI, entriesAPI, journalAPI, Entry } from '@/lib/api';
import LoadingSpinner from '@/components/LoadingSpinner';
import ErrorAlert from '@/components/ErrorAlert';
import {
  BarChart3,
  Calendar,
  BookText,
  ArrowRight,
  Plus,
  PenLine,
  FolderPlus,
} from 'lucide-react';
import Link from 'next/link';

const RING_SIZE = 148;
const RING_STROKE = 8;
const RING_TARGET_ENTRIES = 10;

function ProgressRing({ progress }: { progress: number }) {
  const radius = (RING_SIZE - RING_STROKE) / 2;
  const circumference = 2 * Math.PI * radius;
  const offset = circumference * (1 - Math.min(Math.max(progress, 0), 1));

  return (
    <svg
      width={RING_SIZE}
      height={RING_SIZE}
      viewBox={`0 0 ${RING_SIZE} ${RING_SIZE}`}
      className="-rotate-90"
      aria-hidden="true"
    >
      <circle
        cx={RING_SIZE / 2}
        cy={RING_SIZE / 2}
        r={radius}
        fill="none"
        stroke="rgba(255,255,255,0.06)"
        strokeWidth={RING_STROKE}
      />
      <circle
        cx={RING_SIZE / 2}
        cy={RING_SIZE / 2}
        r={radius}
        fill="none"
        stroke="#B8FF36"
        strokeWidth={RING_STROKE}
        strokeLinecap="round"
        strokeDasharray={circumference}
        strokeDashoffset={offset}
        className="animate-ring-draw drop-shadow-[0_0_8px_rgba(184,255,54,0.45)]"
        style={{ '--ring-circumference': circumference } as React.CSSProperties}
      />
    </svg>
  );
}

export default function Dashboard() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [stats, setStats] = useState({
    categoriesCount: 0,
    entriesCount: 0,
    journalCount: 0,
    recentEntries: [] as Entry[],
  });

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    try {
      setLoading(true);
      setError(null);

      const [categories, entries, journal] = await Promise.all([
        categoriesAPI.getAll(),
        entriesAPI.getAll({ limit: 5 }),
        journalAPI.getAll({ limit: 5 }),
      ]);

      setStats({
        categoriesCount: categories.length,
        entriesCount: entries.length,
        journalCount: journal.total,
        recentEntries: entries,
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load dashboard data');
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <LoadingSpinner size="lg" />;
  if (error) return <ErrorAlert message={error} onDismiss={() => setError(null)} />;

  const ringProgress = stats.entriesCount / RING_TARGET_ENTRIES;

  const kpis = [
    {
      label: 'Categories',
      value: stats.categoriesCount,
      href: '/categories',
      icon: BarChart3,
    },
    {
      label: 'Entries',
      value: stats.entriesCount,
      href: '/entries',
      icon: Calendar,
    },
    {
      label: 'Journal',
      value: stats.journalCount,
      href: '/journal',
      icon: BookText,
    },
  ];

  const quickActions = [
    { label: 'Add category', href: '/categories?action=new', icon: FolderPlus },
    { label: 'Log entry', href: '/entries?action=new', icon: Plus },
    { label: 'Write journal', href: '/journal?action=new', icon: PenLine },
  ];

  return (
    <div className="space-y-8 animate-fade-rise">
      <div>
        <h1 className="text-4xl font-bold text-text-primary tracking-tight">
          Dashboard
          <span className="text-lime">.</span>
        </h1>
        <p className="mt-2 text-text-secondary">Track your progress and stay motivated.</p>
      </div>

      {/* Hero score card */}
      <div className="bg-card border border-white/5 rounded-3xl p-8 flex flex-col sm:flex-row items-center gap-8">
        <div className="relative flex-shrink-0">
          <ProgressRing progress={ringProgress} />
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <span className="text-4xl font-bold text-text-primary leading-none">
              {stats.entriesCount}
            </span>
            <span className="text-[13px] font-medium text-text-secondary mt-1">entries</span>
          </div>
        </div>
        <div className="flex-1 text-center sm:text-left">
          <p className="text-[13px] font-medium uppercase tracking-widest text-lime">
            All good, keep going
          </p>
          <h2 className="text-[22px] font-semibold text-text-primary mt-2">
            Your recent tracking activity
          </h2>
          <p className="text-text-secondary mt-2 text-base">
            {stats.categoriesCount} categories, {stats.journalCount} journal notes. Log something
            today to keep the streak alive.
          </p>
          <Link
            href="/entries?action=new"
            className="inline-flex items-center gap-2 mt-5 px-6 py-3 bg-lime text-background rounded-3xl font-medium transition-all duration-200 hover:-translate-y-0.5 hover:shadow-[0_0_24px_rgba(184,255,54,0.35)]"
          >
            <Plus className="w-4 h-4" strokeWidth={2} />
            Log entry
          </Link>
        </div>
      </div>

      {/* KPI row */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
        {kpis.map(({ label, value, href, icon: Icon }) => (
          <Link
            key={label}
            href={href}
            className="group bg-card border border-white/5 rounded-3xl p-6 transition-all duration-200 hover:-translate-y-0.5 hover:shadow-[0_10px_30px_rgba(0,0,0,0.5)]"
          >
            <div className="flex items-center justify-between">
              <div>
                <p className="text-[13px] font-medium text-text-secondary">{label}</p>
                <p className="text-4xl font-bold text-text-primary mt-2">{value}</p>
              </div>
              <div className="p-3 rounded-2xl bg-lime/10 transition-colors duration-200 group-hover:bg-lime/20">
                <Icon className="w-6 h-6 text-lime" strokeWidth={2} />
              </div>
            </div>
          </Link>
        ))}
      </div>

      {/* Recent activity */}
      <div className="bg-card border border-white/5 rounded-3xl overflow-hidden">
        <div className="px-6 py-5 border-b border-white/5 flex items-center justify-between">
          <h2 className="text-[22px] font-semibold text-text-primary">Recent activity</h2>
          <Link
            href="/entries"
            className="text-sm font-medium text-text-secondary hover:text-lime transition-colors duration-200 inline-flex items-center gap-1"
          >
            View all
            <ArrowRight className="w-4 h-4" strokeWidth={2} />
          </Link>
        </div>
        <div className="px-6 py-4">
          {stats.recentEntries.length === 0 ? (
            <div className="text-center py-14">
              <div className="inline-flex p-4 rounded-3xl bg-surface mb-4">
                <Calendar className="w-8 h-8 text-text-disabled" strokeWidth={2} />
              </div>
              <p className="text-text-secondary">Nothing here yet</p>
              <Link
                href="/entries?action=new"
                className="mt-5 inline-flex items-center gap-2 px-6 py-3 bg-lime text-background rounded-3xl font-medium transition-all duration-200 hover:-translate-y-0.5 hover:shadow-[0_0_24px_rgba(184,255,54,0.35)]"
              >
                Create first entry
              </Link>
            </div>
          ) : (
            <div className="divide-y divide-white/5">
              {stats.recentEntries.map((entry) => (
                <div key={entry.id} className="flex items-center justify-between py-4">
                  <div className="flex items-center gap-4 min-w-0">
                    <div className="p-2.5 rounded-2xl bg-surface flex-shrink-0">
                      <Calendar className="w-4 h-4 text-lime" strokeWidth={2} />
                    </div>
                    <div className="min-w-0">
                      <p className="text-base font-medium text-text-primary">
                        Entry #{entry.id}
                      </p>
                      <p className="text-[13px] text-text-secondary mt-0.5">{entry.entry_date}</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-4 flex-shrink-0">
                    <span className="text-[13px] text-text-disabled">
                      {entry.values.length} values
                    </span>
                    <Link
                      href={`/entries/${entry.id}`}
                      className="text-sm font-medium text-lime hover:text-green-secondary transition-colors duration-200"
                    >
                      View
                    </Link>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Quick actions */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
        {quickActions.map(({ label, href, icon: Icon }) => (
          <Link
            key={label}
            href={href}
            className="group bg-surface border border-white/5 rounded-3xl p-6 flex items-center gap-4 transition-all duration-200 hover:-translate-y-0.5 hover:border-lime/30 hover:shadow-[0_10px_30px_rgba(0,0,0,0.5)]"
          >
            <div className="p-3 rounded-2xl bg-lime text-background transition-transform duration-200 group-hover:scale-105">
              <Icon className="w-5 h-5" strokeWidth={2} />
            </div>
            <span className="text-lg font-medium text-text-primary">{label}</span>
          </Link>
        ))}
      </div>
    </div>
  );
}
