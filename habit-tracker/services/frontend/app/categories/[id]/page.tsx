'use client';
// [review:need-review] PHASE-01/29-category-page-nav-and-quick-add, PHASE-01/27-streak-mode-endpoint
// summary: category detail page - chart, entry history, category pager, quick-add; plus streak block for avoid categories

import { useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { ArrowLeft, ArrowRight, Calendar, Plus } from 'lucide-react';
import {
  Category,
  CategoryStreak,
  Entry,
  TableDay,
  categoriesAPI,
  entriesAPI,
  tableAPI,
} from '@/lib/api';
import { categorySiblings } from '@/lib/category-nav';
import { chartDateRange } from '@/lib/chart-data';
import { groupEntriesByDate } from '@/lib/entry-groups';
import CategoryChart from '@/components/CategoryChart';
import EntryCard from '@/components/EntryCard';
import EntryForm from '@/components/EntryForm';
import ErrorAlert from '@/components/ErrorAlert';
import LoadingSpinner from '@/components/LoadingSpinner';
import StreakCard from '@/components/StreakCard';

/** Full history without pagination (ticket #22: pagination is out of scope). */
const ENTRIES_FETCH_LIMIT = 1000;

export default function CategoryDetailPage() {
  const params = useParams<{ id: string }>();
  const categoryId = Number(params.id);

  const invalidId = !Number.isInteger(categoryId) || categoryId <= 0;

  const [category, setCategory] = useState<Category | null>(null);
  const [categories, setCategories] = useState<Category[]>([]);
  const [days, setDays] = useState<TableDay[] | null>(null);
  const [entries, setEntries] = useState<Entry[] | null>(null);
  const [streak, setStreak] = useState<CategoryStreak | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [refreshCounter, setRefreshCounter] = useState(0);
  const [showForm, setShowForm] = useState(false);

  useEffect(() => {
    if (!Number.isInteger(categoryId) || categoryId <= 0) return;
    let cancelled = false;
    const load = async () => {
      try {
        const { from, to } = chartDateRange(new Date());
        const [categoryResult, categoriesResult, tableResult, entriesResult, streakResult] =
          await Promise.all([
            categoriesAPI.getById(categoryId),
            categoriesAPI.getAll(),
            tableAPI.get(from, to),
            entriesAPI.getAll({ categoryId, limit: ENTRIES_FETCH_LIMIT }),
            // Secondary widget: a failure here must not blank the whole page,
            // so it degrades to "no streak block" instead of rejecting the batch.
            categoriesAPI.getStreak(categoryId).catch(() => null),
          ]);
        if (cancelled) return;
        setCategory(categoryResult);
        setCategories(categoriesResult);
        setDays(tableResult.days);
        setEntries(entriesResult);
        setStreak(streakResult);
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
  const { prev, next } = categorySiblings(categories, categoryId);

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

        <div className="mt-3 flex items-start justify-between gap-4">
          <div className="min-w-0">
            <h1 className="text-4xl font-bold text-text-primary tracking-tight">
              {category?.name ?? 'Category'}
              <span className="text-lime">.</span>
            </h1>
            {category?.description && (
              <p className="mt-2 text-text-secondary">{category.description}</p>
            )}
          </div>

          <div className="flex items-center gap-2 flex-shrink-0">
            <CategoryPagerButton category={prev} direction="prev" />
            <CategoryPagerButton category={next} direction="next" />
            {loaded && (
              <button
                onClick={() => setShowForm(true)}
                className="ml-2 flex items-center gap-2 px-5 py-2.5 bg-lime text-background rounded-3xl font-medium transition-all duration-200 hover:-translate-y-0.5 hover:shadow-[0_0_24px_rgba(184,255,54,0.35)]"
              >
                <Plus className="w-5 h-5" strokeWidth={2} />
                <span className="hidden sm:inline">New entry</span>
              </button>
            )}
          </div>
        </div>

        {categories.length > 1 && (
          <div className="mt-6 flex gap-2 overflow-x-auto pb-1">
            {categories.map((cat) => (
              <Link
                key={cat.id}
                href={`/categories/${cat.id}`}
                aria-current={cat.id === categoryId ? 'page' : undefined}
                className={`px-4 py-2 rounded-3xl text-sm font-medium whitespace-nowrap transition-colors duration-200 ${
                  cat.id === categoryId
                    ? 'bg-lime text-background'
                    : 'bg-surface border border-white/10 text-text-secondary hover:text-text-primary hover:bg-white/5'
                }`}
              >
                {cat.name}
              </Link>
            ))}
          </div>
        )}
      </div>

      {showForm && category && (
        <EntryForm
          categories={categories}
          lockedCategoryId={categoryId}
          onClose={() => setShowForm(false)}
          onSuccess={() => {
            setShowForm(false);
            reload();
          }}
        />
      )}

      {invalidId && <ErrorAlert message="Invalid category id" />}
      {loadError && (
        <ErrorAlert message={loadError} onDismiss={() => setLoadError(null)} />
      )}

      {invalidId ? null : !loaded ? (
        !loadError && <LoadingSpinner size="lg" />
      ) : (
        <>
          {category.streak_mode === 'avoid' && streak !== null && (
            <StreakCard streak={streak} />
          )}

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

interface CategoryPagerButtonProps {
  category: Category | null;
  direction: 'prev' | 'next';
}

/** Arrow to the adjacent category; renders a disabled stub at the ends of the list. */
function CategoryPagerButton({ category, direction }: CategoryPagerButtonProps) {
  const Icon = direction === 'prev' ? ArrowLeft : ArrowRight;
  const baseClass = 'p-2.5 rounded-full border transition-colors duration-200';

  if (!category) {
    return (
      <span
        aria-hidden="true"
        className={`${baseClass} border-white/5 text-text-disabled opacity-40`}
      >
        <Icon className="w-5 h-5" strokeWidth={2} />
      </span>
    );
  }

  return (
    <Link
      href={`/categories/${category.id}`}
      aria-label={`${direction === 'prev' ? 'Previous' : 'Next'} category: ${category.name}`}
      title={category.name}
      className={`${baseClass} border-white/10 bg-surface text-text-secondary hover:text-lime hover:border-lime/40`}
    >
      <Icon className="w-5 h-5" strokeWidth={2} />
    </Link>
  );
}
