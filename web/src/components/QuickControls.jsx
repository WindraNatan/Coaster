import React, { useState, useEffect } from 'react';
import { RotateCcw, Volume2, VolumeX, Sliders, Check, Clock, AlertTriangle } from 'lucide-react';

export default function QuickControls({
  emptyCup = 130,
  onCalibrateCup,
  onTare,
  autoDht = true,
  onToggleAuto,
  demo = true,
  onToggleDemo,
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
    if (!isNaN(val) && val >= 250 && val <= 6000) {
      onSaveGoal(val);
    }
  };

  return (
    <div className="bg-white rounded-2xl p-5 border border-slate-200/80 shadow-soft hover:shadow-soft-lg transition-all flex flex-col gap-5">
      <div>
        <h2 className="text-base font-bold text-slate-900 tracking-tight">
          Kontrol & Konfigurasi Cepat
        </h2>
        <p className="text-xs text-slate-500 mt-0.5">
          Pengaturan sensor, mode pengingat, dan target hidrasi
        </p>
      </div>

      {/* Section 1: Timbangan & Gelas */}
      <div className="space-y-3 pb-4 border-b border-slate-100">
        <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider block">
          Timbangan & Gelas
        </span>

        <button
          type="button"
          onClick={onTare}
          className="w-full flex items-center justify-center gap-2 px-3 py-2 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 text-xs font-medium transition-colors shadow-sm"
          title="Nol-kan timbangan tatakan"
        >
          <RotateCcw className="w-3.5 h-3.5 text-slate-500" />
          <span>Nol-kan Timbangan (Tare)</span>
        </button>

        <form onSubmit={handleSaveEmpty} className="flex items-center gap-2">
          <label htmlFor="emptyCupInput" className="text-xs text-slate-600 font-medium whitespace-nowrap min-w-[110px]">
            Berat Kosong
          </label>
          <div className="relative flex-1">
            <input
              id="emptyCupInput"
              type="number"
              min="35"
              max="300"
              step="1"
              value={inputEmpty}
              onChange={(e) => setInputEmpty(e.target.value)}
              className="w-full pr-8 pl-3 py-1.5 rounded-xl border border-slate-200 text-xs font-mono tabular-nums text-slate-800 focus:outline-none focus:ring-2 focus:ring-water-500/20 focus:border-water-500"
            />
            <span className="absolute right-2.5 top-1/2 -translate-y-1/2 text-xs text-slate-400 font-medium pointer-events-none">
              g
            </span>
          </div>
          <button
            type="submit"
            className="px-3 py-1.5 rounded-xl bg-water-600 hover:bg-water-700 text-white text-xs font-medium transition-colors shadow-sm"
          >
            Simpan
          </button>
        </form>
      </div>

      {/* Section 2: Mode Timer & Pengingat */}
      <div className="space-y-3 pb-4 border-b border-slate-100">
        <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider block">
          Mode Timer & Pengingat
        </span>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
          <button
            type="button"
            onClick={onToggleAuto}
            className={`px-3 py-1.5 rounded-xl border text-xs font-medium transition-all ${
              autoDht
                ? 'bg-sky-50 text-sky-700 border-sky-200 font-semibold'
                : 'bg-white text-slate-700 border-slate-200 hover:bg-slate-50'
            }`}
          >
            {autoDht ? 'Timer: Otomatis' : 'Timer: Manual'}
          </button>

          <button
            type="button"
            onClick={onToggleDemo}
            className={`px-3 py-1.5 rounded-xl border text-xs font-medium transition-all ${
              demo
                ? 'bg-sky-50 text-sky-700 border-sky-200 font-semibold'
                : 'bg-white text-slate-700 border-slate-200 hover:bg-slate-50'
            }`}
          >
            {demo ? 'Demo: 15 dtk' : 'Demo: Mati'}
          </button>

          <button
            type="button"
            onClick={onToggleMute}
            className={`flex items-center justify-center gap-1.5 px-3 py-1.5 rounded-xl border text-xs font-medium transition-all ${
              buzzerMuted
                ? 'bg-amber-50 text-amber-700 border-amber-200 font-semibold'
                : 'bg-white text-slate-700 border-slate-200 hover:bg-slate-50'
            }`}
            title="Buzzer hening, indikator getar tetap aktif"
          >
            {buzzerMuted ? <VolumeX className="w-3.5 h-3.5" /> : <Volume2 className="w-3.5 h-3.5" />}
            <span>{buzzerMuted ? 'Hening' : 'Buzzer ON'}</span>
          </button>
        </div>

        <form onSubmit={handleSaveInterval} className="flex items-center gap-2">
          <label htmlFor="baseMinInput" className="text-xs text-slate-600 font-medium whitespace-nowrap min-w-[110px]">
            Interval Dasar
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
              className="w-full pr-10 pl-3 py-1.5 rounded-xl border border-slate-200 text-xs font-mono tabular-nums text-slate-800 focus:outline-none focus:ring-2 focus:ring-water-500/20 focus:border-water-500"
            />
            <span className="absolute right-2.5 top-1/2 -translate-y-1/2 text-xs text-slate-400 font-medium pointer-events-none">
              mnt
            </span>
          </div>
          <button
            type="submit"
            className="px-3 py-1.5 rounded-xl bg-water-600 hover:bg-water-700 text-white text-xs font-medium transition-colors shadow-sm"
          >
            Atur
          </button>
        </form>

        {timerHint && (
          <p className="text-[11px] text-amber-600 bg-amber-50 border border-amber-200/60 rounded-lg p-2 leading-relaxed">
            {timerHint}
          </p>
        )}
      </div>

      {/* Section 3: Target Hidrasi & Reset */}
      <div className="space-y-3">
        <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider block">
          Target Hidrasi & Sesi
        </span>

        <form onSubmit={handleSaveGoal} className="flex items-center gap-2">
          <label htmlFor="dailyGoalInput" className="text-xs text-slate-600 font-medium whitespace-nowrap min-w-[110px]">
            Target Harian
          </label>
          <div className="relative flex-1">
            <input
              id="dailyGoalInput"
              type="number"
              min="250"
              max="6000"
              step="50"
              value={inputGoal}
              onChange={(e) => setInputGoal(e.target.value)}
              className="w-full pr-8 pl-3 py-1.5 rounded-xl border border-slate-200 text-xs font-mono tabular-nums text-slate-800 focus:outline-none focus:ring-2 focus:ring-water-500/20 focus:border-water-500"
            />
            <span className="absolute right-2.5 top-1/2 -translate-y-1/2 text-xs text-slate-400 font-medium pointer-events-none">
              ml
            </span>
          </div>
          <button
            type="submit"
            className="px-3 py-1.5 rounded-xl bg-water-600 hover:bg-water-700 text-white text-xs font-medium transition-colors shadow-sm"
          >
            Simpan
          </button>
        </form>

        <button
          type="button"
          onClick={onResetDaily}
          className="w-full mt-2 px-3 py-2 rounded-xl border border-rose-200 bg-white hover:bg-rose-50 text-rose-600 text-xs font-medium transition-colors shadow-sm flex items-center justify-center gap-1.5"
        >
          <AlertTriangle className="w-3.5 h-3.5" />
          <span>Reset Harian (Mulai Hari Baru)</span>
        </button>
      </div>
    </div>
  );
}
