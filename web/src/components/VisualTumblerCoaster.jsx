import React from 'react';

const FSM_META = {
  IDLE: {
    name: 'IDLE',
    desc: 'Letakkan gelas di tatakan untuk memulai pemantauan',
    badge: 'bg-slate-100 text-slate-700 border-slate-200',
    led: '#94A3B8',
    glow: 'rgba(148, 163, 184, 0.15)'
  },
  STABLE: {
    name: 'STABLE',
    desc: 'Beban stabil, menyiapkan siklus hitung mundur',
    badge: 'bg-emerald-50 text-emerald-700 border-emerald-200',
    led: '#10B981',
    glow: 'rgba(16, 185, 129, 0.35)'
  },
  TIMING: {
    name: 'TIMING',
    desc: 'Siklus pengingat aktif, hidrasi teratur terjaga',
    badge: 'bg-sky-50 text-sky-700 border-sky-200',
    led: '#0284C7',
    glow: 'rgba(2, 132, 199, 0.35)'
  },
  ALERT_DRINK: {
    name: 'ALERT_DRINK',
    desc: 'Waktunya minum! Ambil gelas dan nikmati kesegarannya',
    badge: 'bg-amber-50 text-amber-700 border-amber-300 animate-pulse',
    led: '#F59E0B',
    glow: 'rgba(245, 158, 11, 0.5)'
  },
  ALERT_CHEAT: {
    name: 'ALERT_CHEAT',
    desc: 'Tegukan kecil terdeteksi (< 20 ml). Silakan minum lebih banyak',
    badge: 'bg-rose-50 text-rose-700 border-rose-300 animate-pulse',
    led: '#EF4444',
    glow: 'rgba(239, 68, 68, 0.5)'
  },
  ALERT_EMPTY_CUP: {
    name: 'ALERT_EMPTY_CUP',
    desc: 'Air di dalam gelas hampir habis. Segera isi ulang tumbler',
    badge: 'bg-rose-50 text-rose-700 border-rose-300 animate-pulse',
    led: '#EF4444',
    glow: 'rgba(239, 68, 68, 0.5)'
  },
  ALERT_MISSING_CUP: {
    name: 'ALERT_MISSING_CUP',
    desc: 'Gelas terangkat lebih dari 10 detik. Letakkan kembali di tatakan',
    badge: 'bg-amber-50 text-amber-700 border-amber-300 animate-pulse',
    led: '#F59E0B',
    glow: 'rgba(245, 158, 11, 0.4)'
  },
  LIFTED: {
    name: 'LIFTED',
    desc: 'Gelas sedang diangkat dari tatakan untuk diminum',
    badge: 'bg-sky-50 text-sky-700 border-sky-200',
    led: '#38BDF8',
    glow: 'rgba(56, 189, 248, 0.3)'
  }
};

export default function VisualTumblerCoaster({
  stateString = 'IDLE',
  weight = 0,
  cupMl = 0,
  cupMax = 500,
  onLift,
  onPlace,
  onSip,
  onPour,
  onEmpty
}) {
  const meta = FSM_META[stateString] || FSM_META.IDLE;
  const isLifted = stateString === 'LIFTED' || stateString === 'ALERT_MISSING_CUP' || weight < 25;

  // Water level SVG calculations
  const maxWaterH = 120;
  const waterPct = Math.min(1, Math.max(0, cupMl / cupMax));
  const waterH = Math.round(waterPct * maxWaterH);
  const waterY = 148 - waterH;

  return (
    <div className="bg-white rounded-2xl p-5 border border-slate-200/80 shadow-soft hover:shadow-soft-lg transition-all flex flex-col justify-between">
      {/* Header */}
      <div className="flex items-center justify-between gap-3 mb-4">
        <div>
          <h2 className="text-base font-bold text-slate-900 tracking-tight">
            Panggung Tatakan & Gelas
          </h2>
          <p className="text-xs text-slate-500 mt-0.5">
            Sensor Load Cell Presisi & Cincin Status FSM
          </p>
        </div>
        <div
          className={`px-3 py-1 rounded-full text-xs font-semibold font-mono tracking-wider border ${meta.badge}`}
          role="status"
          aria-live="polite"
        >
          {meta.name}
        </div>
      </div>

      {/* Visualizer Stage */}
      <div className="relative py-4 flex flex-col items-center justify-center">
        {/* Halo LED Glow behind coaster */}
        <div
          className="absolute bottom-6 w-36 h-12 rounded-full blur-xl pointer-events-none transition-all duration-500"
          style={{
            backgroundColor: meta.glow,
            boxShadow: `0 0 40px ${meta.glow}`
          }}
        />

        <svg
          width="160"
          height="190"
          viewBox="0 0 120 170"
          className="relative z-10 overflow-visible"
          aria-hidden="true"
        >
          <defs>
            <clipPath id="reactCupClip">
              <path d="M30 18 L90 18 L82 140 Q81 148 72 148 L48 148 Q39 148 38 140 Z" />
            </clipPath>
            <linearGradient id="reactCupWaterGrad" x1="0%" y1="0%" x2="0%" y2="100%">
              <stop offset="0%" stopColor="#38BDF8" />
              <stop offset="100%" stopColor="#0284C7" />
            </linearGradient>
            <linearGradient id="reactPorcelainGrad" x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0%" stopColor="#FFFFFF" />
              <stop offset="45%" stopColor="#F8FAFC" />
              <stop offset="100%" stopColor="#E2E8F0" />
            </linearGradient>
          </defs>

          {/* Coaster Base */}
          <g id="coasterBase">
            <ellipse cx="60" cy="156" rx="48" ry="12" fill="#E2E8F0" stroke="#CBD5E1" strokeWidth="1.5" />
            <ellipse cx="60" cy="153" rx="44" ry="10" fill="#FFFFFF" stroke="#E2E8F0" strokeWidth="1" />
            <ellipse
              cx="60"
              cy="153"
              rx="40"
              ry="8"
              fill="none"
              stroke={meta.led}
              strokeWidth="2.5"
              className="transition-colors duration-500"
            />
          </g>

          {/* Ghost cup outline on coaster */}
          <ellipse
            cx="60"
            cy="148"
            rx="30"
            ry="5.5"
            fill="none"
            stroke="#CBD5E1"
            strokeDasharray="4 4"
            strokeWidth="1.5"
          />

          {/* Nordic Tumbler Body (rises up when lifted) */}
          <g
            className="transition-transform duration-300 ease-out"
            style={{
              transform: isLifted ? 'translateY(-24px) scale(0.96)' : 'translateY(0px)',
              transformOrigin: '60px 140px',
              opacity: isLifted ? 0.75 : 1
            }}
          >
            {/* Tumbler Wall */}
            <path
              d="M30 18 L90 18 L82 140 Q81 148 72 148 L48 148 Q39 148 38 140 Z"
              fill="url(#reactPorcelainGrad)"
              stroke="#CBD5E1"
              strokeWidth="2.5"
            />

            {/* Dynamic Water Rectangle clipped to Tumbler */}
            <rect
              x="30"
              y={waterY}
              width="60"
              height={waterH}
              fill="url(#reactCupWaterGrad)"
              opacity="0.9"
              clipPath="url(#reactCupClip)"
              className="transition-all duration-300 ease-out"
            />

            {/* Cup Rim */}
            <ellipse cx="60" cy="18" rx="30" ry="5" fill="#F1F5F9" stroke="#94A3B8" strokeWidth="1.5" />
            <line x1="31" y1="26" x2="89" y2="26" stroke="#CBD5E1" strokeWidth="1" />
            {/* Gloss Highlight reflection */}
            <path d="M35 24 L39 136" stroke="#FFFFFF" strokeWidth="3" strokeLinecap="round" opacity="0.75" />
          </g>
        </svg>

        {/* Volume & Companion Guidance */}
        <div className="mt-2 text-center">
          <div className="text-sm font-bold text-slate-800 font-mono tabular-nums">
            {isLifted ? (
              <span className="text-amber-600">Gelas diangkat</span>
            ) : (
              <span>air {Math.max(0, Math.round(cupMl))} ml</span>
            )}
          </div>
          <p className="text-xs text-slate-500 mt-1 max-w-sm mx-auto min-h-[32px] flex items-center justify-center">
            {meta.desc}
          </p>
        </div>
      </div>

      {/* Tactile Control Buttons */}
      <div className="pt-3 border-t border-slate-100">
        <div className="flex flex-wrap items-center justify-center gap-1.5" role="group" aria-label="Aksi fisik gelas">
          <button
            type="button"
            onClick={onLift}
            className="px-3 py-1.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 text-xs font-medium transition-colors shadow-sm"
          >
            Angkat gelas
          </button>
          <button
            type="button"
            onClick={onPlace}
            className="px-3 py-1.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 text-xs font-medium transition-colors shadow-sm"
          >
            Taruh kembali
          </button>
          <button
            type="button"
            onClick={onSip}
            className="px-3 py-1.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 text-xs font-medium transition-colors shadow-sm"
          >
            Sedot -30 g
          </button>
          <button
            type="button"
            onClick={onPour}
            className="px-3 py-1.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 text-xs font-medium transition-colors shadow-sm"
          >
            Tuang +50 g
          </button>
          <button
            type="button"
            onClick={onEmpty}
            className="px-3 py-1.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 text-xs font-medium transition-colors shadow-sm"
          >
            Kosongkan
          </button>
        </div>
      </div>
    </div>
  );
}
