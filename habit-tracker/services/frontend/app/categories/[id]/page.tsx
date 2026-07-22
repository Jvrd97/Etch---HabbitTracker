'use client';
// [review:need-review] PHASE-01/20-category-page-chart
// summary: category detail page - header with category name plus per-day multi-line chart fed by GET /table over the last year

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { ArrowLeft } from 'lucide-react';
import { Category, TableDay, categoriesAPI, tableAPI } from '@/lib/api';
import { chartDateRange } from '@/lib/chart-data';
import CategoryChart from '@/components/CategoryChart';
import ErrorAlert from '@/components/ErrorAlert';
import LoadingSpinner from '@/components/LoadingSpinner';

export default function CategoryDetailPage() {
  const params = useParams<{ id: string }>();
  const categoryId = Number(params.id);

  const invalidId = !Number.isInteger(categoryId) || categoryId <= 0;

  const [category, setCategory] = useState<Category | null>(null);
  const [days, setDays] = useState<TableDay[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);

  useEffect(() => {
    if (!Number.isInteger(categoryId) || categoryId <= 0) return;
    let cancelled = false;
    const load = async () => {
      try {
        const { from, to } = chartDateRange(new Date());
        const [categoryResult, tableResult] = await Promise.all([
          categoriesAPI.getById(categoryId),
          tableAPI.get(from, to),
        ]);
        if (cancelled) return;
        setCategory(categoryResult);
        setDays(tableResult.days);
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
  }, [categoryId]);

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

      {invalidId ? null : category === null || days === null ? (
        !loadError && <LoadingSpinner size="lg" />
      ) : (
        <CategoryChart category={category} days={days} />
      )}
    </div>
  );
}
