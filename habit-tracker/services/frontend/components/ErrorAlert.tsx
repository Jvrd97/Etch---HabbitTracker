// [review:need-review] PHASE-01/adhoc-lime-redesign
// summary: Dark surface error alert with red accent and dismiss control

import { AlertCircle, X } from 'lucide-react';

interface ErrorAlertProps {
  message: string;
  onDismiss?: () => void;
}

export default function ErrorAlert({ message, onDismiss }: ErrorAlertProps) {
  return (
    <div className="bg-surface border border-danger/40 rounded-3xl p-5 flex items-start animate-fade-rise">
      <div className="p-2 rounded-2xl bg-danger/10 mr-4 flex-shrink-0">
        <AlertCircle className="w-5 h-5 text-danger" strokeWidth={2} />
      </div>
      <div className="flex-1 min-w-0">
        <h3 className="text-sm font-medium text-text-primary">Something went wrong</h3>
        <p className="text-sm text-text-secondary mt-1 break-words">{message}</p>
      </div>
      {onDismiss && (
        <button
          onClick={onDismiss}
          aria-label="Dismiss error"
          className="ml-3 p-1.5 rounded-full text-text-secondary hover:text-danger hover:bg-danger/10 transition-colors duration-200"
        >
          <X className="w-4 h-4" strokeWidth={2} />
        </button>
      )}
    </div>
  );
}
