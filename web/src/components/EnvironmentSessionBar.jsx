import React from 'react';
import { Thermometer, Droplets, Play, Square } from 'lucide-react';

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
  onOpenStartSession,
  onEndSession,
  sessionBusy = false
}) {
  const factorPct = baseMin > 0 ? Math.round((effectiveMin / baseMin) * 100) : 100;
  const envBadge = demo
    ? 'Demo 15 dtk'
    : autoDht
      ? `Adaptif ${factorPct}%`
      : `Manual ${baseMin} mnt`;

  return (
    <section
      className="bg-white rounded-2xl border border-slate-200 shadow-soft p-4 sm:p-5"
      aria-label="Kondisi ruang dan kendali sesi"
    >
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-4 items-center">
        {/* 1. Suhu & Kelembapan Ruang */}
        <div className="lg:col-span-4 lg:pr-4 lg:border-r border-slate-200/80">
          <div className="flex items-center justify-between gap-2">
            <span className="text-xs font-semibold text-slate-700 whitespace-nowrap">
              Kondisi Ruang
            </span>
            <span className="text-[11px] font-medium text-water-800 bg-sky-50 border border-sky-200 px-2 py-0.5 rounded-md whitespace-nowrap">
              {envBadge}
            </span>
          </div>
          <div className="mt-2.5 flex items-center gap-4">
            <div className="flex items-center gap-1.5 whitespace-nowrap">
              <Thermometer className="w-4 h-4 text-amber-700 flex-shrink-0" aria-hidden="true" />
              <span className="text-lg font-bold text-slate-900 font-mono tabular-nums">
                {Number(temp).toFixed(1)} °C
              </span>
            </div>
            <div className="flex items-center gap-1.5 whitespace-nowrap">
              <Droplets className="w-4 h-4 text-water-700 flex-shrink-0" aria-hidden="true" />
              <span className="text-lg font-bold text-slate-900 font-mono tabular-nums">
                {Math.round(hum)}% RH
              </span>
            </div>
          </div>
          <p className="text-xs text-slate-600 mt-1.5">
            {temp >= 30
              ? 'Ruangan hangat, interval dipercepat.'
              : temp <= 20
                ? 'Ruangan sejuk, interval dilonggarkan.'
                : 'Suhu & kelembapan ruang normal.'}
          </p>
        </div>

        {/* 2. Aktivitas Sesi Berjalan */}
        <div className="lg:col-span-5 lg:px-2 lg:border-r border-slate-200/80">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-semibold text-slate-700">
              Akumulasi Sesi Alat
            </span>
            <span className="text-sm font-bold text-water-800 font-mono tabular-nums">
              {Math.round(sessionMl)} ml
            </span>
          </div>
          <div className="grid grid-cols-3 gap-2">
            <div className="rounded-xl bg-slate-50 border border-slate-200/80 px-2.5 py-2 text-center">
              <div className="text-base font-bold text-emerald-800 font-mono tabular-nums">
                {drinkCount}x
              </div>
              <div className="text-[11px] font-medium text-slate-600">Minum</div>
            </div>
            <div className="rounded-xl bg-slate-50 border border-slate-200/80 px-2.5 py-2 text-center">
              <div className="text-base font-bold text-water-800 font-mono tabular-nums">
                {refillCount}x
              </div>
              <div className="text-[11px] font-medium text-slate-600">Isi ulang</div>
            </div>
            <div className="rounded-xl bg-slate-50 border border-slate-200/80 px-2.5 py-2 text-center">
              <div className="text-base font-bold text-amber-900 font-mono tabular-nums">
                {cheatCount}x
              </div>
              <div className="text-[11px] font-medium text-slate-600">Tegukan kecil</div>
            </div>
          </div>
        </div>

        {/* 3. Kendali Sesi (Mulai Sesi / Akhiri Sesi) */}
        <div className="lg:col-span-3 flex flex-col justify-between gap-2">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-700">Status Sesi</span>
            <span
              className={`text-xs font-semibold font-mono ${
                standby ? 'text-slate-600' : 'text-emerald-800'
              }`}
            >
              {standby ? 'Tidur (Standby)' : 'Aktif'}
            </span>
          </div>
          <div className="grid grid-cols-2 lg:grid-cols-1 gap-2">
            <button
              type="button"
              disabled={sessionBusy}
              onClick={onOpenStartSession}
              className="w-full inline-flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl bg-water-700 hover:bg-water-800 disabled:opacity-50 text-white text-xs font-semibold transition-colors"
            >
              <Play className="w-3.5 h-3.5" aria-hidden="true" />
              <span>Mulai Sesi</span>
            </button>
            <button
              type="button"
              disabled={sessionBusy || standby}
              onClick={onEndSession}
              className="w-full inline-flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl border border-slate-300 bg-white hover:bg-slate-50 disabled:opacity-50 text-slate-800 text-xs font-semibold transition-colors"
            >
              <Square className="w-3.5 h-3.5" aria-hidden="true" />
              <span>Akhiri Sesi</span>
            </button>
          </div>
        </div>
      </div>
    </section>
  );
}
