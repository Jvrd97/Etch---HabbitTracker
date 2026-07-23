// [review:need-review] PHASE-01/31-web-quickfixes-md-fab-checklist
// summary: pure markdown parser (headings 1-4, bullet/ordered lists, bold) shared by Journal and Insights

export type InlineToken =
  | { type: 'text'; text: string }
  | { type: 'bold'; text: string };

export type HeadingLevel = 1 | 2 | 3 | 4;

export type MarkdownBlock =
  | { type: 'heading'; level: HeadingLevel; tokens: InlineToken[] }
  | { type: 'bullet'; tokens: InlineToken[] }
  | { type: 'ordered'; marker: string; tokens: InlineToken[] }
  | { type: 'paragraph'; tokens: InlineToken[] };

const HEADING_RE = /^(#{1,4})\s+(.*)$/;
const BULLET_RE = /^[-*]\s+(.*)$/;
const ORDERED_RE = /^(\d+\.)\s+(.*)$/;
const BOLD_RE = /\*\*([^*]+)\*\*/g;

export function parseInline(text: string): InlineToken[] {
  const tokens: InlineToken[] = [];
  let lastIndex = 0;
  for (const match of text.matchAll(BOLD_RE)) {
    const index = match.index ?? 0;
    if (index > lastIndex) {
      tokens.push({ type: 'text', text: text.slice(lastIndex, index) });
    }
    tokens.push({ type: 'bold', text: match[1] });
    lastIndex = index + match[0].length;
  }
  if (lastIndex < text.length) {
    tokens.push({ type: 'text', text: text.slice(lastIndex) });
  }
  return tokens;
}

export function parseMarkdown(content: string): MarkdownBlock[] {
  const blocks: MarkdownBlock[] = [];
  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (trimmed === '') continue;

    const heading = HEADING_RE.exec(trimmed);
    if (heading) {
      blocks.push({
        type: 'heading',
        level: heading[1].length as HeadingLevel,
        tokens: parseInline(heading[2]),
      });
      continue;
    }

    const bullet = BULLET_RE.exec(trimmed);
    if (bullet) {
      blocks.push({ type: 'bullet', tokens: parseInline(bullet[1]) });
      continue;
    }

    const ordered = ORDERED_RE.exec(trimmed);
    if (ordered) {
      blocks.push({
        type: 'ordered',
        marker: ordered[1],
        tokens: parseInline(ordered[2]),
      });
      continue;
    }

    blocks.push({ type: 'paragraph', tokens: parseInline(trimmed) });
  }
  return blocks;
}
