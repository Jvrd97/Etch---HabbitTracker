'use client';
// [review:need-review] PHASE-01/22-category-page-entries-cards
// summary: Entries page migrated to shared EntryCard/FieldValueInput and lib groupEntriesByDate (card markup extracted)

import { useEffect, useState } from 'react';
import { entriesAPI, categoriesAPI, Entry, Category, EntryCreate, EntryValueCreate } from '@/lib/api';
import { groupEntriesByDate } from '@/lib/entry-groups';
import LoadingSpinner from '@/components/LoadingSpinner';
import ErrorAlert from '@/components/ErrorAlert';
import EntryCard, { FieldValueInput, entryInputClass } from '@/components/EntryCard';
import { Plus, Filter, X, Calendar } from 'lucide-react';

const inputClass = entryInputClass;

export default function EntriesPage() {
  const [entries, setEntries] = useState<Entry[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [filterCategory, setFilterCategory] = useState<number | null>(null);

  useEffect(() => {
    loadData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filterCategory]);

  const loadData = async () => {
    try {
      setLoading(true);
      const [entriesData, categoriesData] = await Promise.all([
        entriesAPI.getAll({ categoryId: filterCategory || undefined, limit: 50 }),
        categoriesAPI.getAll(),
      ]);
      setEntries(entriesData);
      setCategories(categoriesData);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load entries');
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <LoadingSpinner size="lg" />;

  const grouped = groupEntriesByDate(entries);

  return (
    <div className="space-y-8 animate-fade-rise">
      <div className="flex justify-between items-center gap-4">
        <div>
          <h1 className="text-4xl font-bold text-text-primary tracking-tight">
            Entries
            <span className="text-lime">.</span>
          </h1>
          <p className="mt-2 text-text-secondary">Track your daily data</p>
        </div>
        <button
          onClick={() => setShowForm(true)}
          className="flex items-center gap-2 px-6 py-3 bg-lime text-background rounded-3xl font-medium transition-all duration-200 hover:-translate-y-0.5 hover:shadow-[0_0_24px_rgba(184,255,54,0.35)]"
        >
          <Plus className="w-5 h-5" strokeWidth={2} />
          <span className="hidden sm:inline">New entry</span>
        </button>
      </div>

      {error && <ErrorAlert message={error} onDismiss={() => setError(null)} />}

      {/* Filter */}
      <div className="bg-card border border-white/5 rounded-3xl p-4">
        <div className="flex items-center gap-4">
          <div className="p-2 rounded-2xl bg-surface flex-shrink-0">
            <Filter className="w-4 h-4 text-lime" strokeWidth={2} />
          </div>
          <select
            value={filterCategory || ''}
            onChange={(e) => setFilterCategory(e.target.value ? Number(e.target.value) : null)}
            className="flex-1 px-4 py-2.5 bg-surface border border-white/10 rounded-2xl text-text-primary outline-none transition-all duration-200 focus:border-lime focus:ring-2 focus:ring-lime/25"
          >
            <option value="">All categories</option>
            {categories.map((cat) => (
              <option key={cat.id} value={cat.id}>
                {cat.name}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Entry Form Modal */}
      {showForm && (
        <EntryForm
          categories={categories}
          onClose={() => setShowForm(false)}
          onSuccess={() => {
            setShowForm(false);
            loadData();
          }}
        />
      )}

      {/* Entries List grouped by date */}
      {entries.length === 0 ? (
        <div className="text-center py-16 bg-card border border-white/5 rounded-3xl">
          <div className="inline-flex p-4 rounded-3xl bg-surface mb-4">
            <Calendar className="w-8 h-8 text-text-disabled" strokeWidth={2} />
          </div>
          <h3 className="text-lg font-medium text-text-primary mb-1">Nothing here yet</h3>
          <p className="text-text-secondary mb-6">Start tracking by creating your first entry</p>
          <button
            onClick={() => setShowForm(true)}
            className="px-6 py-3 bg-lime text-background rounded-3xl font-medium transition-all duration-200 hover:-translate-y-0.5 hover:shadow-[0_0_24px_rgba(184,255,54,0.35)]"
          >
            Create entry
          </button>
        </div>
      ) : (
        <div className="space-y-8">
          {grouped.map(([date, dateEntries]) => (
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
                    category={categories.find((c) => c.id === entry.category_id)}
                    onMutated={loadData}
                    onError={setError}
                  />
                ))}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

interface EntryFormProps {
  categories: Category[];
  onClose: () => void;
  onSuccess: () => void;
}

function EntryForm({ categories, onClose, onSuccess }: EntryFormProps) {
  const [categoryId, setCategoryId] = useState<number>(categories[0]?.id || 0);
  const [entryDate, setEntryDate] = useState(new Date().toISOString().split('T')[0]);
  const [notes, setNotes] = useState('');
  const [values, setValues] = useState<Record<number, string>>({});
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const selectedCategory = categories.find(c => c.id === categoryId);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedCategory) return;

    setSaving(true);
    setError(null);

    try {
      const entryValues: EntryValueCreate[] = selectedCategory.fields.map(field => ({
        field_id: field.id,
        value: values[field.id] || '',
      }));

      const data: EntryCreate = {
        category_id: categoryId,
        entry_date: entryDate,
        notes: notes || undefined,
        values: entryValues,
      };

      await entriesAPI.create(data);
      onSuccess();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create entry');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4 z-50">
      <div className="bg-card border border-white/10 rounded-3xl max-w-2xl w-full max-h-[90vh] overflow-y-auto animate-fade-rise">
        <div className="sticky top-0 bg-card border-b border-white/5 px-6 py-5 flex justify-between items-center rounded-t-3xl">
          <h2 className="text-[22px] font-semibold text-text-primary">New entry</h2>
          <button
            onClick={onClose}
            aria-label="Close"
            className="p-2 rounded-full text-text-secondary hover:text-text-primary hover:bg-white/5 transition-colors duration-200"
          >
            <X className="w-5 h-5" strokeWidth={2} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          {error && <ErrorAlert message={error} />}

          <div>
            <label className="block text-[13px] font-medium text-text-secondary mb-2">
              Category *
            </label>
            <select
              value={categoryId}
              onChange={(e) => {
                setCategoryId(Number(e.target.value));
                setValues({});
              }}
              required
              className={inputClass}
            >
              {categories.map((cat) => (
                <option key={cat.id} value={cat.id}>
                  {cat.name}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-[13px] font-medium text-text-secondary mb-2">
              Date *
            </label>
            <input
              type="date"
              value={entryDate}
              onChange={(e) => setEntryDate(e.target.value)}
              required
              className={inputClass}
            />
          </div>

          {selectedCategory && (
            <div className="space-y-4">
              <h3 className="text-lg font-medium text-text-primary">Field values</h3>
              {selectedCategory.fields.map((field) => (
                <div key={field.id}>
                  <label className="block text-[13px] font-medium text-text-secondary mb-2">
                    {field.name} {field.is_required && '*'}
                  </label>

                  <FieldValueInput
                    field={field}
                    value={values[field.id] || ''}
                    onChange={(value) => setValues({ ...values, [field.id]: value })}
                  />
                </div>
              ))}
            </div>
          )}

          <div>
            <label className="block text-[13px] font-medium text-text-secondary mb-2">
              Notes
            </label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              rows={3}
              className={inputClass}
            />
          </div>

          <div className="flex gap-3 pt-4">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-4 py-3 bg-surface border border-white/10 text-text-primary rounded-3xl font-medium transition-colors duration-200 hover:bg-white/5"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={saving}
              className="flex-1 px-4 py-3 bg-lime text-background rounded-3xl font-medium transition-all duration-200 hover:-translate-y-0.5 hover:shadow-[0_0_24px_rgba(184,255,54,0.35)] disabled:opacity-50 disabled:hover:translate-y-0 disabled:hover:shadow-none"
            >
              {saving ? 'Creating...' : 'Create entry'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
