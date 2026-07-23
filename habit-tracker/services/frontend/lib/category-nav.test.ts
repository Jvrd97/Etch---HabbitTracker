// [review:need-review] PHASE-01/29-category-page-nav-and-quick-add
// summary: unit tests for categorySiblings — prev/next neighbours used by the category detail pager

import { describe, expect, it } from 'bun:test';
import type { Category } from './api';
import { categorySiblings } from './category-nav';

function makeCategory(id: number, name: string): Category {
  return {
    id,
    name,
    display_mode: 'form',
    streak_mode: 'build',
    is_active: true,
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
    fields: [],
  };
}

const categories = [
  makeCategory(4, 'Meditation'),
  makeCategory(6, 'Coffee'),
  makeCategory(9, 'Running'),
];

describe('categorySiblings', () => {
  it('returns both neighbours for a middle category', () => {
    const { prev, next } = categorySiblings(categories, 6);
    expect(prev?.id).toBe(4);
    expect(next?.id).toBe(9);
  });

  it('has no prev on the first category', () => {
    const { prev, next } = categorySiblings(categories, 4);
    expect(prev).toBeNull();
    expect(next?.id).toBe(6);
  });

  it('has no next on the last category', () => {
    const { prev, next } = categorySiblings(categories, 9);
    expect(prev?.id).toBe(6);
    expect(next).toBeNull();
  });

  it('returns no neighbours for a single-item list', () => {
    const { prev, next } = categorySiblings([makeCategory(1, 'Solo')], 1);
    expect(prev).toBeNull();
    expect(next).toBeNull();
  });

  it('returns no neighbours when the current id is not in the list', () => {
    const { prev, next } = categorySiblings(categories, 999);
    expect(prev).toBeNull();
    expect(next).toBeNull();
  });

  it('returns no neighbours for an empty list', () => {
    const { prev, next } = categorySiblings([], 4);
    expect(prev).toBeNull();
    expect(next).toBeNull();
  });
});
