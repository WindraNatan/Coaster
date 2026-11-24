import React, { useState } from 'react';
import { ChevronDown, ChevronUp, Play, FastForward } from 'lucide-react';

const SCENARIOS = [
  { id: 1, title: '1. Letakkan gelas', desc: 'Gelas 350 ml ditaruh hingga siap' },
  { id: 2, title: '2. Pengingat minum', desc: 'Waktu habis memicu pengingat' },
  { id: 3, title: '3. Tegukan terlalu sedikit', desc: 'Ambil dan taruh ulang < 20 ml' },
  { id: 4, title: '4. Minum normal', desc: 'Berkurang 150 ml lalu timer ulang' },
  { id: 5, title: '5. Minum pakai sedotan', desc: 'Berkurang 30 ml tanpa mengangkat' },
  { id: 6, title: '6. Gelas kosong lalu diisi', desc: 'Peringatan habis lalu tuang 240 ml' },
  { id: 7, title: '7. Lupa menaruh gelas', desc: 'Terangkat melebihi batas waktu' },
  { id: 8, title: '8. Ruangan terasa panas', desc: 'Suhu 33 °C mempercepat pengingat' }
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
  const [expanded, setExpanded] = useState(true);

  const formatClock = (totalSec) => {
    const s = Math.max(0, Math.floor(totalSec));
    const m = Math.floor(s / 60);
    const sec = s % 60;
    return String(m).padStart(2, '0') + ':' + String(sec).padStart(2, '0');
  };

  return (
    <section
      className="bg-surface rounded-2xl p-5 border border-hairline space-y-4"
      aria-label="Panel simulasi presentasi"
    >
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="text-base font-semibold text-ink tracking-tight">
            Simulasi presentasi
          </h2>
          <p className="text-xs text-ink-soft mt-0.5">
            Uji seluruh skenario pemakaian tatakan tanpa perangkat fisik
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <div className="px-2.5 py-1 rounded-lg bg-subtle text-xs text-ink-soft">
            <span>Waktu simulasi </span>
            <span className="font-mono tabular-nums text-ink font-semibold">
              {formatClock(simClockSec)}
            </span>
          </div>

          <div
            className="inline-flex p-1 bg-subtle rounded-xl border border-hairline text-xs"
            role="group"
            aria-label="Kecepatan waktu simulasi"
          >
            {[1, 5, 30, 60, 600].map((w) => (
              <button
                key={w}
                type="button"
                aria-pressed={warp === w}
                onClick={() => onWarpChange(w)}
                className={`px-2 py-1 rounded-lg whitespace-nowrap transition-colors duration-150 ${
                  warp === w
                    ? 'bg-surface text-ink font-semibold border border-hairline'
                    : 'text-ink-soft hover:text-ink'
                }`}
              >
                <span className="font-mono tabular-nums">{w}</span>x
              </button>
            ))}
          </div>

          <button
            type="button"
            onClick={() => setExpanded((v) => !v)}
            aria-expanded={expanded}
            className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg border border-control bg-surface hover:bg-subtle text-ink text-xs font-medium whitespace-nowrap transition-colors duration-150"
          >
            <span>{expanded ? 'Sembunyikan' : 'Tampilkan'}</span>
            {expanded ? (
              <ChevronUp className="w-3.5 h-3.5" strokeWidth={1.75} aria-hidden="true" />
            ) : (
              <ChevronDown className="w-3.5 h-3.5" strokeWidth={1.75} aria-hidden="true" />
            )}
          </button>
        </div>
      </div>

      {expanded && (
        <div className="space-y-4 pt-3 border-t border-hairline">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="p-3 rounded-xl bg-subtle space-y-1.5">
              <div className="flex justify-between text-xs">
                <label htmlFor="simWeightSlider" className="font-semibold text-ink-soft">
                  Berat di tatakan
                </label>
                <span className="font-semibold text-ink">
                  <span className="font-mono tabular-nums">{Number(weight).toFixed(1)}</span>
                  <span> g</span>
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
                className="w-full accent-accent"
              />
              <div className="flex justify-between text-xs text-ink-muted">
                <span>0 g</span>
                <span>Kosong 130 g</span>
                <span>Penuh 550 g</span>
              </div>
            </div>

            <div className="p-3 rounded-xl bg-subtle space-y-1.5">
              <div className="flex justify-between text-xs">
                <label htmlFor="simTempSlider" className="font-semibold text-ink-soft">
                  Suhu ruangan
                </label>
                <span className="font-semibold text-ink">
                  <span className="font-mono tabular-nums">{Number(temp).toFixed(1)}</span>
                  <span> °C</span>
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
                className="w-full accent-accent"
              />
              <div className="flex justify-between text-xs text-ink-muted">
                <span>Sejuk 16 °C</span>
                <span>26 °C</span>
                <span>Panas 38 °C</span>
              </div>
            </div>

            <div className="p-3 rounded-xl bg-subtle space-y-1.5">
              <div className="flex justify-between text-xs">
                <label htmlFor="simHumSlider" className="font-semibold text-ink-soft">
                  Kelembapan udara
                </label>
                <span className="font-semibold text-ink">
                  <span className="font-mono tabular-nums">{Math.round(hum)}</span>
                  <span>%</span>
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
                className="w-full accent-accent"
              />
              <div className="flex justify-between text-xs text-ink-muted">
                <span>Kering 20%</span>
                <span>50%</span>
                <span>Lembap 90%</span>
              </div>
            </div>
          </div>

          <div className="space-y-2">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <span className="text-xs font-semibold text-ink-soft">
                Skenario demonstrasi otomatis
              </span>
              {scenarioStepText && (
                <span
                  className="text-xs font-medium text-accent bg-accent-soft px-2.5 py-0.5 rounded-md"
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
                    className={`p-3 rounded-xl border text-left transition-colors duration-150 flex flex-col justify-between ${
                      isRunning
                        ? 'bg-accent-soft border-accent text-ink'
                        : 'bg-surface hover:bg-subtle border-hairline text-ink'
                    }`}
                  >
                    <div className="flex items-center justify-between gap-2">
                      <span className="text-xs font-semibold">{sc.title}</span>
                      {isRunning ? (
                        <FastForward className="w-3.5 h-3.5 text-accent flex-shrink-0" strokeWidth={1.75} aria-hidden="true" />
                      ) : (
                        <Play className="w-3.5 h-3.5 text-ink-muted flex-shrink-0" strokeWidth={1.75} aria-hidden="true" />
                      )}
                    </div>
                    <span className="text-xs text-ink-soft mt-1">{sc.desc}</span>
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      )}
    </section>
  );
}
