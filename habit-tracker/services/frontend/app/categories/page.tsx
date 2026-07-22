'use client';
// [review:need-review] PHASE-01/adhoc-lime-redesign
// summary: Categories page restyled with dark cards, color icon chips and Lime Tech form modal

import { useEffect, useState } from 'react';
import { categoriesAPI, Category, CategoryCreate, FieldCreate } from '@/lib/api';
import LoadingSpinner from '@/components/LoadingSpinner';
import ErrorAlert from '@/components/ErrorAlert';
import { Plus, Pencil, Trash2, FolderKanban, X } from 'lucide-react';

const DEFAULT_CATEGORY_COLOR = '#B8FF36';

const inputClass =
  'w-full px-4 py-3 bg-surface border border-white/10 rounded-2xl text-text-primary placeholder:text-text-disabled outline-none transition-all duration-200 focus:border-lime focus:ring-2 focus:ring-lime/25';

export default function CategoriesPage() {
  const [categories, setCategories] = useState<Category[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [editingCategory, setEditingCategory] = useState<Category | null>(null);

  useEffect(() => {
    loadCategories();
  }, []);

  const loadCategories = async () => {
    try {
      setLoading(true);
      const data = await categoriesAPI.getAll(false); // Get all including inactive
      setCategories(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load categories');
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (id: number) => {
    if (!confirm('Are you sure? This will delete all related entries!')) return;

    try {
      await categoriesAPI.delete(id);
      await loadCategories();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete category');
    }
  };

  if (loading) return <LoadingSpinner size="lg" />;

  return (
    <div className="space-y-8 animate-fade-rise">
      <div className="flex justify-between items-center gap-4">
        <div>
          <h1 className="text-4xl font-bold text-text-primary tracking-tight">
            Categories
            <span className="text-lime">.</span>
          </h1>
          <p className="mt-2 text-text-secondary">Manage your tracking categories</p>
        </div>
        <button
          onClick={() => {
            setEditingCategory(null);
            setShowForm(true);
          }}
          className="flex items-center gap-2 px-6 py-3 bg-lime text-background rounded-3xl font-medium transition-all duration-200 hover:-translate-y-0.5 hover:shadow-[0_0_24px_rgba(184,255,54,0.35)]"
        >
          <Plus className="w-5 h-5" strokeWidth={2} />
          <span className="hidden sm:inline">New category</span>
        </button>
      </div>

      {error && <ErrorAlert message={error} onDismiss={() => setError(null)} />}

      {/* Category Form Modal */}
      {showForm && (
        <CategoryForm
          category={editingCategory}
          onClose={() => {
            setShowForm(false);
            setEditingCategory(null);
          }}
          onSuccess={() => {
            setShowForm(false);
            setEditingCategory(null);
            loadCategories();
          }}
        />
      )}

      {/* Categories Grid */}
      {categories.length === 0 ? (
        <div className="text-center py-16 bg-card border border-white/5 rounded-3xl">
          <div className="inline-flex p-4 rounded-3xl bg-surface mb-4">
            <FolderKanban className="w-8 h-8 text-text-disabled" strokeWidth={2} />
          </div>
          <h3 className="text-lg font-medium text-text-primary mb-1">Nothing here yet</h3>
          <p className="text-text-secondary mb-6">Create your first category to start tracking</p>
          <button
            onClick={() => setShowForm(true)}
            className="px-6 py-3 bg-lime text-background rounded-3xl font-medium transition-all duration-200 hover:-translate-y-0.5 hover:shadow-[0_0_24px_rgba(184,255,54,0.35)]"
          >
            Create category
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {categories.map((category) => (
            <div
              key={category.id}
              className="bg-card border border-white/5 rounded-3xl p-6 transition-all duration-200 hover:-translate-y-0.5 hover:shadow-[0_10px_30px_rgba(0,0,0,0.5)]"
            >
              <div className="flex justify-between items-start mb-4">
                <div className="flex items-center gap-3 min-w-0">
                  <div
                    className="w-10 h-10 rounded-2xl flex items-center justify-center flex-shrink-0"
                    style={{ backgroundColor: `${category.color || DEFAULT_CATEGORY_COLOR}1f` }}
                  >
                    <span
                      className="w-3.5 h-3.5 rounded-full"
                      style={{ backgroundColor: category.color || DEFAULT_CATEGORY_COLOR }}
                    />
                  </div>
                  <h3 className="text-lg font-medium text-text-primary truncate">
                    {category.name}
                  </h3>
                </div>
                <div className="flex gap-1 flex-shrink-0">
                  <button
                    onClick={() => {
                      setEditingCategory(category);
                      setShowForm(true);
                    }}
                    aria-label="Edit category"
                    className="p-2 rounded-full text-text-secondary hover:text-lime hover:bg-lime/10 transition-colors duration-200"
                  >
                    <Pencil className="w-4 h-4" strokeWidth={2} />
                  </button>
                  <button
                    onClick={() => handleDelete(category.id)}
                    aria-label="Delete category"
                    className="p-2 rounded-full text-text-secondary hover:text-danger hover:bg-danger/10 transition-colors duration-200"
                  >
                    <Trash2 className="w-4 h-4" strokeWidth={2} />
                  </button>
                </div>
              </div>

              {category.description && (
                <p className="text-text-secondary text-sm mb-4">{category.description}</p>
              )}

              <div className="space-y-2">
                <p className="text-[13px] font-medium text-text-secondary">
                  Fields ({category.fields.length})
                </p>
                {category.fields.length > 0 ? (
                  <ul className="space-y-1.5">
                    {category.fields.map((field) => (
                      <li
                        key={field.id}
                        className="text-sm text-text-secondary flex items-center gap-2"
                      >
                        <span className="w-1.5 h-1.5 bg-lime rounded-full flex-shrink-0" />
                        <span className="text-text-primary">{field.name}</span>
                        <span className="text-text-disabled">{field.field_type}</span>
                      </li>
                    ))}
                  </ul>
                ) : (
                  <p className="text-sm text-text-disabled">No fields yet</p>
                )}
              </div>

              <div className="mt-5 pt-4 border-t border-white/5">
                <span
                  className={`inline-block px-3 py-1 rounded-full text-xs font-medium ${
                    category.is_active
                      ? 'bg-success/10 text-success'
                      : 'bg-white/5 text-text-disabled'
                  }`}
                >
                  {category.is_active ? 'Active' : 'Inactive'}
                </span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

interface CategoryFormProps {
  category: Category | null;
  onClose: () => void;
  onSuccess: () => void;
}

function CategoryForm({ category, onClose, onSuccess }: CategoryFormProps) {
  const [name, setName] = useState(category?.name || '');
  const [description, setDescription] = useState(category?.description || '');
  const [color, setColor] = useState(category?.color || DEFAULT_CATEGORY_COLOR);
  const [isActive, setIsActive] = useState(category?.is_active ?? true);
  const [fields, setFields] = useState<FieldCreate[]>(
    category?.fields.map(f => ({
      name: f.name,
      field_type: f.field_type,
      is_required: f.is_required,
      options: f.options,
      order: f.order,
    })) || []
  );
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const addField = () => {
    setFields([...fields, { name: '', field_type: 'text', is_required: false, order: fields.length }]);
  };

  const removeField = (index: number) => {
    setFields(fields.filter((_, i) => i !== index));
  };

  const updateField = (index: number, updates: Partial<FieldCreate>) => {
    const newFields = [...fields];
    newFields[index] = { ...newFields[index], ...updates };
    setFields(newFields);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setError(null);

    try {
      const data: CategoryCreate = {
        name,
        description,
        color,
        is_active: isActive,
        fields: fields.filter(f => f.name), // Only include fields with names
      };

      if (category) {
        await categoriesAPI.update(category.id, data);
      } else {
        await categoriesAPI.create(data);
      }

      onSuccess();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to save category');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4 z-50">
      <div className="bg-card border border-white/10 rounded-3xl max-w-2xl w-full max-h-[90vh] overflow-y-auto animate-fade-rise">
        <div className="sticky top-0 bg-card border-b border-white/5 px-6 py-5 flex justify-between items-center rounded-t-3xl">
          <h2 className="text-[22px] font-semibold text-text-primary">
            {category ? 'Edit category' : 'New category'}
          </h2>
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
              Name *
            </label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
              className={inputClass}
            />
          </div>

          <div>
            <label className="block text-[13px] font-medium text-text-secondary mb-2">
              Description
            </label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={3}
              className={inputClass}
            />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-[13px] font-medium text-text-secondary mb-2">
                Color
              </label>
              <input
                type="color"
                value={color}
                onChange={(e) => setColor(e.target.value)}
                className="w-full h-12 bg-surface border border-white/10 rounded-2xl cursor-pointer p-1.5"
              />
            </div>

            <div className="flex items-end pb-2">
              <label className="flex items-center gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  checked={isActive}
                  onChange={(e) => setIsActive(e.target.checked)}
                  className="w-4 h-4 accent-[#B8FF36] rounded"
                />
                <span className="text-sm font-medium text-text-primary">Active</span>
              </label>
            </div>
          </div>

          {/* Fields Section */}
          <div>
            <div className="flex justify-between items-center mb-4">
              <label className="block text-[13px] font-medium text-text-secondary">
                Fields
              </label>
              <button
                type="button"
                onClick={addField}
                className="inline-flex items-center gap-1.5 text-sm text-lime hover:text-green-secondary font-medium transition-colors duration-200"
              >
                <Plus className="w-4 h-4" strokeWidth={2} />
                Add field
              </button>
            </div>

            <div className="space-y-4">
              {fields.map((field, index) => (
                <div key={index} className="bg-surface border border-white/5 rounded-2xl p-4">
                  <div className="grid grid-cols-2 gap-3 mb-3">
                    <input
                      type="text"
                      placeholder="Field name"
                      value={field.name}
                      onChange={(e) => updateField(index, { name: e.target.value })}
                      className="px-3 py-2.5 bg-card border border-white/10 rounded-2xl text-sm text-text-primary placeholder:text-text-disabled outline-none transition-all duration-200 focus:border-lime focus:ring-2 focus:ring-lime/25"
                    />
                    <select
                      value={field.field_type}
                      onChange={(e) =>
                        updateField(index, {
                          field_type: e.target.value as FieldCreate['field_type'],
                        })
                      }
                      className="px-3 py-2.5 bg-card border border-white/10 rounded-2xl text-sm text-text-primary outline-none transition-all duration-200 focus:border-lime focus:ring-2 focus:ring-lime/25"
                    >
                      <option value="text">Text</option>
                      <option value="number">Number</option>
                      <option value="boolean">Boolean</option>
                      <option value="date">Date</option>
                      <option value="datetime">DateTime</option>
                      <option value="time">Time</option>
                      <option value="select">Select</option>
                    </select>
                  </div>

                  {field.field_type === 'select' && (
                    <input
                      type="text"
                      placeholder="Options (comma separated)"
                      value={field.options || ''}
                      onChange={(e) => updateField(index, { options: e.target.value })}
                      className="w-full px-3 py-2.5 bg-card border border-white/10 rounded-2xl text-sm text-text-primary placeholder:text-text-disabled outline-none transition-all duration-200 focus:border-lime focus:ring-2 focus:ring-lime/25 mb-3"
                    />
                  )}

                  <div className="flex justify-between items-center">
                    <label className="flex items-center gap-2 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={field.is_required}
                        onChange={(e) => updateField(index, { is_required: e.target.checked })}
                        className="w-4 h-4 accent-[#B8FF36] rounded"
                      />
                      <span className="text-sm text-text-secondary">Required</span>
                    </label>
                    <button
                      type="button"
                      onClick={() => removeField(index)}
                      className="text-danger hover:text-red-400 text-sm font-medium transition-colors duration-200"
                    >
                      Remove
                    </button>
                  </div>
                </div>
              ))}
            </div>
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
              {saving ? 'Saving...' : category ? 'Update' : 'Create'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
