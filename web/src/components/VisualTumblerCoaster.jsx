import React from 'react';
import { stateBadgeLabel } from '../protocol';

const FSM_META = {
  IDLE: {
    desc: 'Letakkan gelas di tatakan untuk memulai pemantauan.',
    badge: 'bg-slate-100 text-slate-800 border-slate-300',
    led: '#64748B'
  },
  STABLE: {
    desc: 'Beban stabil 1,5 detik. Menyiapkan siklus hitung mundur.',
    badge: 'bg-emerald-50 text-emerald-800 border-emerald-300',
    led: '#059669'
  },
  TIMING: {
    desc: 'Siklus pengingat aktif berjalan.',
    badge: 'bg-sky-50 text-sky-800 border-sky-300',
    led: '#0284C7'
  },
  ALERT_DRINK: {
    desc: 'Waktunya minum air. Angkat gelas dan minum minimal 20 ml.',
    badge: 'bg-amber-50 text-amber-900 border-amber-300 animate-pulse',
    led: '#D97706'
  },
  ALERT_CHEAT: {
    desc: 'Berat kembali tanpa minum cukup (< 20 ml). Silakan minum lagi.',
    badge: 'bg-rose-50 text-rose-900 border-rose-300 animate-pulse',
    led: '#DC2626'
  },
  ALERT_EMPTY_CUP: {
    desc: 'Air di dalam gelas hampir habis. Silakan isi ulang.',
    badge: 'bg-rose-50 text-rose-900 border-rose-300 animate-pulse',
    led: '#DC2626'
  },
  ALERT_MISSING_CUP: {
    desc: 'Gelas belum kembali ke tatakan. Letakkan kembali setelah minum.',
    badge: 'bg-amber-50 text-amber-900 border-amber-300 animate-pulse',
    led: '#D97706'
  },
  ALERT_REFILL: {
    desc: 'Gelas kosong atau belum kembali ke tatakan. Silakan isi ulang.',
    badge: 'bg-rose-50 text-rose-900 border-rose-300 animate-pulse',
    led: '#DC2626'
  },
  LIFTED: {
    desc: 'Gelas sedang diangkat dari tatakan.',
    badge: 'bg-sky-50 text-sky-800 border-sky-300',
    led: '#0284C7'
  }
};

export default function VisualTumblerCoaster({
  stateString = 'IDLE',
  weight = 0,
  isStable = false,
  standby = false,
  cupMl = 0,
  cupMax = 500,
  emptyCup = 130,
  connMode = 'sim',
  onLift,
  onPlace,
  onSip,
  onPour,
  onEmpty
}) {
  const meta = standby
    ? {
        desc: 'Sesi sedang tidur (standby). Tekan Mulai Sesi untuk mengaktifkan pengingat.',
        badge: 'bg-slate-100 text-slate-700 border-slate-300',
        led: '#94A3B8'
      }
    : (FSM_META[stateString] || FSM_META.IDLE);

  const badgeText = standby ? 'STANDBY' : stateBadgeLabel(stateString);
  const isLifted = stateString === 'LIFTED' || stateString === 'ALERT_MISSING_CUP' || weight < 25;

  const maxWaterH = 116;
  const waterPct = isLifted ? 0 : Math.min(1, Math.max(0, cupMl / cupMax));
  const waterH = Math.round(waterPct * maxWaterH);
  const waterY = 146 - waterH;

  const stabilityLabel = standby
    ? 'Sesi tidur'
    : weight < 25
      ? 'Tanpa beban'
      : isStable
        ? 'Stabil (±3 g)'
        : 'Menstabilkan...';

  return (
    <section
      className="bg-white rounded-2xl p-5 border border-slate-200 shadow-soft flex flex-col justify-between h-full"
      aria-label="Panggung tatakan dan tumbler"
    >
      <div className="flex items-start justify-between gap-3">
        <div>
          <h2 className="font-display text-base font-bold text-slate-900 tracking-tight">
            Tatakan & Tumbler
          </h2>
          <p className="text-xs text-slate-600 mt-0.5">
            Gelas kosong {Math.round(emptyCup)} g · Kapasitas {cupMax} ml
          </p>
        </div>
        <div
          className={`px-3 py-1 rounded-full text-xs font-semibold font-mono tracking-wide border ${meta.badge}`}
          role="status"
          aria-live="polite"
        >
          {badgeText}
        </div>
      </div>

      <div className="py-3 flex flex-col items-center justify-center">
        <svg
          width="148"
          height="172"
          viewBox="0 0 120 170"
          className="overflow-visible"
          aria-hidden="true"
        >
          <defs>
            <clipPath id="reactCupClip">
              <path d="M30 20 L90 20 L82 138 Q81 146 72 146 L48 146 Q39 146 38 138 Z" />
            </clipPath>
            <linearGradient id="reactCupWaterGrad" x1="0%" y1="0%" x2="0%" y2="100%">
              <stop offset="0%" stopColor="#38BDF8" />
              <stop offset="100%" stopColor="#0284C7" />
            </linearGradient>
            <linearGradient id="reactPorcelainGrad" x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0%" stopColor="#FFFFFF" />
              <stop offset="55%" stopColor="#F8FAFC" />
              <stop offset="100%" stopColor="#E2E8F0" />
            </linearGradient>
          </defs>

          <g id="coasterBase">
            <ellipse cx="60" cy="155" rx="48" ry="11" fill="#E2E8F0" stroke="#CBD5E1" strokeWidth="1.5" />
            <ellipse cx="60" cy="152" rx="44" ry="9" fill="#FFFFFF" stroke="#CBD5E1" strokeWidth="1" />
            <ellipse
              cx="60"
              cy="152"
              rx="40"
              ry="7.5"
              fill="none"
              stroke={meta.led}
              strokeWidth="2.5"
              className="transition-colors duration-300"
            />
          </g>

          <ellipse
            cx="60"
            cy="146"
            rx="28"
            ry="5"
            fill="none"
            stroke="#94A3B8"
            strokeDasharray="3 3"
            strokeWidth="1.2"
          />

          <g
            className="transition-transform duration-300 ease-out"
            style={{
              transform: isLifted ? 'translateY(-22px)' : 'translateY(0px)',
              transformOrigin: '60px 140px',
              opacity: isLifted ? 0.55 : 1
            }}
          >
            <path
              d="M30 20 L90 20 L82 138 Q81 146 72 146 L48 146 Q39 146 38 138 Z"
              fill="url(#reactPorcelainGrad)"
              stroke="#94A3B8"
              strokeWidth="2"
            />

            {waterH > 0 && (
              <g clipPath="url(#reactCupClip)">
                <rect
                  x="30"
                  y={waterY}
                  width="60"
                  height={waterH}
                  fill="url(#reactCupWaterGrad)"
                  opacity="0.92"
                  className="transition-all duration-300 ease-out"
                />
                <line
                  x1="30"
                  y1={waterY}
                  x2="90"
                  y2={waterY}
                  stroke="#0369A1"
                  strokeWidth="1.5"
                />
              </g>
            )}

            <ellipse cx="60" cy="20" rx="30" ry="4.5" fill="#F1F5F9" stroke="#64748B" strokeWidth="1.5" />
            <path d="M35 26 L39 134" stroke="#FFFFFF" strokeWidth="2.5" strokeLinecap="round" opacity="0.8" />
          </g>
        </svg>

        <div className="mt-2 text-center w-full">
          <div className="flex items-baseline justify-center gap-2">
            <span className="text-2xl font-bold text-slate-900 font-mono tabular-nums">
              {weight.toFixed(1)} g
            </span>
            <span className="text-xs font-semibold text-water-700 font-mono tabular-nums">
              ({isLifted ? 'Gelas diangkat' : `air ${Math.max(0, Math.round(cupMl))} ml`})
            </span>
          </div>
          <div className="mt-1 inline-flex items-center gap-1.5 text-xs font-medium text-slate-600">
            <span>Status beban:</span>
            <span className="font-semibold text-slate-800">{stabilityLabel}</span>
          </div>
          <p className="text-xs text-slate-600 mt-1.5 max-w-sm mx-auto leading-relaxed">
            {meta.desc}
          </p>
        </div>
      </div>

      {connMode === 'sim' ? (
        <div className="pt-3 border-t border-slate-200/80">
          <div className="text-[11px] font-semibold text-slate-600 mb-2 text-center">
            Simulasi sentuhan fisik gelas
          </div>
          <div className="flex flex-wrap items-center justify-center gap-1.5" role="group" aria-label="Aksi simulasi fisik gelas">
            <button
              type="button"
              onClick={onLift}
              className="px-2.5 py-1.5 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-slate-800 text-xs font-medium transition-colors"
            >
              Angkat
            </button>
            <button
              type="button"
              onClick={onPlace}
              className="px-2.5 py-1.5 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-slate-800 text-xs font-medium transition-colors"
            >
              Taruh
            </button>
            <button
              type="button"
              onClick={onSip}
              className="px-2.5 py-1.5 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-slate-800 text-xs font-medium transition-colors"
            >
              Sedot -30 g
            </button>
            <button
              type="button"
              onClick={onPour}
              className="px-2.5 py-1.5 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-slate-800 text-xs font-medium transition-colors"
            >
              Tuang +50 g
            </button>
            <button
              type="button"
              onClick={onEmpty}
              className="px-2.5 py-1.5 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-slate-800 text-xs font-medium transition-colors"
            >
              Habiskan
            </button>
          </div>
        </div>
      ) : (
        <div className="pt-3 border-t border-slate-200/80 text-center">
          <p className="text-xs text-slate-600">
            {connMode === 'usb'
              ? 'Membaca beban langsung dari sensor HX711 melalui USB Serial.'
              : 'Membaca telemetri waktu-nyata dari tatakan ESP32 melalui Firebase Cloud.'}
          </p>
        </div>
      )}
    </section>
  );
}
