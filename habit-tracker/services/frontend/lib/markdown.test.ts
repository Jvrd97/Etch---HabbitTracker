// [review:need-review] PHASE-01/31-web-quickfixes-md-fab-checklist
// summary: smoke tests for the shared markdown parser (headings, lists, bold)

import { describe, expect, it } from 'bun:test';
import { parseInline, parseMarkdown } from './markdown';

describe('parseMarkdown blocks', () => {
  it('parses headings of levels 1-4', () => {
    const blocks = parseMarkdown('# One\n## Two\n### Three\n#### Four');
    expect(blocks).toEqual([
      { type: 'heading', level: 1, tokens: [{ type: 'text', text: 'One' }] },
      { type: 'heading', level: 2, tokens: [{ type: 'text', text: 'Two' }] },
      { type: 'heading', level: 3, tokens: [{ type: 'text', text: 'Three' }] },
      { type: 'heading', level: 4, tokens: [{ type: 'text', text: 'Four' }] },
    ]);
  });

  it('parses dash and star bullets plus ordered items', () => {
    const blocks = parseMarkdown('- first\n* second\n1. third');
    expect(blocks).toEqual([
      { type: 'bullet', tokens: [{ type: 'text', text: 'first' }] },
      { type: 'bullet', tokens: [{ type: 'text', text: 'second' }] },
      { type: 'ordered', marker: '1.', tokens: [{ type: 'text', text: 'third' }] },
    ]);
  });

  it('keeps plain lines as paragraphs and drops blank lines', () => {
    const blocks = parseMarkdown('hello\n\nworld');
    expect(blocks).toEqual([
      { type: 'paragraph', tokens: [{ type: 'text', text: 'hello' }] },
      { type: 'paragraph', tokens: [{ type: 'text', text: 'world' }] },
    ]);
  });

  it('parses bold inside a heading and a list item', () => {
    const blocks = parseMarkdown('## About **sleep**\n- **8h** is fine');
    expect(blocks).toEqual([
      {
        type: 'heading',
        level: 2,
        tokens: [
          { type: 'text', text: 'About ' },
          { type: 'bold', text: 'sleep' },
        ],
      },
      {
        type: 'bullet',
        tokens: [
          { type: 'bold', text: '8h' },
          { type: 'text', text: ' is fine' },
        ],
      },
    ]);
  });
});

describe('parseInline', () => {
  it('splits bold segments out of plain text', () => {
    expect(parseInline('a **b** c')).toEqual([
      { type: 'text', text: 'a ' },
      { type: 'bold', text: 'b' },
      { type: 'text', text: ' c' },
    ]);
  });

  it('leaves an unclosed bold marker as plain text', () => {
    expect(parseInline('a **b')).toEqual([{ type: 'text', text: 'a **b' }]);
  });

  it('handles multiple bold runs', () => {
    expect(parseInline('**a** and **b**')).toEqual([
      { type: 'bold', text: 'a' },
      { type: 'text', text: ' and ' },
      { type: 'bold', text: 'b' },
    ]);
  });
});
