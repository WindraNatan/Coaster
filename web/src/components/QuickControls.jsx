import React, { useState, useEffect } from 'react';
import { RotateCcw, Volume2, VolumeX } from 'lucide-react';

export default React.memo(function QuickControls({
  connMode = 'sim',
  controlsDisabled = false,
  deviceOffline = false,
  weight = 0,
  emptyCup = 130,
  onCalibrateCup,
  onTare,
  autoDht = true,
  demo = false,
  onSelectTimerMode,
  buzzerMuted = false,
  onToggleMute,
  baseMin = 30,
  onSetInterval,
  dailyGoal = 2000,
  onSaveGoal,
  onResetDaily,
  timerHint = null
}) {
  const [inputEmpty, setInputEmpty] = useState(emptyCup);
  const [inputBaseMin, setInputBaseMin] = useState(baseMin);
  const [inputGoal, setInputGoal] = useState(dailyGoal);
  const [confirmTareOpen, setConfirmTareOpen] = useState(false);

  useEffect(() => {
    setInputEmpty(emptyCup);
  }, [emptyCup]);

  useEffect(() => {
    setInputBaseMin(baseMin);
  }, [baseMin]);

  useEffect(() => {
    setInputGoal(dailyGoal);
  }, [dailyGoal]);

  useEffect(() => {
    setConfirmTareOpen(false);
  }, [connMode, controlsDisabled]);

  const activeTimerMode = demo ? 'DEMO' : (autoDht ? 'AUTO_DHT' : 'MANUAL');
  const canUseCurrentWeight = !controlsDisabled && weight >= 35 && weight <= 300;

  const handleSaveEmpty = (e) => {
    e.preventDefault();
    const val = Number(inputEmpty);
    if (!isNaN(val) && val >= 35 && val <= 300) {
      onCalibrateCup(val);
    }
  };

  const handleSaveInterval = (e) => {
    e.preventDefault();
    const val = Number(inputBaseMin);
    if (!isNaN(val) && val >= 1 && val <= 180) {
      onSetInterval(val);
    }
  };

  const handleSaveGoal = (e) => {
    e.preventDefault();
    const val = Number(inputGoal);
    if (!isNaN(val) && val >= 500 && val <= 6000) {
      onSaveGoal(val);
    }
  };

  return (
    <section
      className="bg-surface rounded-2xl p-4 sm:p-5 border border-hairline flex flex-col gap-5"
      aria-label="Pengaturan tatakan dan target minum"
    >
      <div>
        <h2 className="text-base font-semibold text-ink tracking-tight">
          Pengaturan
        </h2>
        <p className="text-xs text-ink-soft mt-0.5">
          Atur jadwal pengingat, target minum, dan gelas
        </p>
        {deviceOffline && (
          <p
            className="mt-2.5 text-xs font-medium text-danger bg-danger-bg border border-danger-border rounded-xl px-3 py-2"
            role="status"
          >
            Kendali alat dijeda saat tatakan tidak terhubung.
          </p>
        )}
      </div>

      <div className="space-y-3 pb-4 border-b border-hairline">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <h3 className="text-xs font-semibold text-ink-soft">
            Jadwal pengingat
          </h3>
          <button
            type="button"
            disabled={controlsDisabled}
            onClick={onToggleMute}
            aria-pressed={buzzerMuted}
            className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg border text-xs font-semibold whitespace-nowrap disabled:opacity-50 disabled:cursor-not-allowed transition-colors duration-150 ${
              buzzerMuted
                ? 'bg-warn-bg text-warn border-warn-border'
                : 'bg-ok-bg text-ok border-ok-border'
            }`}
          >
            {buzzerMuted ? (
              <VolumeX className="w-3.5 h-3.5" strokeWidth={1.75} aria-hidden="true" />
            ) : (
              <Volume2 className="w-3.5 h-3.5" strokeWidth={1.75} aria-hidden="true" />
            )}
            <span>{buzzerMuted ? 'Suara hening' : 'Suara aktif'}</span>
          </button>
        </div>

        <div
          className="grid grid-cols-3 gap-1 sm:gap-1.5 p-1 bg-subtle rounded-xl border border-hairline"
          role="group"
          aria-label="Cara mengatur jeda minum"
        >
          <button
            type="button"
            disabled={controlsDisabled}
            aria-pressed={activeTimerMode === 'AUTO_DHT'}
            onClick={() => onSelectTimerMode('AUTO_DHT')}
            className={`min-w-0 px-1.5 sm:px-2 py-1.5 rounded-lg text-xs font-medium text-center leading-tight disabled:opacity-50 disabled:cursor-not-allowed transition-colors duration-150 ${
              activeTimerMode === 'AUTO_DHT'
                ? 'bg-surface text-ink font-semibold border border-hairline'
                : 'text-ink-soft hover:text-ink'
            }`}
          >
            Sesuai suhu
          </button>
          <button
            type="button"
            disabled={controlsDisabled}
            aria-pressed={activeTimerMode === 'MANUAL'}
            onClick={() => onSelectTimerMode('MANUAL')}
            className={`min-w-0 px-1.5 sm:px-2 py-1.5 rounded-lg text-xs font-medium text-center leading-tight disabled:opacity-50 disabled:cursor-not-allowed transition-colors duration-150 ${
              activeTimerMode === 'MANUAL'
                ? 'bg-surface text-ink font-semibold border border-hairline'
                : 'text-ink-soft hover:text-ink'
            }`}
          >
            Manual
          </button>
          <button
            type="button"
            disabled={controlsDisabled}
            aria-pressed={activeTimerMode === 'DEMO'}
            onClick={() => onSelectTimerMode('DEMO')}
            className={`min-w-0 px-1.5 sm:px-2 py-1.5 rounded-lg text-xs font-medium text-center leading-tight disabled:opacity-50 disabled:cursor-not-allowed transition-colors duration-150 ${
              activeTimerMode === 'DEMO'
                ? 'bg-surface text-ink font-semibold border border-hairline'
                : 'text-ink-soft hover:text-ink'
            }`}
          >
            Demo 15 dtk
          </button>
        </div>

        <form onSubmit={handleSaveInterval} className="flex flex-col sm:flex-row sm:items-center gap-1.5 sm:gap-2">
          <label htmlFor="baseMinInput" className="text-xs text-ink-soft font-medium sm:min-w-[112px] sm:whitespace-nowrap">
            Jeda minum
          </label>
          <div className="flex items-center gap-2 flex-1 min-w-0">
            <div className="relative flex-1 min-w-0">
              <input
                id="baseMinInput"
                type="number"
                min="1"
                max="180"
                step="1"
                disabled={controlsDisabled}
                value={inputBaseMin}
                onChange={(e) => setInputBaseMin(e.target.value)}
                className="w-full pr-12 pl-3 py-1.5 rounded-xl border border-control bg-surface disabled:opacity-50 disabled:cursor-not-allowed text-xs font-mono tabular-nums text-ink"
              />
              <span className="absolute right-2.5 top-1/2 -translate-y-1/2 text-xs text-ink-muted font-medium pointer-events-none">
                menit
              </span>
            </div>
            <button
              type="submit"
              disabled={controlsDisabled}
              className="px-3.5 py-1.5 rounded-xl border border-control bg-surface hover:bg-subtle disabled:opacity-50 disabled:cursor-not-allowed text-ink text-xs font-semibold whitespace-nowrap flex-shrink-0 transition-colors duration-150"
            >
              Atur
            </button>
          </div>
        </form>

        {timerHint && (
          <p
            className="text-xs text-warn bg-warn-bg border border-warn-border rounded-xl p-2.5 leading-relaxed"
            role="status"
          >
            {timerHint}
          </p>
        )}
      </div>

      <div className="space-y-3">
        <h3 className="text-xs font-semibold text-ink-soft">
          Target harian & gelas
        </h3>

        <form onSubmit={handleSaveGoal} className="flex flex-col sm:flex-row sm:items-center gap-1.5 sm:gap-2">
          <label htmlFor="dailyGoalInput" className="text-xs text-ink-soft font-medium sm:min-w-[112px] sm:whitespace-nowrap">
            Target harian
          </label>
          <div className="flex items-center gap-2 flex-1 min-w-0">
            <div className="relative flex-1 min-w-0">
              <input
                id="dailyGoalInput"
                type="number"
                min="500"
                max="6000"
                step="50"
                value={inputGoal}
                onChange={(e) => setInputGoal(e.target.value)}
                className="w-full pr-8 pl-3 py-1.5 rounded-xl border border-control bg-surface text-xs font-mono tabular-nums text-ink"
              />
              <span className="absolute right-2.5 top-1/2 -translate-y-1/2 text-xs text-ink-muted font-medium pointer-events-none">
                ml
              </span>
            </div>
            <button
              type="submit"
              className="px-3.5 py-1.5 rounded-xl border border-control bg-surface hover:bg-subtle text-ink text-xs font-semibold whitespace-nowrap flex-shrink-0 transition-colors duration-150"
            >
              Simpan
            </button>
          </div>
        </form>

        <form onSubmit={handleSaveEmpty} className="flex flex-col sm:flex-row sm:items-center gap-1.5 sm:gap-2">
          <label htmlFor="emptyCupInput" className="text-xs text-ink-soft font-medium sm:min-w-[112px] sm:whitespace-nowrap">
            Berat gelas kosong
          </label>
          <div className="flex items-center gap-2 flex-1 min-w-0">
            <div className="relative flex-1 min-w-0">
              <input
                id="emptyCupInput"
                type="number"
                min="35"
                max="300"
                step="0.5"
                disabled={controlsDisabled}
                value={inputEmpty}
                onChange={(e) => setInputEmpty(e.target.value)}
                className="w-full pr-7 pl-3 py-1.5 rounded-xl border border-control bg-surface disabled:opacity-50 disabled:cursor-not-allowed text-xs font-mono tabular-nums text-ink"
              />
              <span className="absolute right-2.5 top-1/2 -translate-y-1/2 text-xs text-ink-muted font-medium pointer-events-none">
                g
              </span>
            </div>
            <button
              type="submit"
              disabled={controlsDisabled}
              className="px-3.5 py-1.5 rounded-xl border border-control bg-surface hover:bg-subtle disabled:opacity-50 disabled:cursor-not-allowed text-ink text-xs font-semibold whitespace-nowrap flex-shrink-0 transition-colors duration-150"
            >
              Simpan
            </button>
          </div>
        </form>

        <button
          type="button"
          onClick={() => onCalibrateCup(Number(weight.toFixed(1)))}
          disabled={!canUseCurrentWeight}
          className="w-full px-3 py-2 rounded-xl border border-control bg-surface hover:bg-subtle disabled:opacity-50 disabled:cursor-not-allowed text-ink text-xs font-semibold transition-colors duration-150"
        >
          {weight >= 35 && weight <= 300
            ? `Pakai berat sekarang (${weight.toFixed(1)} g)`
            : 'Pakai berat sekarang (taruh gelas 35-300 g)'}
        </button>

        <div className="pt-1 space-y-2">
          <button
            type="button"
            onClick={() => {
              if (connMode === 'cloud') {
                setConfirmTareOpen((prev) => !prev);
              } else {
                onTare();
              }
            }}
            disabled={controlsDisabled}
            className="w-full flex items-center justify-center gap-2 px-3 py-2 rounded-xl border border-control bg-surface hover:bg-subtle disabled:opacity-50 disabled:cursor-not-allowed text-ink text-xs font-semibold whitespace-nowrap transition-colors duration-150"
          >
            <RotateCcw className="w-3.5 h-3.5 text-ink-soft" strokeWidth={1.75} aria-hidden="true" />
            <span>Nolkan timbangan</span>
          </button>

          {connMode === 'cloud' && confirmTareOpen && (
            <div
              className="p-3 rounded-xl border border-warn-border bg-warn-bg space-y-2"
              role="region"
              aria-label="Konfirmasi nolkan timbangan"
            >
              <p className="text-xs text-warn font-medium leading-relaxed">
                Pastikan tatakan benar-benar kosong tanpa gelas sebelum menolkan.
              </p>
              {weight >= 35 && (
                <p className="text-xs text-danger bg-danger-bg border border-danger-border rounded-lg px-2.5 py-1.5 font-medium">
                  Timbangan masih membaca {weight.toFixed(1)} g. Angkat gelas dulu agar titik nol tidak meleset.
                </p>
              )}
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  disabled={controlsDisabled}
                  onClick={() => {
                    setConfirmTareOpen(false);
                    onTare();
                  }}
                  className="px-3 py-1.5 rounded-lg bg-accent hover:bg-accent-hover text-accent-ink text-xs font-semibold transition-colors duration-150"
                >
                  Ya, nolkan
                </button>
                <button
                  type="button"
                  onClick={() => setConfirmTareOpen(false)}
                  className="px-3 py-1.5 rounded-lg border border-control bg-surface hover:bg-subtle text-ink text-xs font-semibold transition-colors duration-150"
                >
                  Batal
                </button>
              </div>
            </div>
          )}

          <button
            type="button"
            onClick={onResetDaily}
            disabled={connMode === 'cloud' || controlsDisabled}
            className="w-full px-3 py-2 rounded-xl border border-danger-border bg-surface hover:bg-danger-bg disabled:opacity-50 disabled:cursor-not-allowed text-danger text-xs font-semibold whitespace-nowrap transition-colors duration-150"
          >
            Mulai hitungan baru
          </button>

          {connMode === 'cloud' && (
            <p className="text-xs text-ink-muted leading-relaxed">
              Untuk memulai catatan sesi baru secara online, gunakan tombol Mulai sesi.
            </p>
          )}
        </div>
      </div>
    </section>
  );
});
