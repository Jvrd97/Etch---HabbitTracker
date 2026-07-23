'use client';
// [review:need-review] PHASE-01/27-streak-mode-endpoint
// summary: avoid-streak block (current/best streak, last relapse) for the category page

import { Flame } from 'lucide-react';
import type { CategoryStreak } from '@/lib/api';
import { formatDays, formatLastRelapse } from '@/lib/streak-format';

interface StreakCardProps {
  streak: CategoryStreak;
}

export default function StreakCard({ streak }: StreakCardProps) {
  return (
    <div className="bg-card border border-white/5 rounded-3xl p-6">
      <div className="flex items-center gap-3 mb-5">
        <div className="p-2.5 rounded-2xl bg-lime/10">
          <Flame className="w-5 h-5 text-lime" strokeWidth={2} />
        </div>
        <h2 className="text-lg font-medium text-text-primary">Streak</h2>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-5">
        <div>
          <p className="text-[13px] font-medium text-text-secondary mb-1">
            Current streak
          </p>
          <p className="text-3xl font-bold text-lime tracking-tight">
            {formatDays(streak.current_streak)}
          </p>
        </div>
        <div>
          <p className="text-[13px] font-medium text-text-secondary mb-1">Best</p>
          <p className="text-3xl font-bold text-text-primary tracking-tight">
            {formatDays(streak.best_streak)}
          </p>
        </div>
        <div>
          <p className="text-[13px] font-medium text-text-secondary mb-1">
            Last relapse
          </p>
          <p className="text-xl font-medium text-text-primary">
            {formatLastRelapse(streak.last_relapse_date)}
          </p>
        </div>
      </div>
    </div>
  );
}
