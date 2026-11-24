import React from 'react';
import { SlidersHorizontal, Cable, Cloud, User } from 'lucide-react';

export default function Header({
  connMode,
  setConnMode,
  usbConnected,
  cloudConnected,
  standby,
  userEmail,
  onOpenAuth
}) {
  const getBadgeInfo = () => {
    if (standby) {
      return {
        label: 'Mode istirahat',
        cls: 'bg-subtle text-ink-soft border-hairline',
        dot: 'bg-ink-muted'
      };
    }
    if (connMode === 'sim') {
      return {
        label: 'Mode simulasi',
        cls: 'bg-ok-bg text-ok border-ok-border',
        dot: 'bg-ok'
      };
    }
    if (connMode === 'usb') {
      return usbConnected
        ? {
            label: 'Tersambung lewat kabel',
            cls: 'bg-ok-bg text-ok border-ok-border',
            dot: 'bg-ok'
          }
        : {
            label: 'Menunggu kabel USB',
            cls: 'bg-warn-bg text-warn border-warn-border',
            dot: 'bg-warn'
          };
    }
    return cloudConnected
      ? {
          label: 'Tersambung online',
          cls: 'bg-ok-bg text-ok border-ok-border',
          dot: 'bg-ok'
        }
      : {
          label: 'Belum terhubung',
          cls: 'bg-subtle text-ink-soft border-hairline',
          dot: 'bg-ink-muted'
        };
  };

  const badge = getBadgeInfo();

  return (
    <header className="sticky top-0 z-40 bg-surface border-b border-hairline px-4 sm:px-6 py-3">
      <div className="max-w-7xl mx-auto flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3 min-w-0">
          <div className="w-8 h-8 rounded-lg bg-accent flex items-center justify-center text-accent-ink flex-shrink-0">
            <svg viewBox="0 0 24 24" className="w-4 h-4 fill-current" aria-hidden="true">
              <path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z" />
            </svg>
          </div>
          <div className="flex flex-wrap items-center gap-2.5 min-w-0">
            <h1 className="text-base sm:text-lg font-semibold text-ink tracking-tight whitespace-nowrap">
              Smart Hydration Coaster
            </h1>
            <div
              className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium border whitespace-nowrap ${badge.cls}`}
              role="status"
              aria-live="polite"
            >
              <span className={`w-1.5 h-1.5 rounded-full ${badge.dot}`} aria-hidden="true" />
              <span>{badge.label}</span>
            </div>
          </div>
        </div>

        <div className="flex items-center flex-wrap gap-2">
          <div
            className="inline-flex p-1 bg-subtle rounded-xl border border-hairline text-xs font-medium"
            role="group"
            aria-label="Sumber koneksi tatakan"
          >
            <button
              type="button"
              aria-pressed={connMode === 'sim'}
              onClick={() => setConnMode('sim')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg whitespace-nowrap transition-colors duration-150 ${
                connMode === 'sim'
                  ? 'bg-surface text-ink font-semibold border border-hairline'
                  : 'text-ink-soft hover:text-ink'
              }`}
            >
              <SlidersHorizontal className="w-3.5 h-3.5" strokeWidth={1.75} aria-hidden="true" />
              <span>Simulasi</span>
            </button>
            <button
              type="button"
              aria-pressed={connMode === 'usb'}
              onClick={() => setConnMode('usb')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg whitespace-nowrap transition-colors duration-150 ${
                connMode === 'usb'
                  ? 'bg-surface text-ink font-semibold border border-hairline'
                  : 'text-ink-soft hover:text-ink'
              }`}
            >
              <Cable className="w-3.5 h-3.5" strokeWidth={1.75} aria-hidden="true" />
              <span>Kabel USB</span>
            </button>
            <button
              type="button"
              aria-pressed={connMode === 'cloud'}
              onClick={() => setConnMode('cloud')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg whitespace-nowrap transition-colors duration-150 ${
                connMode === 'cloud'
                  ? 'bg-surface text-ink font-semibold border border-hairline'
                  : 'text-ink-soft hover:text-ink'
              }`}
            >
              <Cloud className="w-3.5 h-3.5" strokeWidth={1.75} aria-hidden="true" />
              <span>Online</span>
            </button>
          </div>

          <button
            type="button"
            onClick={onOpenAuth}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl border border-control bg-surface hover:bg-subtle text-ink text-xs font-semibold whitespace-nowrap transition-colors duration-150"
          >
            <User className="w-3.5 h-3.5 text-accent" strokeWidth={1.75} aria-hidden="true" />
            <span className="max-w-[140px] sm:max-w-[180px] truncate">
              {userEmail ? userEmail.split('@')[0] : 'Masuk'}
            </span>
          </button>
        </div>
      </div>
    </header>
  );
}
