// [review:need-review] PHASE-01/28-today-avoid-card
// summary: unit tests for Today category partitioning (avoid vs checklist vs quick-form)

import { describe, expect, it } from 'bun:test';
import type { Category, Field } from './api';
import { partitionTodayCategories } from './today-categories';

function field(overrides: Partial<Field>): Field {
  return {
    id: 1,
    category_id: 1,
    name: 'Field',
    field_type: 'text',
    is_required: false,
    order: 0,
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
    ...overrides,
  };
}

function category(overrides: Partial<Category>): Category {
  return {
    id: 1,
    name: 'Category',
    display_mode: 'form',
    streak_mode: 'build',
    is_active: true,
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
    fields: [],
    ...overrides,
  };
}

describe('partitionTodayCategories', () => {
  it('routes avoid categories to the avoid group, not quick-form', () => {
    const avoid = category({
      id: 10,
      streak_mode: 'avoid',
      display_mode: 'form',
      fields: [field({ id: 100, field_type: 'number', name: 'Amount' })],
    });

    const groups = partitionTodayCategories([avoid]);

    expect(groups.avoid.map((a) => a.category.id)).toEqual([10]);
    expect(groups.quickForm).toHaveLength(0);
    expect(groups.checklist).toHaveLength(0);
  });

  it('keeps a build number category as a quick-form item with its number field', () => {
    const build = category({
      id: 20,
      streak_mode: 'build',
      display_mode: 'form',
      fields: [field({ id: 200, field_type: 'number', name: 'Cups' })],
    });

    const groups = partitionTodayCategories([build]);

    expect(groups.quickForm).toHaveLength(1);
    expect(groups.quickForm[0].category.id).toBe(20);
    expect(groups.quickForm[0].numberField.id).toBe(200);
    expect(groups.avoid).toHaveLength(0);
  });

  it('routes a checklist category with boolean fields to the checklist group', () => {
    const checklist = category({
      id: 30,
      display_mode: 'checklist',
      streak_mode: 'build',
      fields: [field({ id: 300, field_type: 'boolean', name: 'Done' })],
    });

    const groups = partitionTodayCategories([checklist]);

    expect(groups.checklist.map((c) => c.id)).toEqual([30]);
    expect(groups.quickForm).toHaveLength(0);
  });

  it('exposes the number field on avoid categories when present', () => {
    const avoid = category({
      id: 40,
      streak_mode: 'avoid',
      fields: [field({ id: 400, field_type: 'number', name: 'Cigarettes' })],
    });

    const groups = partitionTodayCategories([avoid]);

    expect(groups.avoid[0].numberField?.id).toBe(400);
  });

  it('leaves the number field undefined on avoid categories that have none', () => {
    const avoid = category({
      id: 50,
      streak_mode: 'avoid',
      fields: [field({ id: 500, field_type: 'text', name: 'Note' })],
    });

    const groups = partitionTodayCategories([avoid]);

    expect(groups.avoid[0].numberField).toBeUndefined();
  });
});
