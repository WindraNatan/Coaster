import React from 'react';

export default function RingGaugeTrio({
  goalCur = 0,
  goalMax = 2000,
  cupMl = 0,
  cupMax = 500,
  remSec = null,
  targetSec = 15,
  stateString = 'IDLE',
  targetMntStr = '15 detik'
}) {
  const C = 251.327; // 2 * PI * 40

  // 1. Daily goal percentage & dashoffset
  const dailyPct = goalMax > 0 ? Math.min(100, Math.max(0, (goalCur / goalMax) * 100)) : 0;
  const dailyOffset = C * (1 - dailyPct / 100);

  // 2. Cup volume percentage & dashoffset
  const cupPct = cupMax > 0 ? Math.min(100, Math.max(0, (cupMl / cupMax) * 100)) : 0;
  const cupOffset = C * (1 - cupPct / 100);
  const isCupLow = cupMl < 50 && stateString === 'ALERT_EMPTY_CUP';

  // 3. Countdown timer
  let cdText = '--:--';
  let cdPct = 0;
  if (remSec !== null && remSec !== undefined && !isNaN(remSec)) {
    const s = Math.max(0, Math.floor(remSec));
    const m = Math.floor(s / 60);
    const sec = s % 60;
    cdText = String(m).padStart(2, '0') + ':' + String(sec).padStart(2, '0');
    if (targetSec > 0) {
      cdPct = Math.min(100, Math.max(0, (s / targetSec) * 100));
    }
  }
  const cdOffset = C * (1 - cdPct / 100);
  const isAlertOrLowTimer = stateString === 'ALERT_DRINK' || (remSec !== null && remSec <= 3);

  return (
    <section className="grid grid-cols-1 md:grid-cols-3 gap-4" aria-label="Indikator instrumen hidrasi melingkar">
      {/* Ring 1: Target Hidrasi Harian */}
      <div className="bg-white rounded-2xl p-5 border border-slate-200/80 shadow-soft hover:shadow-soft-lg transition-all flex flex-col items-center">
        <div className="w-full flex items-center justify-between mb-3">
          <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
            Target Harian
          </span>
          <span className="px-2 py-0.5 rounded-full text-[11px] font-semibold bg-sky-50 text-sky-700 border border-sky-100">
            Hari Ini
          </span>
        </div>

        <div className="relative w-36 h-36 flex items-center justify-center my-1">
          <svg className="w-full h-full transform -rotate-90" viewBox="0 0 100 100" aria-hidden="true">
            <defs>
              <linearGradient id="ringWaterGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" stopColor="#0284C7" />
                <stop offset="100%" stopColor="#38BDF8" />
              </linearGradient>
            </defs>
            <circle
              cx="50"
              cy="50"
              r="40"
              fill="none"
              stroke="#E0F2FE"
              strokeWidth="8"
            />
            <circle
              cx="50"
              cy="50"
              r="40"
              fill="none"
              stroke="url(#ringWaterGrad)"
              strokeWidth="8"
              strokeDasharray={C}
              strokeDashoffset={dailyOffset}
              strokeLinecap="round"
              className="transition-[stroke-dashoffset] duration-500 ease-out"
            />
          </svg>
          <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
            <div className="text-2xl font-bold text-slate-900 font-mono tabular-nums leading-none">
              {Math.round(dailyPct)}
              <span className="text-sm font-semibold text-slate-500 ml-0.5">%</span>
            </div>
            <span className="text-[11px] font-medium text-slate-400 mt-1">tercapai</span>
          </div>
        </div>

        <div className="mt-3 text-center">
          <div className="text-sm font-semibold text-slate-800 font-mono tabular-nums">
            {Math.round(goalCur)} <span className="text-slate-400 font-normal">/</span> {goalMax} ml
          </div>
          <p className="text-xs text-slate-500 mt-0.5">Air diminum hari ini</p>
        </div>
      </div>

      {/* Ring 2: Volume Air Gelas */}
      <div className="bg-white rounded-2xl p-5 border border-slate-200/80 shadow-soft hover:shadow-soft-lg transition-all flex flex-col items-center">
        <div className="w-full flex items-center justify-between mb-3">
          <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
            Volume Air Gelas
          </span>
          <span className="px-2 py-0.5 rounded-full text-[11px] font-semibold bg-emerald-50 text-emerald-700 border border-emerald-100">
            Tumbler {cupMax} ml
          </span>
        </div>

        <div className="relative w-36 h-36 flex items-center justify-center my-1">
          <svg className="w-full h-full transform -rotate-90" viewBox="0 0 100 100" aria-hidden="true">
            <defs>
              <linearGradient id="ringCupGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" stopColor={isCupLow ? '#EF4444' : '#10B981'} />
                <stop offset="100%" stopColor={isCupLow ? '#F87171' : '#34D399'} />
              </linearGradient>
            </defs>
            <circle
              cx="50"
              cy="50"
              r="40"
              fill="none"
              stroke="#F1F5F9"
              strokeWidth="8"
            />
            <circle
              cx="50"
              cy="50"
              r="40"
              fill="none"
              stroke="url(#ringCupGrad)"
              strokeWidth="8"
              strokeDasharray={C}
              strokeDashoffset={cupOffset}
              strokeLinecap="round"
              className="transition-[stroke-dashoffset] duration-500 ease-out"
            />
          </svg>
          <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
            <div className="text-2xl font-bold text-slate-900 font-mono tabular-nums leading-none">
              {Math.max(0, Math.round(cupMl))}
              <span className="text-xs font-semibold text-slate-500 ml-0.5">ml</span>
            </div>
            <span className="text-[11px] font-medium text-slate-400 mt-1">dalam tumbler</span>
          </div>
        </div>

        <div className="mt-3 text-center">
          <div className="text-sm font-semibold text-slate-800 font-mono tabular-nums">
            {Math.round(cupPct)}% <span className="text-slate-500 font-normal">isi gelas</span>
          </div>
          <p className="text-xs text-slate-500 mt-0.5">Kapasitas wadah {cupMax} ml</p>
        </div>
      </div>

      {/* Ring 3: Hitung Mundur Waktu Minum */}
      <div className="bg-white rounded-2xl p-5 border border-slate-200/80 shadow-soft hover:shadow-soft-lg transition-all flex flex-col items-center">
        <div className="w-full flex items-center justify-between mb-3">
          <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
            Minum Berikutnya
          </span>
          <span
            className={`px-2 py-0.5 rounded-full text-[11px] font-semibold border ${
              isAlertOrLowTimer
                ? 'bg-amber-50 text-amber-700 border-amber-200 animate-pulse'
                : 'bg-sky-50 text-sky-700 border-sky-100'
            }`}
          >
            {isAlertOrLowTimer ? 'Waktunya Minum' : 'Siklus Aktif'}
          </span>
        </div>

        <div className="relative w-36 h-36 flex items-center justify-center my-1">
          <svg className="w-full h-full transform -rotate-90" viewBox="0 0 100 100" aria-hidden="true">
            <defs>
              <linearGradient id="ringTimerGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" stopColor={isAlertOrLowTimer ? '#F59E0B' : '#0284C7'} />
                <stop offset="100%" stopColor={isAlertOrLowTimer ? '#FBBF24' : '#60A5FA'} />
              </linearGradient>
            </defs>
            <circle
              cx="50"
              cy="50"
              r="40"
              fill="none"
              stroke="#F1F5F9"
              strokeWidth="8"
            />
            <circle
              cx="50"
              cy="50"
              r="40"
              fill="none"
              stroke="url(#ringTimerGrad)"
              strokeWidth="8"
              strokeDasharray={C}
              strokeDashoffset={cdOffset}
              strokeLinecap="round"
              className="transition-[stroke-dashoffset] duration-500 ease-out"
            />
          </svg>
          <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
            <div
              className={`text-2xl font-bold font-mono tabular-nums leading-none tracking-tight ${
                isAlertOrLowTimer ? 'text-amber-600 animate-pulse' : 'text-slate-900'
              }`}
            >
              {cdText}
            </div>
            <span className="text-[11px] font-medium text-slate-400 mt-1">sisa waktu</span>
          </div>
        </div>

        <div className="mt-3 text-center">
          <div className="text-sm font-semibold text-slate-800">
            Target: <span className="font-mono text-water-700">{targetMntStr}</span>
          </div>
          <p className="text-xs text-slate-500 mt-0.5">Interval minum terjadwal</p>
        </div>
      </div>
    </section>
  );
}
