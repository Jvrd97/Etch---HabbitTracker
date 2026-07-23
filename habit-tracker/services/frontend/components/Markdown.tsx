// [review:need-review] PHASE-01/31-web-quickfixes-md-fab-checklist
// summary: shared markdown renderer (replaces InsightMarkdown) — headings, lists, bold; used by Dashboard, Insights and Journal

import { InlineToken, MarkdownBlock, parseMarkdown } from '@/lib/markdown';

function Inline({ tokens }: { tokens: InlineToken[] }) {
  return (
    <>
      {tokens.map((token, i) =>
        token.type === 'bold' ? (
          <strong key={i} className="font-semibold text-text-primary">
            {token.text}
          </strong>
        ) : (
          <span key={i}>{token.text}</span>
        )
      )}
    </>
  );
}

function Block({ block }: { block: MarkdownBlock }) {
  switch (block.type) {
    case 'heading':
      if (block.level <= 2) {
        return (
          <h3 className="text-lg font-semibold text-lime pt-3">
            <Inline tokens={block.tokens} />
          </h3>
        );
      }
      return (
        <h4 className="text-base font-semibold text-text-primary pt-2">
          <Inline tokens={block.tokens} />
        </h4>
      );
    case 'bullet':
      return (
        <p className="pl-4 relative before:content-['•'] before:absolute before:left-0 before:text-lime">
          <Inline tokens={block.tokens} />
        </p>
      );
    case 'ordered':
      return (
        <p className="pl-6 relative">
          <span className="absolute left-0 text-lime">{block.marker}</span>
          <Inline tokens={block.tokens} />
        </p>
      );
    case 'paragraph':
      return (
        <p>
          <Inline tokens={block.tokens} />
        </p>
      );
  }
}

export default function Markdown({ content }: { content: string }) {
  return (
    <div className="space-y-2 text-text-secondary text-base leading-relaxed">
      {parseMarkdown(content).map((block, i) => (
        <Block key={i} block={block} />
      ))}
    </div>
  );
}
