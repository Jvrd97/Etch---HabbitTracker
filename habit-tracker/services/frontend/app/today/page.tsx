'use client';
// [review:need-review] PHASE-01/31-web-quickfixes-md-fab-checklist
// summary: Today page — checklist chips are boolean-fields only; legacy checklist categories without booleans fall back to quick number input

import { useCallback, useEffect, useState } from 'react';
import { categoriesAPI, entriesAPI, Category, Entry, Field } from '@/lib/api';
import LoadingSpinner from '@/components/LoadingSpinner';
import ErrorAlert from '@/components/ErrorAlert';
import { Check, Plus, Sun } from 'lucide-react';

const TRUE_VALUE = 'true';

function todayISO(): string {
  return new Date().toISOString().split('T')[0];
}

function firstNumberField(category: Category): Field | undefined {
  return [...category.fields]
    .sort((a, b) => a.order - b.order)
    .find((f) => f.field_type === 'number');
}

function booleanFields(category: Category): Field[] {
  return [...category.fields]
    .filter((f) => f.field_type === 'boolean')
    .sort((a, b) => a.order - b.order);
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

export default function TodayPage() {
  const [categories, setCategories] = useState<Category[]>([]);
  const [checked, setChecked] = useState<CheckedMap>({});
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
      setChecked(buildCheckedMap(categoriesData, entriesData));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load today data');
    } finally {
      setLoading(false);
    }
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

  // Legacy data fallback: a checklist category saved before the API started
  // requiring a boolean field is treated like a form category below.
  const checklistCategories = categories.filter(
    (c) => c.display_mode === 'checklist' && booleanFields(c).length > 0
  );
  const quickFormCategories = categories
    .map((category) => ({ category, numberField: firstNumberField(category) }))
    .filter(
      (item): item is { category: Category; numberField: Field } =>
        item.numberField !== undefined &&
        (item.category.display_mode === 'form' ||
          booleanFields(item.category).length === 0)
    );

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

      {checklistCategories.length === 0 && quickFormCategories.length === 0 ? (
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
  onError: (message: string) => void;
}

function QuickNumberRow({ category, numberField, onError }: QuickNumberRowProps) {
  const [value, setValue] = useState('');
  const [saving, setSaving] = useState(false);
  const [savedValue, setSavedValue] = useState<string | null>(null);

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!value) return;
    setSaving(true);
    try {
      await entriesAPI.create({
        category_id: category.id,
        entry_date: todayISO(),
        values: [{ field_id: numberField.id, value }],
      });
      setSavedValue(value);
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
        <p className="text-xs text-text-disabled truncate">
          {numberField.name}
          {savedValue !== null && (
            <span className="text-lime"> — saved: {savedValue}</span>
          )}
        </p>
      </div>
      <input
        type="number"
        step="any"
        value={value}
        onChange={(e) => setValue(e.target.value)}
        placeholder="0"
        aria-label={`${category.name}: ${numberField.name}`}
        className="w-24 px-4 py-2.5 bg-surface border border-white/10 rounded-2xl text-text-primary placeholder:text-text-disabled outline-none transition-all duration-200 focus:border-lime focus:ring-2 focus:ring-lime/25"
      />
      <button
        type="submit"
        disabled={saving || !value}
        aria-label={`Save ${category.name}`}
        className="p-2.5 bg-lime text-background rounded-full transition-all duration-200 hover:-translate-y-0.5 hover:shadow-[0_0_18px_rgba(184,255,54,0.35)] disabled:opacity-50 disabled:hover:translate-y-0 disabled:hover:shadow-none"
      >
        <Plus className="w-4 h-4" strokeWidth={2.5} />
      </button>
    </form>
  );
}
