'use client';
// [review:need-review] PHASE-01/22-category-page-entries-cards
// summary: reusable entry card (extracted from app/entries/page.tsx) with inline edit/delete + shared FieldValueInput

import { useState } from 'react';
import { Pencil, X } from 'lucide-react';
import {
  Category,
  Entry,
  EntryValueCreate,
  Field,
  entriesAPI,
} from '@/lib/api';

const DEFAULT_CATEGORY_COLOR = '#B8FF36';

export const entryInputClass =
  'w-full px-4 py-3 bg-surface border border-white/10 rounded-2xl text-text-primary placeholder:text-text-disabled outline-none transition-all duration-200 focus:border-lime focus:ring-2 focus:ring-lime/25';

interface FieldValueInputProps {
  field: Field;
  value: string;
  onChange: (value: string) => void;
}

/** Type-aware input for a single field value; shared by create and edit forms. */
export function FieldValueInput({ field, value, onChange }: FieldValueInputProps) {
  if (field.field_type === 'select') {
    return (
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        required={field.is_required}
        className={entryInputClass}
      >
        <option value="">Select...</option>
        {field.options?.split(',').map((opt) => (
          <option key={opt} value={opt.trim()}>
            {opt.trim()}
          </option>
        ))}
      </select>
    );
  }
  if (field.field_type === 'boolean') {
    return (
      <input
        type="checkbox"
        checked={value === 'true'}
        onChange={(e) => onChange(e.target.checked.toString())}
        className="w-5 h-5 accent-[#B8FF36] rounded"
      />
    );
  }
  const inputType =
    field.field_type === 'number'
      ? 'number'
      : field.field_type === 'date'
        ? 'date'
        : field.field_type === 'time'
          ? 'time'
          : 'text';
  return (
    <input
      type={inputType}
      value={value}
      onChange={(e) => onChange(e.target.value)}
      required={field.is_required}
      step={field.field_type === 'number' ? 'any' : undefined}
      className={entryInputClass}
    />
  );
}

interface EntryCardProps {
  entry: Entry;
  category: Category | undefined;
  /** Called after a successful update or delete so the parent can reload data. */
  onMutated: () => void;
  onError: (message: string) => void;
}

/** Dark card for one entry: field values grid, notes, inline edit form, delete. */
export default function EntryCard({ entry, category, onMutated, onError }: EntryCardProps) {
  const [editing, setEditing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [entryDate, setEntryDate] = useState(entry.entry_date);
  const [notes, setNotes] = useState(entry.notes ?? '');
  const [values, setValues] = useState<Record<number, string>>({});

  const categoryColor = category?.color || DEFAULT_CATEGORY_COLOR;

  const startEdit = () => {
    const initial: Record<number, string> = {};
    for (const value of entry.values) {
      initial[value.field_id] = value.value;
    }
    setValues(initial);
    setEntryDate(entry.entry_date);
    setNotes(entry.notes ?? '');
    setEditing(true);
  };

  const handleDelete = async () => {
    if (!confirm('Delete this entry?')) return;
    try {
      await entriesAPI.delete(entry.id);
      onMutated();
    } catch (err) {
      onError(err instanceof Error ? err.message : 'Failed to delete entry');
    }
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!category) return;
    setSaving(true);
    try {
      const entryValues: EntryValueCreate[] = category.fields.map((field) => ({
        field_id: field.id,
        value: values[field.id] || '',
      }));
      await entriesAPI.update(entry.id, {
        entry_date: entryDate,
        notes: notes || undefined,
        values: entryValues,
      });
      setEditing(false);
      onMutated();
    } catch (err) {
      onError(err instanceof Error ? err.message : 'Failed to update entry');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="bg-card border border-white/5 rounded-3xl p-6 transition-all duration-200 hover:-translate-y-0.5 hover:shadow-[0_10px_30px_rgba(0,0,0,0.5)]">
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
        <div className="flex items-center gap-1 flex-shrink-0">
          {category && !editing && (
            <button
              onClick={startEdit}
              aria-label="Edit entry"
              className="p-2 rounded-full text-text-secondary hover:text-lime hover:bg-lime/10 transition-colors duration-200"
            >
              <Pencil className="w-4 h-4" strokeWidth={2} />
            </button>
          )}
          <button
            onClick={handleDelete}
            aria-label="Delete entry"
            className="p-2 rounded-full text-text-secondary hover:text-danger hover:bg-danger/10 transition-colors duration-200"
          >
            <X className="w-4 h-4" strokeWidth={2} />
          </button>
        </div>
      </div>

      {editing && category ? (
        <form onSubmit={handleSave} className="space-y-4">
          <div>
            <label className="block text-[13px] font-medium text-text-secondary mb-2">
              Date *
            </label>
            <input
              type="date"
              value={entryDate}
              onChange={(e) => setEntryDate(e.target.value)}
              required
              className={entryInputClass}
            />
          </div>

          {category.fields.map((field) => (
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

          <div>
            <label className="block text-[13px] font-medium text-text-secondary mb-2">
              Notes
            </label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              rows={3}
              className={entryInputClass}
            />
          </div>

          <div className="flex gap-3 pt-2">
            <button
              type="button"
              onClick={() => setEditing(false)}
              className="flex-1 px-4 py-3 bg-surface border border-white/10 text-text-primary rounded-3xl font-medium transition-colors duration-200 hover:bg-white/5"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={saving}
              className="flex-1 px-4 py-3 bg-lime text-background rounded-3xl font-medium transition-all duration-200 hover:-translate-y-0.5 hover:shadow-[0_0_24px_rgba(184,255,54,0.35)] disabled:opacity-50 disabled:hover:translate-y-0 disabled:hover:shadow-none"
            >
              {saving ? 'Saving...' : 'Save'}
            </button>
          </div>
        </form>
      ) : (
        <>
          <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
            {entry.values.map((value) => {
              const field = category?.fields.find((f) => f.id === value.field_id);
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
        </>
      )}
    </div>
  );
}
