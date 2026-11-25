import React from 'react';
import { Thermometer, Droplets, Play, Pause } from 'lucide-react';

export default function EnvironmentSessionBar({
  temp = 27.0,
  hum = 60,
  autoDht = true,
  demo = false,
  baseMin = 30,
  effectiveMin = 30,
  sessionMl = 0,
  drinkCount = 0,
  refillCount = 0,
  cheatCount = 0,
  standby = false,
  deviceOffline = false,
  controlsDisabled = false,
  onOpenStartSession,
  onEndSession,
  sessionBusy = false
}) {
  const factorPct = baseMin > 0 ? Math.round((effectiveMin / baseMin) * 100) : 100;
  const envBadge = demo
    ? 'Demo 15 dtk'
    : autoDht
      ? `Otomatis ${factorPct}%`
      : `Tetap ${baseMin} mnt`;

  const envDesc = demo
    ? 'Jeda demo tetap 15 detik.'
    : temp >= 30
      ? 'Ruangan hangat, jeda dipercepat.'
      : temp <= 20
        ? 'Ruangan sejuk, jeda dilonggarkan.'
        : 'Suhu ruangan nyaman.';

  return (
    <section
      className="bg-surface rounded-2xl border border-hairline p-4 sm:p-5"
      aria-label="Kondisi ruangan dan sesi minum"
    >
      <div className="grid grid-cols-1 md:grid-cols-12 gap-4 md:gap-0 items-center">
        <div className="md:col-span-4 md:pr-4 md:border-r border-hairline min-w-0">
          <div className="flex items-center justify-between gap-2">
            <span className="text-xs font-semibold text-ink-soft whitespace-nowrap">
              Suhu ruangan
            </span>
            <span className="text-xs font-medium text-accent bg-accent-soft px-2 py-0.5 rounded-md whitespace-nowrap">
              {envBadge}
            </span>
          </div>
          <div className="mt-2.5 flex items-center gap-4">
            <div className="flex items-center gap-1.5 whitespace-nowrap">
              <Thermometer className="w-4 h-4 text-warn flex-shrink-0" strokeWidth={1.75} aria-hidden="true" />
              <span className="text-lg font-semibold text-ink">
                <span className="font-mono tabular-nums">{Number(temp).toFixed(1)}</span>
                <span> °C</span>
              </span>
            </div>
            <div className="flex items-center gap-1.5 whitespace-nowrap">
              <Droplets className="w-4 h-4 text-accent flex-shrink-0" strokeWidth={1.75} aria-hidden="true" />
              <span className="text-lg font-semibold text-ink">
                <span className="font-mono tabular-nums">{Math.round(hum)}</span>
                <span>%</span>
              </span>
            </div>
          </div>
          <p className="text-xs text-ink-soft mt-1.5">
            {envDesc}
          </p>
        </div>

        <div className="md:col-span-5 md:px-5 md:border-r border-hairline pt-3 md:pt-0 border-t md:border-t-0 min-w-0">
          <div className="flex items-center justify-between mb-2.5">
            <span className="text-xs font-semibold text-ink-soft">
              Sesi saat ini
            </span>
            <span className="text-sm font-semibold text-accent">
              <span className="font-mono tabular-nums">{Math.round(sessionMl)}</span>
              <span> ml</span>
            </span>
          </div>
          <div className="grid grid-cols-3 divide-x divide-hairline bg-subtle rounded-xl py-2.5">
            <div className="px-1.5 sm:px-2 text-center min-w-0">
              <div className="text-base font-semibold text-ok">
                <span className="font-mono tabular-nums">{drinkCount}</span>
                <span>x</span>
              </div>
              <div className="text-xs text-ink-soft mt-0.5 leading-tight">Minum</div>
            </div>
            <div className="px-1.5 sm:px-2 text-center min-w-0">
              <div className="text-base font-semibold text-accent">
                <span className="font-mono tabular-nums">{refillCount}</span>
                <span>x</span>
              </div>
              <div className="text-xs text-ink-soft mt-0.5 leading-tight">Isi ulang</div>
            </div>
            <div className="px-1.5 sm:px-2 text-center min-w-0">
              <div className="text-base font-semibold text-warn">
                <span className="font-mono tabular-nums">{cheatCount}</span>
                <span>x</span>
              </div>
              <div className="text-xs text-ink-soft mt-0.5 leading-tight">Tegukan kecil</div>
            </div>
          </div>
        </div>

        <div className="md:col-span-3 md:pl-4 pt-3 md:pt-0 border-t md:border-t-0 border-hairline flex flex-col justify-between gap-2 min-w-0">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-ink-soft">Status sesi</span>
            <span
              className={`text-xs font-semibold ${
                deviceOffline ? 'text-danger' : standby ? 'text-ink-muted' : 'text-ok'
              }`}
            >
              {deviceOffline ? 'Terputus' : standby ? 'Istirahat' : 'Aktif'}
            </span>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-1 gap-2">
            <button
              type="button"
              disabled={sessionBusy || controlsDisabled}
              onClick={onOpenStartSession}
              className="w-full inline-flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl bg-accent hover:bg-accent-hover disabled:opacity-50 disabled:cursor-not-allowed text-accent-ink text-xs font-semibold whitespace-nowrap transition-colors duration-150"
            >
              <Play className="w-3.5 h-3.5" strokeWidth={1.75} aria-hidden="true" />
              <span>Mulai sesi</span>
            </button>
            <button
              type="button"
              disabled={sessionBusy || standby || controlsDisabled}
              onClick={onEndSession}
              className="w-full inline-flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl border border-control bg-surface hover:bg-subtle disabled:opacity-50 disabled:cursor-not-allowed text-ink text-xs font-semibold whitespace-nowrap transition-colors duration-150"
            >
              <Pause className="w-3.5 h-3.5" strokeWidth={1.75} aria-hidden="true" />
              <span>Istirahatkan</span>
            </button>
          </div>
        </div>
      </div>
    </section>
  );
}
