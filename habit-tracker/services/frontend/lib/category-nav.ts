// [review:need-review] PHASE-01/29-category-page-nav-and-quick-add
// summary: pure helper resolving prev/next categories for the category detail pager

import type { Category } from './api';

export interface CategorySiblings {
  prev: Category | null;
  next: Category | null;
}

/**
 * Neighbours of `currentId` in `categories`, in list order.
 *
 * Does not wrap around: the first category has no prev, the last has no next.
 * An unknown id (or an empty list) yields no neighbours rather than guessing a
 * position, so a stale/deleted category cannot silently page into another one.
 */
export function categorySiblings(
  categories: Category[],
  currentId: number
): CategorySiblings {
  const index = categories.findIndex((category) => category.id === currentId);
  if (index === -1) return { prev: null, next: null };

  return {
    prev: categories[index - 1] ?? null,
    next: categories[index + 1] ?? null,
  };
}
