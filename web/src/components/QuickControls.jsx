import React, { useState, useEffect } from 'react';
import { RotateCcw, Volume2, VolumeX } from 'lucide-react';

export default function QuickControls({
  connMode = 'sim',
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

  useEffect(() => {
    setInputEmpty(emptyCup);
  }, [emptyCup]);

  useEffect(() => {
    setInputBaseMin(baseMin);
  }, [baseMin]);

  useEffect(() => {
    setInputGoal(dailyGoal);
  }, [dailyGoal]);

  const activeTimerMode = demo ? 'DEMO' : (autoDht ? 'AUTO_DHT' : 'MANUAL');

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
      className="bg-surface rounded-2xl p-5 border border-hairline flex flex-col gap-5"
      aria-label="Pengaturan tatakan dan target minum"
    >
      <div>
        <h2 className="text-base font-semibold text-ink tracking-tight">
          Pengaturan
        </h2>
        <p className="text-xs text-ink-soft mt-0.5">
          Atur jadwal pengingat, target minum, dan gelas
        </p>
      </div>

      {/* Bagian 1: Jadwal pengingat & suara */}
      <div className="space-y-3 pb-4 border-b border-hairline">
        <div className="flex items-center justify-between gap-2">
          <h3 className="text-xs font-semibold text-ink-soft">
            Jadwal pengingat
          </h3>
          <button
            type="button"
            onClick={onToggleMute}
            aria-pressed={buzzerMuted}
            className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg border text-xs font-semibold whitespace-nowrap transition-colors duration-150 ${
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
          className="grid grid-cols-3 gap-1.5 p-1 bg-subtle rounded-xl border border-hairline"
          role="group"
          aria-label="Cara mengatur jeda minum"
        >
          <button
            type="button"
            aria-pressed={activeTimerMode === 'AUTO_DHT'}
            onClick={() => onSelectTimerMode('AUTO_DHT')}
            className={`px-2 py-1.5 rounded-lg text-xs font-medium whitespace-nowrap transition-colors duration-150 ${
              activeTimerMode === 'AUTO_DHT'
                ? 'bg-surface text-ink font-semibold border border-hairline'
                : 'text-ink-soft hover:text-ink'
            }`}
          >
            Sesuai suhu
          </button>
          <button
            type="button"
            aria-pressed={activeTimerMode === 'MANUAL'}
            onClick={() => onSelectTimerMode('MANUAL')}
            className={`px-2 py-1.5 rounded-lg text-xs font-medium whitespace-nowrap transition-colors duration-150 ${
              activeTimerMode === 'MANUAL'
                ? 'bg-surface text-ink font-semibold border border-hairline'
                : 'text-ink-soft hover:text-ink'
            }`}
          >
            Manual
          </button>
          <button
            type="button"
            aria-pressed={activeTimerMode === 'DEMO'}
            onClick={() => onSelectTimerMode('DEMO')}
            className={`px-2 py-1.5 rounded-lg text-xs font-medium whitespace-nowrap transition-colors duration-150 ${
              activeTimerMode === 'DEMO'
                ? 'bg-surface text-ink font-semibold border border-hairline'
                : 'text-ink-soft hover:text-ink'
            }`}
          >
            Demo 15 dtk
          </button>
        </div>

        <form onSubmit={handleSaveInterval} className="flex items-center gap-2">
          <label htmlFor="baseMinInput" className="text-xs text-ink-soft font-medium whitespace-nowrap min-w-[112px]">
            Jeda minum
          </label>
          <div className="relative flex-1">
            <input
              id="baseMinInput"
              type="number"
              min="1"
              max="180"
              step="1"
              value={inputBaseMin}
              onChange={(e) => setInputBaseMin(e.target.value)}
              className="w-full pr-12 pl-3 py-1.5 rounded-xl border border-control bg-surface text-xs font-mono tabular-nums text-ink"
            />
            <span className="absolute right-2.5 top-1/2 -translate-y-1/2 text-xs text-ink-muted font-medium pointer-events-none">
              menit
            </span>
          </div>
          <button
            type="submit"
            className="px-3 py-1.5 rounded-xl border border-control bg-surface hover:bg-subtle text-ink text-xs font-semibold whitespace-nowrap transition-colors duration-150"
          >
            Atur
          </button>
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

      {/* Bagian 2: Target harian & ukuran gelas */}
      <div className="space-y-3">
        <h3 className="text-xs font-semibold text-ink-soft">
          Target harian & gelas
        </h3>

        <form onSubmit={handleSaveGoal} className="flex items-center gap-2">
          <label htmlFor="dailyGoalInput" className="text-xs text-ink-soft font-medium whitespace-nowrap min-w-[112px]">
            Target harian
          </label>
          <div className="relative flex-1">
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
            className="px-3 py-1.5 rounded-xl border border-control bg-surface hover:bg-subtle text-ink text-xs font-semibold whitespace-nowrap transition-colors duration-150"
          >
            Simpan
          </button>
        </form>

        <form onSubmit={handleSaveEmpty} className="flex items-center gap-2">
          <label htmlFor="emptyCupInput" className="text-xs text-ink-soft font-medium whitespace-nowrap min-w-[112px]">
            Berat gelas kosong
          </label>
          <div className="relative flex-1">
            <input
              id="emptyCupInput"
              type="number"
              min="35"
              max="300"
              step="0.5"
              value={inputEmpty}
              onChange={(e) => setInputEmpty(e.target.value)}
              className="w-full pr-7 pl-3 py-1.5 rounded-xl border border-control bg-surface text-xs font-mono tabular-nums text-ink"
            />
            <span className="absolute right-2.5 top-1/2 -translate-y-1/2 text-xs text-ink-muted font-medium pointer-events-none">
              g
            </span>
          </div>
          <button
            type="submit"
            className="px-3 py-1.5 rounded-xl border border-control bg-surface hover:bg-subtle text-ink text-xs font-semibold whitespace-nowrap transition-colors duration-150"
          >
            Simpan
          </button>
        </form>

        <div className="pt-1 space-y-2">
          <button
            type="button"
            onClick={onTare}
            disabled={connMode === 'cloud'}
            className="w-full flex items-center justify-center gap-2 px-3 py-2 rounded-xl border border-control bg-surface hover:bg-subtle disabled:opacity-50 disabled:cursor-not-allowed text-ink text-xs font-semibold whitespace-nowrap transition-colors duration-150"
          >
            <RotateCcw className="w-3.5 h-3.5 text-ink-soft" strokeWidth={1.75} aria-hidden="true" />
            <span>Nolkan timbangan</span>
          </button>

          <button
            type="button"
            onClick={onResetDaily}
            disabled={connMode === 'cloud'}
            className="w-full px-3 py-2 rounded-xl border border-danger-border bg-surface hover:bg-danger-bg disabled:opacity-50 disabled:cursor-not-allowed text-danger text-xs font-semibold whitespace-nowrap transition-colors duration-150"
          >
            Mulai hitungan baru
          </button>

          {connMode === 'cloud' && (
            <p className="text-xs text-ink-muted leading-relaxed">
              Penyetelan nol timbangan tersedia lewat kabel USB. Untuk memulai catatan baru secara online, gunakan tombol Mulai sesi.
            </p>
          )}
        </div>
      </div>
    </section>
  );
}
