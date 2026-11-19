import React from 'react';

export default function RingGaugeTrio({
  goalCur = 0,
  goalMax = 2000,
  cupMl = 0,
  cupMax = 500,
  weight = 0,
  remSec = null,
  targetSec = 15,
  stateString = 'IDLE',
  standby = false,
  targetMntStr = '15 detik'
}) {
  const C = 251.327; // 2 * PI * 40

  // 1. Target Hidrasi Harian
  const dailyPct = goalMax > 0 ? Math.min(100, Math.max(0, (goalCur / goalMax) * 100)) : 0;
  const dailyOffset = C * (1 - dailyPct / 100);

  // 2. Volume Air Gelas (jujur terhadap status gelas)
  const isLifted = stateString === 'LIFTED' || stateString === 'ALERT_MISSING_CUP';
  const isNoCup = !isLifted && (stateString === 'IDLE' || weight < 25);
  const isCupEmptyAlert = stateString === 'ALERT_EMPTY_CUP' || (!isNoCup && !isLifted && cupMl <= 15);
  const effectiveCupMl = (isNoCup || isLifted) ? 0 : Math.max(0, Math.round(cupMl));
  const cupPct = cupMax > 0 ? Math.min(100, Math.max(0, (effectiveCupMl / cupMax) * 100)) : 0;
  const cupOffset = C * (1 - cupPct / 100);

  const cupCenterText = isLifted
    ? 'Angkat'
    : isNoCup
      ? '0'
      : String(effectiveCupMl);

  const cupSubText = isLifted
    ? 'Gelas sedang diangkat'
    : isNoCup
      ? 'Belum ada gelas di tatakan'
      : isCupEmptyAlert
        ? 'Air hampir habis, isi ulang'
        : `${Math.round(cupPct)}% dari kapasitas ${cupMax} ml`;

  // 3. Hitung Mundur Waktu Minum
  let cdText = '--:--';
  let cdPct = 0;
  if (!standby && remSec !== null && remSec !== undefined && !isNaN(remSec)) {
    const s = Math.max(0, Math.floor(remSec));
    const m = Math.floor(s / 60);
    const sec = s % 60;
    cdText = String(m).padStart(2, '0') + ':' + String(sec).padStart(2, '0');
    if (targetSec > 0) {
      cdPct = Math.min(100, Math.max(0, (s / targetSec) * 100));
    }
  }
  const cdOffset = C * (1 - cdPct / 100);
  const isAlertOrLowTimer = !standby && (stateString === 'ALERT_DRINK' || (remSec !== null && remSec <= 3));

  return (
    <section
      className="bg-white rounded-2xl border border-slate-200 shadow-soft p-4 sm:p-5"
      aria-label="Indikator utama hidrasi"
    >
      <div className="grid grid-cols-1 sm:grid-cols-3 divide-y sm:divide-y-0 sm:divide-x divide-slate-200/80">
        {/* Ring 1: Hidrasi Hari Ini */}
        <div className="py-3 sm:py-0 sm:pr-4 flex flex-col items-center">
          <div className="text-xs font-semibold text-slate-700 tracking-tight mb-2">
            Hidrasi Hari Ini
          </div>

          <div className="relative w-32 h-32 flex items-center justify-center">
            <svg className="w-full h-full transform -rotate-90" viewBox="0 0 100 100" aria-hidden="true">
              <circle cx="50" cy="50" r="40" fill="none" stroke="#E0F2FE" strokeWidth="8" />
              <circle
                cx="50"
                cy="50"
                r="40"
                fill="none"
                stroke="#0284C7"
                strokeWidth="8"
                strokeDasharray={C}
                strokeDashoffset={dailyOffset}
                strokeLinecap="round"
                className="transition-[stroke-dashoffset] duration-300 ease-out"
              />
            </svg>
            <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
              <div className="text-2xl font-bold text-slate-900 font-mono tabular-nums leading-none">
                {Math.round(dailyPct)}
                <span className="text-sm font-semibold text-slate-600 ml-0.5">%</span>
              </div>
              <span className="text-[11px] font-medium text-slate-600 mt-1">tercapai</span>
            </div>
          </div>

          <div className="mt-2.5 text-center">
            <div className="text-sm font-bold text-slate-900 font-mono tabular-nums">
              {Math.round(goalCur)} <span className="text-slate-600 font-normal">/</span> {goalMax} ml
            </div>
            <p className="text-xs text-slate-600 mt-0.5">Akumulasi minum harian</p>
          </div>
        </div>

        {/* Ring 2: Volume Air Gelas */}
        <div className="py-3 sm:py-0 sm:px-4 flex flex-col items-center">
          <div className="text-xs font-semibold text-slate-700 tracking-tight mb-2">
            Volume Air Gelas
          </div>

          <div className="relative w-32 h-32 flex items-center justify-center">
            <svg className="w-full h-full transform -rotate-90" viewBox="0 0 100 100" aria-hidden="true">
              <circle cx="50" cy="50" r="40" fill="none" stroke="#F1F5F9" strokeWidth="8" />
              <circle
                cx="50"
                cy="50"
                r="40"
                fill="none"
                stroke={isCupEmptyAlert ? '#DC2626' : '#059669'}
                strokeWidth="8"
                strokeDasharray={C}
                strokeDashoffset={cupOffset}
                strokeLinecap="round"
                className="transition-[stroke-dashoffset] duration-300 ease-out"
              />
            </svg>
            <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
              <div className="text-2xl font-bold text-slate-900 font-mono tabular-nums leading-none">
                {cupCenterText}
                {!isLifted && (
                  <span className="text-xs font-semibold text-slate-600 ml-0.5">ml</span>
                )}
              </div>
              <span className="text-[11px] font-medium text-slate-600 mt-1">
                {isLifted ? 'di luar tatakan' : 'isi bersih'}
              </span>
            </div>
          </div>

          <div className="mt-2.5 text-center">
            <div className={`text-xs font-semibold ${isCupEmptyAlert ? 'text-rose-800' : 'text-slate-800'}`}>
              {cupSubText}
            </div>
            <p className="text-xs text-slate-600 mt-0.5">Berat air di atas gelas kosong</p>
          </div>
        </div>

        {/* Ring 3: Minum Berikutnya */}
        <div className="py-3 sm:py-0 sm:pl-4 flex flex-col items-center">
          <div className="text-xs font-semibold text-slate-700 tracking-tight mb-2">
            Minum Berikutnya
          </div>

          <div className="relative w-32 h-32 flex items-center justify-center">
            <svg className="w-full h-full transform -rotate-90" viewBox="0 0 100 100" aria-hidden="true">
              <circle cx="50" cy="50" r="40" fill="none" stroke="#F1F5F9" strokeWidth="8" />
              <circle
                cx="50"
                cy="50"
                r="40"
                fill="none"
                stroke={isAlertOrLowTimer ? '#D97706' : '#0284C7'}
                strokeWidth="8"
                strokeDasharray={C}
                strokeDashoffset={cdOffset}
                strokeLinecap="round"
                className="transition-[stroke-dashoffset] duration-300 ease-out"
              />
            </svg>
            <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
              <div
                className={`text-2xl font-bold font-mono tabular-nums leading-none tracking-tight ${
                  isAlertOrLowTimer ? 'text-amber-800' : 'text-slate-900'
                }`}
              >
                {cdText}
              </div>
              <span className="text-[11px] font-medium text-slate-600 mt-1">
                {standby ? 'sesi tidur' : isAlertOrLowTimer ? 'waktunya minum' : 'sisa waktu'}
              </span>
            </div>
          </div>

          <div className="mt-2.5 text-center">
            <div className="text-sm font-semibold text-slate-800">
              Target: <span className="font-mono text-water-800 font-bold">{targetMntStr}</span>
            </div>
            <p className="text-xs text-slate-600 mt-0.5">Interval siklus berjalan</p>
          </div>
        </div>
      </div>
    </section>
  );
}
