import React from 'react';
import { FlaskConical, Play, FastForward } from 'lucide-react';

const SCENARIOS = [
  { id: 1, title: '1. Taruh Gelas (350 g)', desc: 'IDLE -> STABLE -> TIMING' },
  { id: 2, title: '2. Alarm Minum', desc: 'Timer habis -> ALERT_DRINK' },
  { id: 3, title: '3. Tegukan Kecil (-10 g)', desc: 'Angkat & kembali < 20 ml -> CHEAT' },
  { id: 4, title: '4. Minum Valid (-150 g)', desc: 'Volume tercatat -> TIMING ulang' },
  { id: 5, title: '5. Sedot Tanpa Angkat', desc: 'Turun >= 20 g stabil -> tercatat' },
  { id: 6, title: '6. Gelas Kosong & Refill', desc: 'REFILL -> tuang air -> TIMING' },
  { id: 7, title: '7. Lupa Taruh (> 10 dtk)', desc: 'LIFTED > batas -> REFILL' },
  { id: 8, title: '8. Ruangan Panas (33 °C)', desc: 'Kompensasi adaptif mempercepat timer' }
];

export default function LabSimulatorPanel({
  weight = 0,
  onWeightChange,
  temp = 27.0,
  onTempChange,
  hum = 60,
  onHumChange,
  warp = 1,
  onWarpChange,
  simClockSec = 0,
  activeScenario = null,
  scenarioStepText = '',
  onRunScenario
}) {
  const formatClock = (totalSec) => {
    const s = Math.max(0, Math.floor(totalSec));
    const m = Math.floor(s / 60);
    const sec = s % 60;
    return String(m).padStart(2, '0') + ':' + String(sec).padStart(2, '0');
  };

  return (
    <section
      className="bg-white rounded-2xl p-5 border border-slate-200 shadow-soft space-y-4"
      aria-label="Panel laboratorium simulator FSM"
    >
      <div className="flex flex-wrap items-center justify-between gap-3 pb-3 border-b border-slate-200/80">
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-lg bg-emerald-50 border border-emerald-200 flex items-center justify-center text-emerald-800">
            <FlaskConical className="w-4 h-4" aria-hidden="true" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h2 className="font-display text-base font-bold text-slate-900 tracking-tight">
                Laboratorium Simulator FSM
              </h2>
              <span className="px-2 py-0.5 rounded-md text-[11px] font-semibold bg-emerald-50 text-emerald-800 border border-emerald-200">
                Khusus Mode Simulator
              </span>
            </div>
            <p className="text-xs text-slate-600 mt-0.5">
              Uji 7 state FSM, gangguan sensor HX711/DHT11, dan 8 skenario verifikasi otomatis
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <span className="text-xs font-mono font-semibold text-slate-700 bg-slate-100 border border-slate-200 px-2.5 py-1 rounded-lg tabular-nums">
            Jam Sim: {formatClock(simClockSec)}
          </span>
          <div
            className="inline-flex p-1 bg-slate-100 rounded-xl border border-slate-200 text-xs font-mono"
            role="group"
            aria-label="Percepatan waktu simulasi"
          >
            {[1, 5, 30, 60, 600].map((w) => (
              <button
                key={w}
                type="button"
                aria-pressed={warp === w}
                onClick={() => onWarpChange(w)}
                className={`px-2 py-1 rounded-lg transition-colors ${
                  warp === w
                    ? 'bg-white text-slate-900 font-bold shadow-sm border border-slate-200/80'
                    : 'text-slate-700 hover:text-slate-900'
                }`}
              >
                x{w}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Sliders: Berat, Suhu, Kelembapan */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="p-3 rounded-xl bg-slate-50 border border-slate-200/80 space-y-1.5">
          <div className="flex justify-between text-xs">
            <label htmlFor="simWeightSlider" className="font-semibold text-slate-700">
              Beban Load Cell HX711
            </label>
            <span className="font-mono font-bold text-slate-900 tabular-nums">
              {Number(weight).toFixed(1)} g
            </span>
          </div>
          <input
            id="simWeightSlider"
            type="range"
            min="0"
            max="550"
            step="1"
            value={weight}
            onChange={(e) => onWeightChange(Number(e.target.value))}
            className="w-full accent-water-700"
          />
          <div className="flex justify-between text-[11px] text-slate-600 font-mono">
            <span>0 g</span>
            <span>Kosong 130 g</span>
            <span>Penuh 550 g</span>
          </div>
        </div>

        <div className="p-3 rounded-xl bg-slate-50 border border-slate-200/80 space-y-1.5">
          <div className="flex justify-between text-xs">
            <label htmlFor="simTempSlider" className="font-semibold text-slate-700">
              Suhu Ruang Simulasi
            </label>
            <span className="font-mono font-bold text-slate-900 tabular-nums">
              {Number(temp).toFixed(1)} °C
            </span>
          </div>
          <input
            id="simTempSlider"
            type="range"
            min="16"
            max="38"
            step="0.5"
            value={temp}
            onChange={(e) => onTempChange(Number(e.target.value))}
            className="w-full accent-water-700"
          />
          <div className="flex justify-between text-[11px] text-slate-600 font-mono">
            <span>16 °C (Sejuk)</span>
            <span>26 °C</span>
            <span>38 °C (Panas)</span>
          </div>
        </div>

        <div className="p-3 rounded-xl bg-slate-50 border border-slate-200/80 space-y-1.5">
          <div className="flex justify-between text-xs">
            <label htmlFor="simHumSlider" className="font-semibold text-slate-700">
              Kelembapan Relatif (RH)
            </label>
            <span className="font-mono font-bold text-slate-900 tabular-nums">
              {Math.round(hum)}%
            </span>
          </div>
          <input
            id="simHumSlider"
            type="range"
            min="20"
            max="90"
            step="1"
            value={hum}
            onChange={(e) => onHumChange(Number(e.target.value))}
            className="w-full accent-water-700"
          />
          <div className="flex justify-between text-[11px] text-slate-600 font-mono">
            <span>20% (Kering)</span>
            <span>50%</span>
            <span>90% (Lembap)</span>
          </div>
        </div>
      </div>

      {/* 8 Automated Verification Scenarios */}
      <div className="space-y-2">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <span className="text-xs font-semibold text-slate-700">
            Skenario Uji Otomatis (Paritas 1:1 C++ / Python / JS)
          </span>
          {scenarioStepText && (
            <span
              className="text-xs font-mono font-semibold text-water-800 bg-sky-50 border border-sky-200 px-2.5 py-0.5 rounded-md"
              role="status"
            >
              {scenarioStepText}
            </span>
          )}
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-2">
          {SCENARIOS.map((sc) => {
            const isRunning = activeScenario === sc.id;
            return (
              <button
                key={sc.id}
                type="button"
                onClick={() => onRunScenario(sc.id)}
                className={`p-2.5 rounded-xl border text-left transition-colors flex flex-col justify-between ${
                  isRunning
                    ? 'bg-sky-50 border-sky-300 text-sky-900'
                    : 'bg-white hover:bg-slate-50 border-slate-200 text-slate-800'
                }`}
              >
                <div className="flex items-center justify-between gap-2">
                  <span className="text-xs font-bold tracking-tight">{sc.title}</span>
                  {isRunning ? (
                    <FastForward className="w-3.5 h-3.5 text-water-700 flex-shrink-0" aria-hidden="true" />
                  ) : (
                    <Play className="w-3.5 h-3.5 text-slate-500 flex-shrink-0" aria-hidden="true" />
                  )}
                </div>
                <span className="text-[11px] text-slate-600 mt-1 font-mono">{sc.desc}</span>
              </button>
            );
          })}
        </div>
      </div>
    </section>
  );
}
