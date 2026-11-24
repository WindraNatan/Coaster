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
  const isTiming = !standby && stateString === 'TIMING';
  const hasRem = remSec !== null && remSec !== undefined && !isNaN(remSec);
  let cdText = '--:--';
  let cdPct = 0;
  if (isTiming && hasRem) {
    const s = Math.max(0, Math.floor(remSec));
    const m = Math.floor(s / 60);
    const sec = s % 60;
    cdText = String(m).padStart(2, '0') + ':' + String(sec).padStart(2, '0');
    if (targetSec > 0) {
      cdPct = Math.min(100, Math.max(0, (s / targetSec) * 100));
    }
  } else if (!standby && stateString === 'ALERT_DRINK') {
    cdText = '00:00';
    cdPct = 0;
  }
  const cdOffset = C * (1 - cdPct / 100);
  const isDrinkDue = !standby && (stateString === 'ALERT_DRINK' || (isTiming && hasRem && remSec <= 3));
  const cdSubLabel = standby
    ? 'sedang istirahat'
    : isDrinkDue
      ? 'waktunya minum'
      : isTiming
        ? 'sisa waktu'
        : stateString === 'LIFTED' || stateString === 'ALERT_MISSING_CUP'
          ? 'gelas diangkat'
          : stateString === 'ALERT_EMPTY_CUP' || stateString === 'ALERT_REFILL'
            ? 'isi ulang air'
            : stateString === 'ALERT_CHEAT'
              ? 'minum lagi'
              : 'menunggu gelas';

  return (
    <section
      className="bg-surface rounded-2xl border border-hairline p-4 sm:p-5"
      aria-label="Ringkasan tiga indikator hidrasi"
    >
      <div className="grid grid-cols-2 gap-y-4 gap-x-3 sm:grid-cols-3 sm:gap-0 sm:divide-x divide-hairline">
        {/* Ring 1: Target harian */}
        <div className="min-w-0 sm:pr-4 flex flex-col items-center">
          <div className="text-xs font-semibold text-ink-soft mb-2">
            Target harian
          </div>

          <div className="relative w-24 h-24 sm:w-32 sm:h-32 flex items-center justify-center">
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
              <div className="text-xl sm:text-2xl font-semibold text-ink leading-none">
                <span className="font-mono tabular-nums">{Math.round(dailyPct)}</span>
                <span className="text-xs sm:text-sm font-medium text-ink-soft ml-0.5">%</span>
              </div>
              <span className="text-[11px] sm:text-xs text-ink-muted mt-1">tercapai</span>
            </div>
          </div>

          <div className="mt-2 sm:mt-2.5 text-center">
            <div className="text-xs sm:text-sm font-semibold text-ink">
              <span className="font-mono tabular-nums">{Math.round(goalCur)}</span>
              <span className="text-ink-muted font-normal"> / </span>
              <span className="font-mono tabular-nums">{goalMax}</span>
              <span> ml</span>
            </div>
            <p className="text-[11px] sm:text-xs text-ink-soft mt-0.5">Total minum hari ini</p>
          </div>
        </div>

        {/* Ring 2: Isi gelas */}
        <div className="min-w-0 sm:px-4 flex flex-col items-center">
          <div className="text-xs font-semibold text-ink-soft mb-2">
            Isi gelas
          </div>

          <div className="relative w-24 h-24 sm:w-32 sm:h-32 flex items-center justify-center">
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
              <div className="text-xl sm:text-2xl font-semibold text-ink leading-none">
                {isLifted ? (
                  <span className="text-sm sm:text-base font-semibold">Angkat</span>
                ) : (
                  <>
                    <span className="font-mono tabular-nums">{cupCenterNum}</span>
                    <span className="text-xs font-medium text-ink-soft ml-0.5">ml</span>
                  </>
                )}
              </div>
              <span className="text-[11px] sm:text-xs text-ink-muted mt-1">
                {isLifted ? 'di luar tatakan' : 'dalam gelas'}
              </span>
            </div>
          </div>

          <div className="mt-2 sm:mt-2.5 text-center">
            <div className={`text-xs font-semibold ${isCupEmptyAlert ? 'text-danger' : 'text-ink'}`}>
              {cupSubText}
            </div>
            <p className="text-[11px] sm:text-xs text-ink-soft mt-0.5">Sisa air bersih</p>
          </div>
        </div>

        {/* Ring 3: Jadwal minum (tampil utama di bagian atas pada layar ponsel) */}
        <div className="order-first sm:order-last col-span-2 sm:col-span-1 min-w-0 pb-4 sm:pb-0 sm:pl-4 border-b sm:border-b-0 border-hairline flex flex-row sm:flex-col items-center justify-between sm:justify-center gap-4 sm:gap-0">
          <div className="hidden sm:block text-xs font-semibold text-ink-soft mb-2">
            Jadwal minum
          </div>

          <div className="relative w-28 h-28 sm:w-32 sm:h-32 flex-shrink-0 flex items-center justify-center">
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
                className={`text-xl sm:text-2xl font-semibold leading-none tracking-tight ${
                  isDrinkDue ? 'text-warn' : 'text-ink'
                }`}
              >
                <span className="font-mono tabular-nums">{cdText}</span>
              </div>
              <span className="text-[10px] sm:text-xs text-ink-muted mt-1 px-1 max-w-[76px] sm:max-w-none leading-tight">
                {cdSubLabel}
              </span>
            </div>
          </div>

          <div className="flex-1 min-w-0 sm:flex-none sm:mt-2.5 text-left sm:text-center">
            <div className="sm:hidden text-xs font-semibold text-ink-soft mb-1">
              Jadwal minum
            </div>
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
