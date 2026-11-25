import React from 'react';
import { SlidersHorizontal, Cable, Cloud, User } from 'lucide-react';

export default function Header({
  connMode,
  setConnMode,
  usbConnected,
  cloudConnected,
  deviceOffline = false,
  standby,
  userEmail,
  onOpenAuth
}) {
  const getBadgeInfo = () => {
    if (deviceOffline) {
      return {
        label: 'Alat terputus',
        cls: 'bg-danger-bg text-danger border-danger-border',
        dot: 'bg-danger'
      };
    }
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
    <header className="static lg:sticky lg:top-0 z-40 bg-surface border-b border-hairline px-3 sm:px-6 py-2.5 sm:py-3">
      <div className="max-w-7xl mx-auto flex flex-col lg:flex-row lg:items-center lg:justify-between gap-2.5 lg:gap-3">
        <div className="flex items-center justify-between gap-2 min-w-0">
          <div className="flex items-center gap-2.5 sm:gap-3 min-w-0">
            <img
              src="./icon-192.png"
              alt=""
              aria-hidden="true"
              width="36"
              height="36"
              className="w-9 h-9 rounded-lg object-cover flex-shrink-0"
            />
            <div className="flex flex-col sm:flex-row sm:items-center gap-0.5 sm:gap-2.5 min-w-0">
              <h1 className="text-sm sm:text-lg font-semibold text-ink tracking-tight truncate">
                Smart Hydration Coaster
              </h1>
              <div
                className={`self-start sm:self-auto inline-flex items-center gap-1.5 px-2 sm:px-2.5 py-0.5 rounded-full text-[11px] sm:text-xs font-medium border whitespace-nowrap ${badge.cls}`}
                role="status"
                aria-live="polite"
              >
                <span className={`w-1.5 h-1.5 rounded-full ${badge.dot}`} aria-hidden="true" />
                <span>{badge.label}</span>
              </div>
            </div>
          </div>

          <button
            type="button"
            onClick={onOpenAuth}
            className="lg:hidden flex-shrink-0 inline-flex items-center gap-1.5 px-2.5 sm:px-3 py-1.5 rounded-xl border border-control bg-surface hover:bg-subtle text-ink text-xs font-semibold whitespace-nowrap transition-colors duration-150"
          >
            <User className="w-3.5 h-3.5 text-accent" strokeWidth={1.75} aria-hidden="true" />
            <span className="max-w-[84px] sm:max-w-[140px] truncate">
              {userEmail ? userEmail.split('@')[0] : 'Masuk'}
            </span>
          </button>
        </div>

        <div className="flex items-center gap-2 w-full lg:w-auto">
          <div
            className="grid grid-cols-3 w-full sm:inline-flex sm:w-auto p-1 bg-subtle rounded-xl border border-hairline text-xs font-medium"
            role="group"
            aria-label="Sumber koneksi tatakan"
          >
            <button
              type="button"
              aria-pressed={connMode === 'sim'}
              onClick={() => setConnMode('sim')}
              className={`flex items-center justify-center gap-1.5 px-2 sm:px-3 py-1.5 rounded-lg min-w-0 whitespace-nowrap transition-colors duration-150 ${
                connMode === 'sim'
                  ? 'bg-surface text-ink font-semibold border border-hairline'
                  : 'text-ink-soft hover:text-ink'
              }`}
            >
              <SlidersHorizontal className="w-3.5 h-3.5 flex-shrink-0" strokeWidth={1.75} aria-hidden="true" />
              <span>Simulasi</span>
            </button>
            <button
              type="button"
              aria-pressed={connMode === 'usb'}
              onClick={() => setConnMode('usb')}
              className={`flex items-center justify-center gap-1.5 px-2 sm:px-3 py-1.5 rounded-lg min-w-0 whitespace-nowrap transition-colors duration-150 ${
                connMode === 'usb'
                  ? 'bg-surface text-ink font-semibold border border-hairline'
                  : 'text-ink-soft hover:text-ink'
              }`}
            >
              <Cable className="w-3.5 h-3.5 flex-shrink-0" strokeWidth={1.75} aria-hidden="true" />
              <span className="sm:hidden">USB</span>
              <span className="hidden sm:inline">Kabel USB</span>
            </button>
            <button
              type="button"
              aria-pressed={connMode === 'cloud'}
              onClick={() => setConnMode('cloud')}
              className={`flex items-center justify-center gap-1.5 px-2 sm:px-3 py-1.5 rounded-lg min-w-0 whitespace-nowrap transition-colors duration-150 ${
                connMode === 'cloud'
                  ? 'bg-surface text-ink font-semibold border border-hairline'
                  : 'text-ink-soft hover:text-ink'
              }`}
            >
              <Cloud className="w-3.5 h-3.5 flex-shrink-0" strokeWidth={1.75} aria-hidden="true" />
              <span>Online</span>
            </button>
          </div>

          <button
            type="button"
            onClick={onOpenAuth}
            className="hidden lg:inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl border border-control bg-surface hover:bg-subtle text-ink text-xs font-semibold whitespace-nowrap transition-colors duration-150"
          >
            <User className="w-3.5 h-3.5 text-accent" strokeWidth={1.75} aria-hidden="true" />
            <span className="max-w-[140px] xl:max-w-[180px] truncate">
              {userEmail ? userEmail.split('@')[0] : 'Masuk'}
            </span>
          </button>
        </div>
      </div>
    </header>
  );
}
