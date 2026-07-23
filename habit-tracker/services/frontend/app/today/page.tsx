'use client';
// [review:need-review] PHASE-01/28-today-avoid-card
// summary: Today page — avoid categories render a streak card with relapse form; build number categories keep the running-total quick input

import { useCallback, useEffect, useState } from 'react';
import { categoriesAPI, entriesAPI, Category, CategoryStreak, Entry, Field } from '@/lib/api';
import LoadingSpinner from '@/components/LoadingSpinner';
import ErrorAlert from '@/components/ErrorAlert';
import AvoidStreakCard from '@/components/AvoidStreakCard';
import { booleanFields, partitionTodayCategories } from '@/lib/today-categories';
import { Check, Plus, Sun } from 'lucide-react';

const TRUE_VALUE = 'true';

function todayISO(): string {
  return new Date().toISOString().split('T')[0];
}

/** checked-state per category: field_id -> boolean */
type CheckedMap = Record<number, Record<number, boolean>>;

function buildCheckedMap(categories: Category[], entries: Entry[]): CheckedMap {
  const map: CheckedMap = {};
  for (const category of categories) {
    if (category.display_mode !== 'checklist') continue;
    const entry = entries.find((e) => e.category_id === category.id);
    const fieldsChecked: Record<number, boolean> = {};
    for (const field of booleanFields(category)) {
      const value = entry?.values.find((v) => v.field_id === field.id);
      fieldsChecked[field.id] = value?.value === TRUE_VALUE;
    }
    map[category.id] = fieldsChecked;
  }
  return map;
}

/** Sum of today's values for one number field across all of a category's entries. */
function numberFieldSum(
  entries: Entry[],
  categoryId: number,
  fieldId: number
): number {
  return entries
    .filter((entry) => entry.category_id === categoryId)
    .reduce((sum, entry) => {
      const value = entry.values.find((v) => v.field_id === fieldId);
      const parsed = value ? Number(value.value) : Number.NaN;
      return Number.isFinite(parsed) ? sum + parsed : sum;
    }, 0);
}

/** current/best streak per avoid category; null while loading or on failure. */
type StreakMap = Record<number, CategoryStreak | null>;

export default function TodayPage() {
  const [categories, setCategories] = useState<Category[]>([]);
  const [entries, setEntries] = useState<Entry[]>([]);
  const [checked, setChecked] = useState<CheckedMap>({});
  const [streaks, setStreaks] = useState<StreakMap>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadData = useCallback(async () => {
    try {
      setLoading(true);
      const date = todayISO();
      const [categoriesData, entriesData] = await Promise.all([
        categoriesAPI.getAll(),
        entriesAPI.getAll({ startDate: date, endDate: date }),
      ]);
      setCategories(categoriesData);
      setEntries(entriesData);
      setChecked(buildCheckedMap(categoriesData, entriesData));

      // Streaks are a secondary widget: a failed fetch degrades one card to "—"
      // instead of blanking the page.
      const avoid = partitionTodayCategories(categoriesData).avoid;
      const loaded = await Promise.all(
        avoid.map(
          async ({ category }) =>
            [category.id, await categoriesAPI.getStreak(category.id).catch(() => null)] as const
        )
      );
      setStreaks(Object.fromEntries(loaded));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load today data');
    } finally {
      setLoading(false);
    }
  }, []);

  const reloadStreak = useCallback(async (categoryId: number) => {
    const streak = await categoriesAPI.getStreak(categoryId).catch(() => null);
    setStreaks((prev) => ({ ...prev, [categoryId]: streak }));
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const handleToggle = async (categoryId: number, fieldId: number) => {
    const current = checked[categoryId]?.[fieldId] ?? false;
    const next = !current;

    // Optimistic update
    setChecked((prev) => ({
      ...prev,
      [categoryId]: { ...prev[categoryId], [fieldId]: next },
    }));

    try {
      await entriesAPI.upsertChecklist({
        category_id: categoryId,
        entry_date: todayISO(),
        values: { [fieldId]: next },
      });
    } catch (err) {
      // Roll back on failure
      setChecked((prev) => ({
        ...prev,
        [categoryId]: { ...prev[categoryId], [fieldId]: current },
      }));
      setError(err instanceof Error ? err.message : 'Failed to save check');
    }
  };

  if (loading) return <LoadingSpinner size="lg" />;

  const {
    avoid: avoidCategories,
    checklist: checklistCategories,
    quickForm: quickFormCategories,
  } = partitionTodayCategories(categories);

  const nothingToTrack =
    avoidCategories.length === 0 &&
    checklistCategories.length === 0 &&
    quickFormCategories.length === 0;

  return (
    <div className="space-y-8 animate-fade-rise">
      <div>
        <h1 className="text-4xl font-bold text-text-primary tracking-tight">
          Today
          <span className="text-lime">.</span>
        </h1>
        <p className="mt-2 text-text-secondary">{todayISO()} — one tap to check things off</p>
      </div>

      {error && <ErrorAlert message={error} onDismiss={() => setError(null)} />}

      {nothingToTrack ? (
        <div className="text-center py-16 bg-card border border-white/5 rounded-3xl">
          <div className="inline-flex p-4 rounded-3xl bg-surface mb-4">
            <Sun className="w-8 h-8 text-text-disabled" strokeWidth={2} />
          </div>
          <h3 className="text-lg font-medium text-text-primary mb-1">Nothing to track today</h3>
          <p className="text-text-secondary">
            Create a checklist category or a form category with a number field
          </p>
        </div>
      ) : (
        <>
          {avoidCategories.length > 0 && (
            <section>
              <div className="flex items-center gap-3 mb-4">
                <span className="text-[13px] font-medium uppercase tracking-widest text-lime">
                  Streaks
                </span>
                <div className="flex-1 h-px bg-white/5" />
              </div>
              <div className="space-y-3">
                {avoidCategories.map(({ category, numberField }) => (
                  <AvoidStreakCard
                    key={category.id}
                    category={category}
                    numberField={numberField}
                    streak={streaks[category.id] ?? null}
                    onRelapse={reloadStreak}
                    onError={setError}
                  />
                ))}
              </div>
            </section>
          )}

          {checklistCategories.map((category) => (
            <section key={category.id}>
              <div className="flex items-center gap-3 mb-4">
                <span className="text-[13px] font-medium uppercase tracking-widest text-lime">
                  {category.name}
                </span>
                <div className="flex-1 h-px bg-white/5" />
              </div>
              <div className="flex flex-wrap gap-3">
                {booleanFields(category).map((field) => {
                    const isChecked = checked[category.id]?.[field.id] ?? false;
                    return (
                      <button
                        key={field.id}
                        onClick={() => handleToggle(category.id, field.id)}
                        aria-pressed={isChecked}
                        className={`inline-flex items-center gap-2 px-5 py-3 rounded-full text-sm font-medium transition-all duration-200 border ${
                          isChecked
                            ? 'bg-lime text-background border-lime shadow-[0_0_18px_rgba(184,255,54,0.25)]'
                            : 'bg-card text-text-secondary border-white/10 hover:text-text-primary hover:bg-white/5'
                        }`}
                      >
                        {isChecked && <Check className="w-4 h-4" strokeWidth={2.5} />}
                        {field.name}
                      </button>
                    );
                  })}
              </div>
            </section>
          ))}

          {quickFormCategories.length > 0 && (
            <section>
              <div className="flex items-center gap-3 mb-4">
                <span className="text-[13px] font-medium uppercase tracking-widest text-lime">
                  Quick input
                </span>
                <div className="flex-1 h-px bg-white/5" />
              </div>
              <div className="space-y-3">
                {quickFormCategories.map(({ category, numberField }) => (
                  <QuickNumberRow
                    key={category.id}
                    category={category}
                    numberField={numberField}
                    initialTotal={numberFieldSum(entries, category.id, numberField.id)}
                    onError={setError}
                  />
                ))}
              </div>
            </section>
          )}
        </>
      )}
    </div>
  );
}

interface QuickNumberRowProps {
  category: Category;
  numberField: Field;
  /** Sum of today's entries for this field, shown as the running total. */
  initialTotal: number;
  onError: (message: string) => void;
}

/** Total as a clean string: integers stay integers, floats drop trailing zeros. */
function formatTotal(n: number): string {
  return Number.isInteger(n) ? String(n) : Number(n.toFixed(2)).toString();
}

function QuickNumberRow({
  category,
  numberField,
  initialTotal,
  onError,
}: QuickNumberRowProps) {
  const [value, setValue] = useState('');
  const [saving, setSaving] = useState(false);
  const [total, setTotal] = useState(initialTotal);

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    const amount = Number(value);
    if (!value || !Number.isFinite(amount)) return;
    setSaving(true);
    try {
      await entriesAPI.create({
        category_id: category.id,
        entry_date: todayISO(),
        values: [{ field_id: numberField.id, value }],
      });
      setTotal((current) => current + amount);
      setValue('');
    } catch (err) {
      onError(err instanceof Error ? err.message : 'Failed to save entry');
    } finally {
      setSaving(false);
    }
  };

  return (
    <form
      onSubmit={handleSave}
      className="flex items-center gap-4 bg-card border border-white/5 rounded-3xl p-4"
    >
      <div className="min-w-0 flex-1">
        <p className="text-sm font-medium text-text-primary truncate">{category.name}</p>
        <p className="text-xs text-text-disabled truncate">{numberField.name}</p>
      </div>
      <div className="text-right leading-tight">
        <span className="block text-2xl font-semibold text-lime tabular-nums">
          {formatTotal(total)}
        </span>
        <span className="block text-[11px] uppercase tracking-widest text-text-disabled">
          today
        </span>
      </div>
      <input
        type="number"
        step="any"
        value={value}
        onChange={(e) => setValue(e.target.value)}
        placeholder="0"
        aria-label={`${category.name}: add ${numberField.name}`}
        className="w-24 px-4 py-2.5 bg-surface border border-white/10 rounded-2xl text-text-primary placeholder:text-text-disabled outline-none transition-all duration-200 focus:border-lime focus:ring-2 focus:ring-lime/25"
      />
      <button
        type="submit"
        disabled={saving || !value}
        aria-label={`Add to ${category.name}`}
        className="p-2.5 bg-lime text-background rounded-full transition-all duration-200 hover:-translate-y-0.5 hover:shadow-[0_0_18px_rgba(184,255,54,0.35)] disabled:opacity-50 disabled:hover:translate-y-0 disabled:hover:shadow-none"
      >
        <Plus className="w-4 h-4" strokeWidth={2.5} />
      </button>
    </form>
  );
}
