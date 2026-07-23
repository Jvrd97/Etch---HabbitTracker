// [review:need-review] PHASE-01/28-today-avoid-card
// summary: pure Today-page category partitioning (avoid streak / checklist / quick-form) + field helpers

import type { Category, Field } from './api';

/** First number field of a category, ordered, or undefined if none. */
export function firstNumberField(category: Category): Field | undefined {
  return [...category.fields]
    .sort((a, b) => a.order - b.order)
    .find((f) => f.field_type === 'number');
}

/** Boolean fields of a category, ordered. */
export function booleanFields(category: Category): Field[] {
  return [...category.fields]
    .filter((f) => f.field_type === 'boolean')
    .sort((a, b) => a.order - b.order);
}

/** An avoid category plus its optional "how much" number field. */
export interface AvoidItem {
  category: Category;
  numberField: Field | undefined;
}

/** A quick-input category paired with the number field it increments. */
export interface QuickFormItem {
  category: Category;
  numberField: Field;
}

/** Today-page categories split by how they should be rendered. */
export interface TodayGroups {
  avoid: AvoidItem[];
  checklist: Category[];
  quickForm: QuickFormItem[];
}

/**
 * Route each category to its Today-page renderer. Avoid-streak categories win
 * first (they show a streak card, never a quick input), then checklist
 * categories with boolean fields, then number categories as quick inputs. A
 * checklist saved before boolean fields were required falls through to
 * quick-form, matching the legacy fallback the page relied on.
 */
export function partitionTodayCategories(categories: Category[]): TodayGroups {
  const avoid: AvoidItem[] = [];
  const checklist: Category[] = [];
  const quickForm: QuickFormItem[] = [];

  for (const category of categories) {
    if (category.streak_mode === 'avoid') {
      avoid.push({ category, numberField: firstNumberField(category) });
      continue;
    }

    if (category.display_mode === 'checklist' && booleanFields(category).length > 0) {
      checklist.push(category);
      continue;
    }

    const numberField = firstNumberField(category);
    if (
      numberField &&
      (category.display_mode === 'form' || booleanFields(category).length === 0)
    ) {
      quickForm.push({ category, numberField });
    }
  }

  return { avoid, checklist, quickForm };
}
