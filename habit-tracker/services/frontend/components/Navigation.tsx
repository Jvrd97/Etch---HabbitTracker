'use client';
// [review:need-review] PHASE-01/25-ai-reports-history
// summary: added Insights nav item (AI reports history)

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Home, FolderKanban, CalendarDays, BookOpen, Sun, Table2, Sparkles } from 'lucide-react';

const navItems = [
  { name: 'Dashboard', href: '/', icon: Home },
  { name: 'Today', href: '/today', icon: Sun },
  { name: 'Table', href: '/table', icon: Table2 },
  { name: 'Categories', href: '/categories', icon: FolderKanban },
  { name: 'Entries', href: '/entries', icon: CalendarDays },
  { name: 'Journal', href: '/journal', icon: BookOpen },
  { name: 'Insights', href: '/insights', icon: Sparkles },
];

export default function Navigation() {
  const pathname = usePathname();

  return (
    <nav className="sticky top-0 z-40 bg-background/90 backdrop-blur-md border-b border-white/5">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          <Link href="/" className="flex items-center gap-2 select-none">
            <span className="text-xl font-bold tracking-tight text-text-primary">
              Habit Tracker
            </span>
            <span
              aria-hidden="true"
              className="w-2 h-2 rounded-full bg-lime shadow-[0_0_10px_rgba(184,255,54,0.8)]"
            />
          </Link>

          <div className="flex items-center gap-1 sm:gap-2">
            {navItems.map((item) => {
              const Icon = item.icon;
              const isActive = pathname === item.href;
              return (
                <Link
                  key={item.name}
                  href={item.href}
                  aria-current={isActive ? 'page' : undefined}
                  className={`inline-flex items-center gap-2 px-3 sm:px-4 py-2 rounded-full text-sm font-medium transition-all duration-200 ${
                    isActive
                      ? 'bg-lime text-background shadow-[0_0_18px_rgba(184,255,54,0.25)]'
                      : 'text-text-secondary hover:text-text-primary hover:bg-white/5'
                  }`}
                >
                  <Icon className="w-4 h-4" strokeWidth={2} />
                  <span className="hidden sm:inline">{item.name}</span>
                </Link>
              );
            })}
          </div>
        </div>
      </div>
    </nav>
  );
}
