'use client';
// [review:need-review] PHASE-01/31-web-quickfixes-md-fab-checklist
// summary: /insights page — switched to shared Markdown renderer (bold/lists/headings now parsed)

import { useEffect, useState } from 'react';
import { insightsAPI, AIReport, AIReportListItem } from '@/lib/api';
import Markdown from '@/components/Markdown';
import LoadingSpinner from '@/components/LoadingSpinner';
import ErrorAlert from '@/components/ErrorAlert';
import { Sparkles, ChevronDown, ChevronUp } from 'lucide-react';
import Link from 'next/link';

type ReportView =
  | { status: 'closed' }
  | { status: 'loading'; id: number }
  | { status: 'error'; id: number; message: string }
  | { status: 'open'; id: number; report: AIReport };

function formatDate(iso: string): string {
  return new Date(iso).toLocaleString('ru-RU', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export default function InsightsPage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [reports, setReports] = useState<AIReportListItem[]>([]);
  const [view, setView] = useState<ReportView>({ status: 'closed' });

  useEffect(() => {
    loadReports();
  }, []);

  const loadReports = async () => {
    try {
      setLoading(true);
      setError(null);
      setReports(await insightsAPI.getAll());
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load reports');
    } finally {
      setLoading(false);
    }
  };

  const openReport = async (id: number) => {
    if (view.status === 'open' && view.id === id) {
      setView({ status: 'closed' });
      return;
    }
    setView({ status: 'loading', id });
    try {
      const report = await insightsAPI.getById(id);
      setView({ status: 'open', id, report });
    } catch (err) {
      setView({
        status: 'error',
        id,
        message: err instanceof Error ? err.message : 'Failed to load report',
      });
    }
  };

  if (loading) return <LoadingSpinner size="lg" />;
  if (error) return <ErrorAlert message={error} onDismiss={() => setError(null)} />;

  return (
    <div className="space-y-8 animate-fade-rise">
      <div>
        <h1 className="text-4xl font-bold text-text-primary tracking-tight">
          AI Insights
          <span className="text-lime">.</span>
        </h1>
        <p className="mt-2 text-text-secondary">
          История AI-разборов. Новый разбор запускается с Dashboard.
        </p>
      </div>

      {reports.length === 0 ? (
        <div className="bg-card border border-white/5 rounded-3xl text-center py-16 px-6">
          <div className="inline-flex p-4 rounded-3xl bg-surface mb-4">
            <Sparkles className="w-8 h-8 text-text-disabled" strokeWidth={2} />
          </div>
          <p className="text-text-secondary">Пока нет ни одного отчёта</p>
          <Link
            href="/"
            className="mt-5 inline-flex items-center gap-2 px-6 py-3 bg-lime text-background rounded-3xl font-medium transition-all duration-200 hover:-translate-y-0.5 hover:shadow-[0_0_24px_rgba(184,255,54,0.35)]"
          >
            <Sparkles className="w-4 h-4" strokeWidth={2} />
            Запустить разбор
          </Link>
        </div>
      ) : (
        <div className="space-y-5">
          {reports.map((item) => {
            const isOpen = view.status === 'open' && view.id === item.id;
            const isLoading = view.status === 'loading' && view.id === item.id;
            const isError = view.status === 'error' && view.id === item.id;
            return (
              <div
                key={item.id}
                className="bg-card border border-white/5 rounded-3xl overflow-hidden transition-all duration-200 hover:border-lime/20"
              >
                <button
                  type="button"
                  onClick={() => openReport(item.id)}
                  aria-expanded={isOpen}
                  className="w-full text-left px-6 py-5 flex items-start justify-between gap-4"
                >
                  <div className="flex items-start gap-4 min-w-0">
                    <div className="p-2.5 rounded-2xl bg-lime/10 flex-shrink-0">
                      <Sparkles className="w-5 h-5 text-lime" strokeWidth={2} />
                    </div>
                    <div className="min-w-0">
                      <p className="text-base font-semibold text-text-primary">
                        Разбор за {item.period_days} дн.
                      </p>
                      <p className="text-[13px] text-text-secondary mt-0.5">
                        {formatDate(item.created_at)} · {item.model}
                      </p>
                      {!isOpen && (
                        <p className="text-sm text-text-disabled mt-2 line-clamp-2">
                          {item.preview}
                        </p>
                      )}
                    </div>
                  </div>
                  <span className="p-2 rounded-full text-text-secondary flex-shrink-0">
                    {isOpen ? (
                      <ChevronUp className="w-5 h-5" strokeWidth={2} />
                    ) : (
                      <ChevronDown className="w-5 h-5" strokeWidth={2} />
                    )}
                  </span>
                </button>

                {isLoading && (
                  <div className="px-6 pb-5">
                    <LoadingSpinner size="sm" />
                  </div>
                )}
                {isError && (
                  <div className="px-6 pb-5">
                    <p className="text-red-400">{view.message}</p>
                  </div>
                )}
                {isOpen && (
                  <div className="px-6 pb-6 border-t border-white/5 pt-5">
                    <Markdown content={view.report.content} />
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
