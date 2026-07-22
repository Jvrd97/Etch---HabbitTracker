// [review:need-review] PHASE-01/25-ai-reports-history
// summary: minimal markdown renderer for AI reports, extracted from Dashboard for reuse on /insights

export default function InsightMarkdown({ content }: { content: string }) {
  // Minimal MD rendering (headings + bullet lists + paragraphs), no extra deps
  const lines = content.split('\n');
  return (
    <div className="space-y-2 text-text-secondary text-base leading-relaxed">
      {lines.map((line, i) => {
        const trimmed = line.trim();
        if (trimmed === '') return null;
        if (trimmed.startsWith('### ')) {
          return (
            <h4 key={i} className="text-base font-semibold text-text-primary pt-2">
              {trimmed.slice(4)}
            </h4>
          );
        }
        if (trimmed.startsWith('## ')) {
          return (
            <h3 key={i} className="text-lg font-semibold text-lime pt-3">
              {trimmed.slice(3)}
            </h3>
          );
        }
        if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
          return (
            <p
              key={i}
              className="pl-4 relative before:content-['•'] before:absolute before:left-0 before:text-lime"
            >
              {trimmed.slice(2)}
            </p>
          );
        }
        return <p key={i}>{trimmed}</p>;
      })}
    </div>
  );
}
