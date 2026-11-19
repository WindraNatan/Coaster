import React from 'react';
import { Cpu, Usb, Cloud, User } from 'lucide-react';

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
        label: 'Sesi Tidur (Standby)',
        bg: 'bg-slate-100 text-slate-700 border-slate-300',
        dot: 'bg-slate-500'
      };
    }
    if (connMode === 'sim') {
      return {
        label: 'Simulator Aktif',
        bg: 'bg-emerald-50 text-emerald-800 border-emerald-200',
        dot: 'bg-emerald-600'
      };
    }
    if (connMode === 'usb') {
      return usbConnected
        ? {
            label: 'USB ESP32 Terhubung',
            bg: 'bg-sky-50 text-sky-800 border-sky-200',
            dot: 'bg-sky-600'
          }
        : {
            label: 'USB Menunggu Port',
            bg: 'bg-amber-50 text-amber-900 border-amber-300',
            dot: 'bg-amber-600'
          };
    }
    return cloudConnected
      ? {
          label: 'Cloud Firebase Sinkron',
          bg: 'bg-sky-50 text-sky-800 border-sky-200',
          dot: 'bg-sky-600'
        }
      : {
          label: 'Cloud Perlu Masuk / Klaim',
          bg: 'bg-slate-100 text-slate-700 border-slate-300',
          dot: 'bg-slate-500'
        };
  };

  const badge = getBadgeInfo();

  return (
    <header className="sticky top-0 z-40 bg-white/95 backdrop-blur border-b border-slate-200 px-4 sm:px-6 py-2.5">
      <div className="max-w-7xl mx-auto flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3 min-w-0">
          <div className="w-8 h-8 rounded-lg bg-water-700 flex items-center justify-center text-white flex-shrink-0">
            <svg viewBox="0 0 24 24" className="w-4 h-4 fill-current" aria-hidden="true">
              <path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z" />
            </svg>
          </div>
          <div className="flex flex-wrap items-center gap-2 min-w-0">
            <h1 className="font-display text-base sm:text-lg font-bold text-slate-900 tracking-tight whitespace-nowrap">
              Smart Hydration Coaster
            </h1>
            <div
              className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium font-mono border ${badge.bg}`}
              role="status"
              aria-live="polite"
            >
              <span className={`w-2 h-2 rounded-full ${badge.dot}`} aria-hidden="true" />
              <span>{badge.label}</span>
            </div>
          </div>
        </div>

        <div className="flex items-center flex-wrap gap-2">
          <div
            className="inline-flex p-1 bg-slate-100 rounded-xl border border-slate-200 text-xs font-medium text-slate-700"
            role="group"
            aria-label="Pilih mode koneksi"
          >
            <button
              type="button"
              aria-pressed={connMode === 'sim'}
              onClick={() => setConnMode('sim')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg transition-colors ${
                connMode === 'sim'
                  ? 'bg-white text-slate-900 font-semibold shadow-sm border border-slate-200/80'
                  : 'text-slate-700 hover:text-slate-900'
              }`}
            >
              <Cpu className="w-3.5 h-3.5" aria-hidden="true" />
              <span>Simulator</span>
            </button>
            <button
              type="button"
              aria-pressed={connMode === 'usb'}
              onClick={() => setConnMode('usb')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg transition-colors ${
                connMode === 'usb'
                  ? 'bg-white text-slate-900 font-semibold shadow-sm border border-slate-200/80'
                  : 'text-slate-700 hover:text-slate-900'
              }`}
            >
              <Usb className="w-3.5 h-3.5" aria-hidden="true" />
              <span>USB Serial</span>
            </button>
            <button
              type="button"
              aria-pressed={connMode === 'cloud'}
              onClick={() => setConnMode('cloud')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg transition-colors ${
                connMode === 'cloud'
                  ? 'bg-white text-slate-900 font-semibold shadow-sm border border-slate-200/80'
                  : 'text-slate-700 hover:text-slate-900'
              }`}
            >
              <Cloud className="w-3.5 h-3.5" aria-hidden="true" />
              <span>Firebase Cloud</span>
            </button>
          </div>

          <button
            type="button"
            onClick={onOpenAuth}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 text-slate-800 text-xs font-semibold transition-colors"
          >
            <User className="w-3.5 h-3.5 text-water-700" aria-hidden="true" />
            <span className="max-w-[140px] sm:max-w-[180px] truncate">
              {userEmail ? userEmail.split('@')[0] : 'Akun & Alat'}
            </span>
          </button>
        </div>
      </div>
    </header>
  );
}
