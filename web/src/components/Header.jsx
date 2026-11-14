import React from 'react';
import { Cpu, Usb, Cloud, RotateCcw, User, CheckCircle2, AlertCircle } from 'lucide-react';

export default function Header({
  connMode,
  setConnMode,
  usbConnected,
  cloudConnected,
  userEmail,
  onOpenAuth,
  onTare
}) {
  const getBadgeInfo = () => {
    if (connMode === 'sim') {
      return {
        label: 'Simulator Aktif',
        bg: 'bg-emerald-50 text-emerald-700 border-emerald-200',
        dot: 'bg-emerald-500'
      };
    }
    if (connMode === 'usb') {
      return usbConnected
        ? {
            label: 'Live USB ESP32',
            bg: 'bg-sky-50 text-sky-700 border-sky-200',
            dot: 'bg-sky-500'
          }
        : {
            label: 'USB Menunggu Port',
            bg: 'bg-amber-50 text-amber-700 border-amber-200',
            dot: 'bg-amber-500'
          };
    }
    return cloudConnected
      ? {
          label: 'Cloud Firebase Sinkron',
          bg: 'bg-sky-50 text-sky-700 border-sky-200',
          dot: 'bg-sky-500'
        }
      : {
          label: 'Cloud Perlu Tautan',
          bg: 'bg-slate-100 text-slate-600 border-slate-200',
          dot: 'bg-slate-400'
        };
  };

  const badge = getBadgeInfo();

  return (
    <header className="sticky top-0 z-40 bg-white/90 backdrop-blur-md border-b border-slate-200/80 px-4 sm:px-6 py-3 transition-colors">
      <div className="max-w-7xl mx-auto flex flex-wrap items-center justify-between gap-3">
        {/* Brand & Live Status */}
        <div className="flex items-center gap-3 min-w-0">
          <div className="w-8 h-8 rounded-xl bg-water-600 flex items-center justify-center text-white shadow-soft shadow-water-600/30 flex-shrink-0">
            <svg viewBox="0 0 24 24" className="w-5 h-5 fill-current" aria-hidden="true">
              <path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z" />
            </svg>
          </div>
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <h1 className="text-base sm:text-lg font-bold text-slate-900 tracking-tight whitespace-nowrap">
                Smart Hydration Coaster
              </h1>
              <div
                className={`hidden sm:inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium font-mono border ${badge.bg}`}
              >
                <span className={`w-1.5 h-1.5 rounded-full ${badge.dot} animate-pulse`} />
                <span>{badge.label}</span>
              </div>
            </div>
          </div>
        </div>

        {/* Connection Switcher, Tare, User Pill */}
        <div className="flex items-center flex-wrap gap-2">
          {/* Connection Mode Switcher */}
          <div className="inline-flex p-1 bg-slate-100 rounded-full border border-slate-200/60 text-xs font-medium text-slate-600">
            <button
              type="button"
              onClick={() => setConnMode('sim')}
              className={`flex items-center gap-1 px-3 py-1.5 rounded-full transition-all ${
                connMode === 'sim'
                  ? 'bg-white text-slate-900 font-semibold shadow-sm'
                  : 'hover:text-slate-900'
              }`}
            >
              <Cpu className="w-3.5 h-3.5" />
              <span>Simulator</span>
            </button>
            <button
              type="button"
              onClick={() => setConnMode('usb')}
              className={`flex items-center gap-1 px-3 py-1.5 rounded-full transition-all ${
                connMode === 'usb'
                  ? 'bg-white text-slate-900 font-semibold shadow-sm'
                  : 'hover:text-slate-900'
              }`}
            >
              <Usb className="w-3.5 h-3.5" />
              <span>USB Serial</span>
            </button>
            <button
              type="button"
              onClick={() => setConnMode('cloud')}
              className={`flex items-center gap-1 px-3 py-1.5 rounded-full transition-all ${
                connMode === 'cloud'
                  ? 'bg-white text-slate-900 font-semibold shadow-sm'
                  : 'hover:text-slate-900'
              }`}
            >
              <Cloud className="w-3.5 h-3.5" />
              <span>Firebase Cloud</span>
            </button>
          </div>

          {/* Quick Tare Button */}
          <button
            type="button"
            onClick={onTare}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 hover:text-slate-900 text-xs font-medium transition-colors shadow-sm"
            title="Nol-kan timbangan tatakan"
          >
            <RotateCcw className="w-3.5 h-3.5 text-slate-500" />
            <span>Tare</span>
          </button>

          {/* User Auth Pill */}
          <button
            type="button"
            onClick={onOpenAuth}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 hover:text-slate-900 text-xs font-medium transition-colors shadow-sm"
          >
            <User className="w-3.5 h-3.5 text-water-600" />
            <span className="max-w-[120px] sm:max-w-[160px] truncate">
              {userEmail ? userEmail.split('@')[0] : 'Akun / Klaim'}
            </span>
          </button>
        </div>
      </div>
    </header>
  );
}
