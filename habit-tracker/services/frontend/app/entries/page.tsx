'use client';
// [review:need-review] PHASE-01/adhoc-lime-redesign
// summary: Entries page restyled with date-grouped dark cards, filter chip bar and Lime Tech form modal

import { useEffect, useState } from 'react';
import { entriesAPI, categoriesAPI, Entry, Category, EntryCreate, EntryValueCreate } from '@/lib/api';
import LoadingSpinner from '@/components/LoadingSpinner';
import ErrorAlert from '@/components/ErrorAlert';
import { Plus, Filter, X, Calendar } from 'lucide-react';

const DEFAULT_CATEGORY_COLOR = '#B8FF36';

const inputClass =
  'w-full px-4 py-3 bg-surface border border-white/10 rounded-2xl text-text-primary placeholder:text-text-disabled outline-none transition-all duration-200 focus:border-lime focus:ring-2 focus:ring-lime/25';

function groupByDate(entries: Entry[]): Array<[string, Entry[]]> {
  const groups = new Map<string, Entry[]>();
  for (const entry of entries) {
    const existing = groups.get(entry.entry_date);
    if (existing) {
      existing.push(entry);
    } else {
      groups.set(entry.entry_date, [entry]);
    }
  }
  return Array.from(groups.entries());
}

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

  const handleDelete = async (id: number) => {
    if (!confirm('Delete this entry?')) return;
    try {
      await entriesAPI.delete(id);
      await loadData();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete entry');
    }
  };

  if (loading) return <LoadingSpinner size="lg" />;

  const grouped = groupByDate(entries);

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
                {dateEntries.map((entry) => {
                  const category = categories.find(c => c.id === entry.category_id);
                  const categoryColor = category?.color || DEFAULT_CATEGORY_COLOR;
                  return (
                    <div
                      key={entry.id}
                      className="bg-card border border-white/5 rounded-3xl p-6 transition-all duration-200 hover:-translate-y-0.5 hover:shadow-[0_10px_30px_rgba(0,0,0,0.5)]"
                    >
                      <div className="flex justify-between items-start mb-4">
                        <div className="flex items-center gap-3 min-w-0">
                          <div
                            className="w-10 h-10 rounded-2xl flex items-center justify-center flex-shrink-0"
                            style={{ backgroundColor: `${categoryColor}1f` }}
                          >
                            <span
                              className="w-3.5 h-3.5 rounded-full"
                              style={{ backgroundColor: categoryColor }}
                            />
                          </div>
                          <h3 className="text-lg font-medium text-text-primary truncate">
                            {category?.name || 'Unknown Category'}
                          </h3>
                        </div>
                        <button
                          onClick={() => handleDelete(entry.id)}
                          aria-label="Delete entry"
                          className="p-2 rounded-full text-text-secondary hover:text-danger hover:bg-danger/10 transition-colors duration-200 flex-shrink-0"
                        >
                          <X className="w-4 h-4" strokeWidth={2} />
                        </button>
                      </div>

                      <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
                        {entry.values.map((value) => {
                          const field = category?.fields.find(f => f.id === value.field_id);
                          return (
                            <div
                              key={value.id}
                              className="bg-surface border border-white/5 rounded-2xl p-3.5"
                            >
                              <p className="text-xs text-text-disabled mb-1">{field?.name}</p>
                              <p className="text-sm font-medium text-text-primary break-words">
                                {value.value}
                              </p>
                            </div>
                          );
                        })}
                      </div>

                      {entry.notes && (
                        <div className="mt-4 pt-4 border-t border-white/5">
                          <p className="text-sm text-text-secondary">{entry.notes}</p>
                        </div>
                      )}
                    </div>
                  );
                })}
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

                  {field.field_type === 'select' ? (
                    <select
                      value={values[field.id] || ''}
                      onChange={(e) => setValues({ ...values, [field.id]: e.target.value })}
                      required={field.is_required}
                      className={inputClass}
                    >
                      <option value="">Select...</option>
                      {field.options?.split(',').map((opt) => (
                        <option key={opt} value={opt.trim()}>
                          {opt.trim()}
                        </option>
                      ))}
                    </select>
                  ) : field.field_type === 'boolean' ? (
                    <input
                      type="checkbox"
                      checked={values[field.id] === 'true'}
                      onChange={(e) => setValues({ ...values, [field.id]: e.target.checked.toString() })}
                      className="w-5 h-5 accent-[#B8FF36] rounded"
                    />
                  ) : field.field_type === 'number' ? (
                    <input
                      type="number"
                      value={values[field.id] || ''}
                      onChange={(e) => setValues({ ...values, [field.id]: e.target.value })}
                      required={field.is_required}
                      step="any"
                      className={inputClass}
                    />
                  ) : field.field_type === 'date' ? (
                    <input
                      type="date"
                      value={values[field.id] || ''}
                      onChange={(e) => setValues({ ...values, [field.id]: e.target.value })}
                      required={field.is_required}
                      className={inputClass}
                    />
                  ) : field.field_type === 'time' ? (
                    <input
                      type="time"
                      value={values[field.id] || ''}
                      onChange={(e) => setValues({ ...values, [field.id]: e.target.value })}
                      required={field.is_required}
                      className={inputClass}
                    />
                  ) : (
                    <input
                      type="text"
                      value={values[field.id] || ''}
                      onChange={(e) => setValues({ ...values, [field.id]: e.target.value })}
                      required={field.is_required}
                      className={inputClass}
                    />
                  )}
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
