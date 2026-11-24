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
  targetLabel = '15 detik'
}) {
  const C = 251.327; // 2 * PI * 40

  // 1. Target hidrasi harian
  const dailyPct = goalMax > 0 ? Math.min(100, Math.max(0, (goalCur / goalMax) * 100)) : 0;
  const dailyOffset = C * (1 - dailyPct / 100);

  // 2. Isi gelas
  const isLifted = stateString === 'LIFTED' || stateString === 'ALERT_MISSING_CUP';
  const isNoCup = !isLifted && weight < 25;
  const isCupEmptyAlert = stateString === 'ALERT_EMPTY_CUP' || (!isNoCup && !isLifted && cupMl <= 15);
  const effectiveCupMl = (isNoCup || isLifted) ? 0 : Math.max(0, Math.round(cupMl));
  const cupPct = cupMax > 0 ? Math.min(100, Math.max(0, (effectiveCupMl / cupMax) * 100)) : 0;
  const cupOffset = C * (1 - cupPct / 100);

  const cupCenterNum = isLifted ? 'Angkat' : isNoCup ? '0' : String(effectiveCupMl);
  const cupSubText = isLifted
    ? 'Gelas sedang diangkat'
    : isNoCup
      ? 'Belum ada gelas'
      : isCupEmptyAlert
        ? 'Air hampir habis'
        : `${Math.round(cupPct)}% dari ${cupMax} ml`;

  // 3. Hitung mundur jadwal minum
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
  const isDrinkDue = !standby && (stateString === 'ALERT_DRINK' || (remSec !== null && remSec <= 3));

  return (
    <section
      className="bg-surface rounded-2xl border border-hairline p-4 sm:p-5"
      aria-label="Ringkasan tiga indikator hidrasi"
    >
      <div className="grid grid-cols-1 sm:grid-cols-3 divide-y sm:divide-y-0 sm:divide-x divide-hairline">
        {/* Ring 1: Target harian */}
        <div className="py-3 sm:py-0 sm:pr-4 flex flex-col items-center">
          <div className="text-xs font-semibold text-ink-soft mb-2">
            Target harian
          </div>

          <div className="relative w-32 h-32 flex items-center justify-center">
            <svg className="w-full h-full transform -rotate-90" viewBox="0 0 100 100" aria-hidden="true">
              <circle cx="50" cy="50" r="40" fill="none" stroke="var(--bg-subtle)" strokeWidth="8" />
              <circle
                cx="50"
                cy="50"
                r="40"
                fill="none"
                stroke="var(--accent)"
                strokeWidth="8"
                strokeDasharray={C}
                strokeDashoffset={dailyOffset}
                strokeLinecap="round"
                className="transition-[stroke-dashoffset,stroke] duration-300 ease-calm"
              />
            </svg>
            <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
              <div className="text-2xl font-semibold text-ink leading-none">
                <span className="font-mono tabular-nums">{Math.round(dailyPct)}</span>
                <span className="text-sm font-medium text-ink-soft ml-0.5">%</span>
              </div>
              <span className="text-xs text-ink-muted mt-1">tercapai</span>
            </div>
          </div>

          <div className="mt-2.5 text-center">
            <div className="text-sm font-semibold text-ink">
              <span className="font-mono tabular-nums">{Math.round(goalCur)}</span>
              <span className="text-ink-muted font-normal"> / </span>
              <span className="font-mono tabular-nums">{goalMax}</span>
              <span> ml</span>
            </div>
            <p className="text-xs text-ink-soft mt-0.5">Total minum hari ini</p>
          </div>
        </div>

        {/* Ring 2: Isi gelas */}
        <div className="py-3 sm:py-0 sm:px-4 flex flex-col items-center">
          <div className="text-xs font-semibold text-ink-soft mb-2">
            Isi gelas
          </div>

          <div className="relative w-32 h-32 flex items-center justify-center">
            <svg className="w-full h-full transform -rotate-90" viewBox="0 0 100 100" aria-hidden="true">
              <circle cx="50" cy="50" r="40" fill="none" stroke="var(--bg-subtle)" strokeWidth="8" />
              <circle
                cx="50"
                cy="50"
                r="40"
                fill="none"
                stroke={isCupEmptyAlert ? 'var(--danger)' : 'var(--ok)'}
                strokeWidth="8"
                strokeDasharray={C}
                strokeDashoffset={cupOffset}
                strokeLinecap="round"
                className="transition-[stroke-dashoffset,stroke] duration-300 ease-calm"
              />
            </svg>
            <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
              <div className="text-2xl font-semibold text-ink leading-none">
                {isLifted ? (
                  <span className="text-base font-semibold">Angkat</span>
                ) : (
                  <>
                    <span className="font-mono tabular-nums">{cupCenterNum}</span>
                    <span className="text-xs font-medium text-ink-soft ml-0.5">ml</span>
                  </>
                )}
              </div>
              <span className="text-xs text-ink-muted mt-1">
                {isLifted ? 'di luar tatakan' : 'dalam gelas'}
              </span>
            </div>
          </div>

          <div className="mt-2.5 text-center">
            <div className={`text-xs font-semibold ${isCupEmptyAlert ? 'text-danger' : 'text-ink'}`}>
              {cupSubText}
            </div>
            <p className="text-xs text-ink-soft mt-0.5">Sisa air bersih</p>
          </div>
        </div>

        {/* Ring 3: Jadwal minum */}
        <div className="py-3 sm:py-0 sm:pl-4 flex flex-col items-center">
          <div className="text-xs font-semibold text-ink-soft mb-2">
            Jadwal minum
          </div>

          <div className="relative w-32 h-32 flex items-center justify-center">
            <svg className="w-full h-full transform -rotate-90" viewBox="0 0 100 100" aria-hidden="true">
              <circle cx="50" cy="50" r="40" fill="none" stroke="var(--bg-subtle)" strokeWidth="8" />
              <circle
                cx="50"
                cy="50"
                r="40"
                fill="none"
                stroke={isDrinkDue ? 'var(--warn)' : 'var(--accent)'}
                strokeWidth="8"
                strokeDasharray={C}
                strokeDashoffset={cdOffset}
                strokeLinecap="round"
                className="transition-[stroke-dashoffset,stroke] duration-300 ease-calm"
              />
            </svg>
            <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
              <div
                className={`text-2xl font-semibold leading-none tracking-tight ${
                  isDrinkDue ? 'text-warn' : 'text-ink'
                }`}
              >
                <span className="font-mono tabular-nums">{cdText}</span>
              </div>
              <span className="text-xs text-ink-muted mt-1">
                {standby ? 'sedang istirahat' : isDrinkDue ? 'waktunya minum' : 'sisa waktu'}
              </span>
            </div>
          </div>

          <div className="mt-2.5 text-center">
            <div className="text-sm font-semibold text-ink">
              <span>Jeda </span>
              <span className="text-accent">{targetLabel}</span>
            </div>
            <p className="text-xs text-ink-soft mt-0.5">Pengingat minum berikutnya</p>
          </div>
        </div>
      </div>
    </section>
  );
}
