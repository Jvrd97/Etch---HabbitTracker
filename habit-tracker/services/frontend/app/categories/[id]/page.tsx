'use client';
// [review:need-review] PHASE-01/22-category-page-entries-cards
// summary: category detail page - chart plus full entry history as editable EntryCard list; mutations reload entries and chart data

import { useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { ArrowLeft, Calendar } from 'lucide-react';
import { Category, Entry, TableDay, categoriesAPI, entriesAPI, tableAPI } from '@/lib/api';
import { chartDateRange } from '@/lib/chart-data';
import { groupEntriesByDate } from '@/lib/entry-groups';
import CategoryChart from '@/components/CategoryChart';
import EntryCard from '@/components/EntryCard';
import ErrorAlert from '@/components/ErrorAlert';
import LoadingSpinner from '@/components/LoadingSpinner';

/** Full history without pagination (ticket #22: pagination is out of scope). */
const ENTRIES_FETCH_LIMIT = 1000;

export default function CategoryDetailPage() {
  const params = useParams<{ id: string }>();
  const categoryId = Number(params.id);

  const invalidId = !Number.isInteger(categoryId) || categoryId <= 0;

  const [category, setCategory] = useState<Category | null>(null);
  const [days, setDays] = useState<TableDay[] | null>(null);
  const [entries, setEntries] = useState<Entry[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [refreshCounter, setRefreshCounter] = useState(0);

  useEffect(() => {
    if (!Number.isInteger(categoryId) || categoryId <= 0) return;
    let cancelled = false;
    const load = async () => {
      try {
        const { from, to } = chartDateRange(new Date());
        const [categoryResult, tableResult, entriesResult] = await Promise.all([
          categoriesAPI.getById(categoryId),
          tableAPI.get(from, to),
          entriesAPI.getAll({ categoryId, limit: ENTRIES_FETCH_LIMIT }),
        ]);
        if (cancelled) return;
        setCategory(categoryResult);
        setDays(tableResult.days);
        setEntries(entriesResult);
      } catch (err) {
        if (!cancelled) {
          setLoadError(err instanceof Error ? err.message : 'Failed to load category');
        }
      }
    };
    load();
    return () => {
      cancelled = true;
    };
  }, [categoryId, refreshCounter]);

  const reload = useCallback(() => {
    setRefreshCounter((n) => n + 1);
  }, []);

  const loaded = category !== null && days !== null && entries !== null;

  return (
    <div className="space-y-8 animate-fade-rise">
      <div>
        <Link
          href="/categories"
          className="inline-flex items-center gap-2 text-sm text-text-secondary transition-colors duration-200 hover:text-lime"
        >
          <ArrowLeft className="w-4 h-4" strokeWidth={2} />
          Categories
        </Link>
        <h1 className="mt-3 text-4xl font-bold text-text-primary tracking-tight">
          {category?.name ?? 'Category'}
          <span className="text-lime">.</span>
        </h1>
        {category?.description && (
          <p className="mt-2 text-text-secondary">{category.description}</p>
        )}
      </div>

      {invalidId && <ErrorAlert message="Invalid category id" />}
      {loadError && (
        <ErrorAlert message={loadError} onDismiss={() => setLoadError(null)} />
      )}

      {invalidId ? null : !loaded ? (
        !loadError && <LoadingSpinner size="lg" />
      ) : (
        <>
          <CategoryChart category={category} days={days} />

          {entries.length === 0 ? (
            <div className="text-center py-16 bg-card border border-white/5 rounded-3xl">
              <div className="inline-flex p-4 rounded-3xl bg-surface mb-4">
                <Calendar className="w-8 h-8 text-text-disabled" strokeWidth={2} />
              </div>
              <h3 className="text-lg font-medium text-text-primary mb-1">
                No entries yet
              </h3>
              <p className="text-text-secondary">
                Entries for this category will appear here
              </p>
            </div>
          ) : (
            <div className="space-y-8">
              {groupEntriesByDate(entries).map(([date, dateEntries]) => (
                <div key={date}>
                  <div className="flex items-center gap-3 mb-4">
                    <span className="text-[13px] font-medium uppercase tracking-widest text-lime">
                      {date}
                    </span>
                    <div className="flex-1 h-px bg-white/5" />
                  </div>
                  <div className="space-y-4">
                    {dateEntries.map((entry) => (
                      <EntryCard
                        key={entry.id}
                        entry={entry}
                        category={category}
                        onMutated={reload}
                        onError={setLoadError}
                      />
                    ))}
                  </div>
                </div>
              ))}
            </div>
          )}
        </>
      )}
    </div>
  );
}
