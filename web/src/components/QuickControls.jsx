import React, { useState, useEffect } from 'react';
import { RotateCcw, Volume2, VolumeX, AlertTriangle } from 'lucide-react';

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
      className="bg-white rounded-2xl p-5 border border-slate-200 shadow-soft flex flex-col gap-5"
      aria-label="Kontrol dan konfigurasi tatakan"
    >
      <div>
        <h2 className="font-display text-base font-bold text-slate-900 tracking-tight">
          Konfigurasi Alat
        </h2>
        <p className="text-xs text-slate-600 mt-0.5">
          Kalibrasi gelas, mode pengingat, dan target harian
        </p>
      </div>

      {/* Section 1: Timbangan & Gelas */}
      <div className="space-y-3 pb-4 border-b border-slate-200/80">
        <h3 className="text-xs font-semibold text-slate-700">
          Timbangan & Kalibrasi Gelas
        </h3>

        <button
          type="button"
          onClick={onTare}
          disabled={connMode === 'cloud'}
          className="w-full flex items-center justify-center gap-2 px-3 py-2 rounded-xl border border-slate-300 bg-white hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed text-slate-800 text-xs font-semibold transition-colors"
        >
          <RotateCcw className="w-3.5 h-3.5 text-slate-600" aria-hidden="true" />
          <span>Nol-kan Timbangan (Tare)</span>
        </button>
        {connMode === 'cloud' && (
          <p className="text-[11px] text-slate-600 leading-relaxed">
            Tare hanya tersedia lewat USB Serial atau saat tatakan menyala tanpa beban.
          </p>
        )}

        <form onSubmit={handleSaveEmpty} className="flex items-center gap-2">
          <label htmlFor="emptyCupInput" className="text-xs text-slate-700 font-medium whitespace-nowrap min-w-[105px]">
            Gelas kosong
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
              className="w-full pr-7 pl-3 py-1.5 rounded-xl border border-slate-300 text-xs font-mono tabular-nums text-slate-900"
            />
            <span className="absolute right-2.5 top-1/2 -translate-y-1/2 text-xs text-slate-600 font-medium pointer-events-none">
              g
            </span>
          </div>
          <button
            type="submit"
            className="px-3 py-1.5 rounded-xl bg-water-700 hover:bg-water-800 text-white text-xs font-semibold transition-colors"
          >
            Simpan
          </button>
        </form>
      </div>

      {/* Section 2: Mode Timer & Suara */}
      <div className="space-y-3 pb-4 border-b border-slate-200/80">
        <div className="flex items-center justify-between">
          <h3 className="text-xs font-semibold text-slate-700">
            Mode Timer & Pengingat
          </h3>
          <button
            type="button"
            onClick={onToggleMute}
            aria-pressed={buzzerMuted}
            className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg border text-xs font-semibold transition-colors ${
              buzzerMuted
                ? 'bg-amber-50 text-amber-900 border-amber-300'
                : 'bg-emerald-50 text-emerald-800 border-emerald-300'
            }`}
          >
            {buzzerMuted ? (
              <VolumeX className="w-3.5 h-3.5" aria-hidden="true" />
            ) : (
              <Volume2 className="w-3.5 h-3.5" aria-hidden="true" />
            )}
            <span>{buzzerMuted ? 'Buzzer Hening' : 'Buzzer Aktif'}</span>
          </button>
        </div>

        <div
          className="grid grid-cols-3 gap-1.5 p-1 bg-slate-100 rounded-xl border border-slate-200"
          role="group"
          aria-label="Mode timer pengingat"
        >
          <button
            type="button"
            aria-pressed={activeTimerMode === 'AUTO_DHT'}
            onClick={() => onSelectTimerMode('AUTO_DHT')}
            className={`px-2 py-1.5 rounded-lg text-xs font-medium transition-colors ${
              activeTimerMode === 'AUTO_DHT'
                ? 'bg-white text-slate-900 font-semibold shadow-sm border border-slate-200/80'
                : 'text-slate-700 hover:text-slate-900'
            }`}
          >
            Otomatis
          </button>
          <button
            type="button"
            aria-pressed={activeTimerMode === 'MANUAL'}
            onClick={() => onSelectTimerMode('MANUAL')}
            className={`px-2 py-1.5 rounded-lg text-xs font-medium transition-colors ${
              activeTimerMode === 'MANUAL'
                ? 'bg-white text-slate-900 font-semibold shadow-sm border border-slate-200/80'
                : 'text-slate-700 hover:text-slate-900'
            }`}
          >
            Manual
          </button>
          <button
            type="button"
            aria-pressed={activeTimerMode === 'DEMO'}
            onClick={() => onSelectTimerMode('DEMO')}
            className={`px-2 py-1.5 rounded-lg text-xs font-medium transition-colors ${
              activeTimerMode === 'DEMO'
                ? 'bg-white text-slate-900 font-semibold shadow-sm border border-slate-200/80'
                : 'text-slate-700 hover:text-slate-900'
            }`}
          >
            Demo 15 dtk
          </button>
        </div>

        <form onSubmit={handleSaveInterval} className="flex items-center gap-2">
          <label htmlFor="baseMinInput" className="text-xs text-slate-700 font-medium whitespace-nowrap min-w-[105px]">
            Interval dasar
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
              className="w-full pr-10 pl-3 py-1.5 rounded-xl border border-slate-300 text-xs font-mono tabular-nums text-slate-900"
            />
            <span className="absolute right-2.5 top-1/2 -translate-y-1/2 text-xs text-slate-600 font-medium pointer-events-none">
              mnt
            </span>
          </div>
          <button
            type="submit"
            className="px-3 py-1.5 rounded-xl bg-water-700 hover:bg-water-800 text-white text-xs font-semibold transition-colors"
          >
            Atur
          </button>
        </form>

        {timerHint && (
          <p
            className="text-xs text-amber-900 bg-amber-50 border border-amber-300 rounded-xl p-2.5 leading-relaxed"
            role="status"
          >
            {timerHint}
          </p>
        )}
      </div>

      {/* Section 3: Target Hidrasi & Reset */}
      <div className="space-y-3">
        <h3 className="text-xs font-semibold text-slate-700">
          Target Hidrasi Harian
        </h3>

        <form onSubmit={handleSaveGoal} className="flex items-center gap-2">
          <label htmlFor="dailyGoalInput" className="text-xs text-slate-700 font-medium whitespace-nowrap min-w-[105px]">
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
              className="w-full pr-8 pl-3 py-1.5 rounded-xl border border-slate-300 text-xs font-mono tabular-nums text-slate-900"
            />
            <span className="absolute right-2.5 top-1/2 -translate-y-1/2 text-xs text-slate-600 font-medium pointer-events-none">
              ml
            </span>
          </div>
          <button
            type="submit"
            className="px-3 py-1.5 rounded-xl bg-water-700 hover:bg-water-800 text-white text-xs font-semibold transition-colors"
          >
            Simpan
          </button>
        </form>

        <button
          type="button"
          onClick={onResetDaily}
          disabled={connMode === 'cloud'}
          className="w-full mt-1 px-3 py-2 rounded-xl border border-rose-300 bg-white hover:bg-rose-50 disabled:opacity-50 disabled:cursor-not-allowed text-rose-800 text-xs font-semibold transition-colors flex items-center justify-center gap-1.5"
        >
          <AlertTriangle className="w-3.5 h-3.5" aria-hidden="true" />
          <span>Reset Statistik Harian</span>
        </button>
        {connMode === 'cloud' && (
          <p className="text-[11px] text-slate-600 leading-relaxed">
            Pada mode Cloud, gunakan tombol Mulai Sesi untuk memulai sesi pengguna baru.
          </p>
        )}
      </div>
    </section>
  );
}
