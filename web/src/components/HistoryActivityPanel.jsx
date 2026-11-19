import React, { useState } from 'react';
import { Calendar, Terminal, Activity, Download, Trash2 } from 'lucide-react';

export default function HistoryActivityPanel({
  dailyHistory = {},
  todayDateKey = '',
  todayMl = 0,
  todayDrinks = 0,
  dailyGoal = 2000,
  logs = [],
  onClearLogs,
  onExportCsv,
  weightHistory = [],
  emptyCup = 130
}) {
  const [activeTab, setActiveTab] = useState('history'); // 'history' | 'logs' | 'weight'

  const getLast7Days = () => {
    const days = [];
    const now = new Date();
    for (let i = 6; i >= 0; i--) {
      const d = new Date(now);
      d.setDate(now.getDate() - i);
      const key =
        d.getFullYear() +
        '-' +
        String(d.getMonth() + 1).padStart(2, '0') +
        '-' +
        String(d.getDate()).padStart(2, '0');
      const label = d.toLocaleDateString('id-ID', { weekday: 'short', day: 'numeric' });
      const rec = dailyHistory[key] || {};
      const isToday = key === todayDateKey;
      const ml = isToday
        ? Math.max(Number(rec.total_ml || 0), Math.round(todayMl))
        : Math.round(Number(rec.total_ml || 0));
      const drinks = isToday
        ? Math.max(Number(rec.drink_count || 0), todayDrinks)
        : Number(rec.drink_count || 0);
      days.push({ key, label, ml, drinks, isToday });
    }
    return days;
  };

  const days7 = getLast7Days();
  const maxBarMl = Math.max(dailyGoal, ...days7.map((d) => d.ml), 500);

  const renderWeightChart = () => {
    const pts = weightHistory.length > 0 ? weightHistory : [0];
    const maxW = 550;
    const wSvg = 540;
    const hSvg = 150;
    const polyPoints = pts
      .map((val, idx) => {
        const x = pts.length === 1 ? wSvg / 2 : (idx / (pts.length - 1)) * wSvg;
        const clamped = Math.min(maxW, Math.max(0, Number(val) || 0));
        const y = hSvg - (clamped / maxW) * (hSvg - 20) - 10;
        return `${x.toFixed(1)},${y.toFixed(1)}`;
      })
      .join(' ');

    const yEmpty = hSvg - (Math.min(maxW, emptyCup) / maxW) * (hSvg - 20) - 10;
    const yCupOn = hSvg - (35 / maxW) * (hSvg - 20) - 10;

    return (
      <div className="space-y-3">
        <div className="flex flex-wrap items-center justify-between gap-2 text-xs text-slate-600">
          <span>30 sampel pembacaan beban terakhir (0 - 550 g)</span>
          <div className="flex items-center gap-4 font-mono">
            <span className="inline-flex items-center gap-1.5">
              <span className="w-2.5 h-0.5 bg-emerald-600 inline-block" />
              Gelas kosong ({Math.round(emptyCup)} g)
            </span>
            <span className="inline-flex items-center gap-1.5">
              <span className="w-2.5 h-0.5 bg-amber-600 inline-block" />
              Ambang deteksi (35 g)
            </span>
          </div>
        </div>

        <div className="bg-slate-50 rounded-xl border border-slate-200 p-3">
          <svg
            viewBox={`0 0 ${wSvg} ${hSvg}`}
            className="w-full h-40 overflow-visible"
            role="img"
            aria-label="Grafik riwayat berat tatakan"
          >
            <line
              x1="0"
              y1={yEmpty}
              x2={wSvg}
              y2={yEmpty}
              stroke="#059669"
              strokeDasharray="4 4"
              strokeWidth="1.2"
            />
            <line
              x1="0"
              y1={yCupOn}
              x2={wSvg}
              y2={yCupOn}
              stroke="#D97706"
              strokeDasharray="3 3"
              strokeWidth="1"
            />
            <polyline
              fill="none"
              stroke="#0284C7"
              strokeWidth="2.5"
              strokeLinecap="round"
              strokeLinejoin="round"
              points={polyPoints}
            />
          </svg>
        </div>
      </div>
    );
  };

  return (
    <section
      className="bg-white rounded-2xl p-5 border border-slate-200 shadow-soft flex flex-col justify-between"
      aria-label="Riwayat hidrasi dan log aktivitas"
    >
      <div>
        <div className="flex flex-wrap items-center justify-between gap-3 pb-4 border-b border-slate-200/80">
          <div>
            <h2 className="font-display text-base font-bold text-slate-900 tracking-tight">
              Riwayat & Diagnostik Sensor
            </h2>
            <p className="text-xs text-slate-600 mt-0.5">
              Capaian hidrasi 7 hari terakhir, log kejadian, dan kurva berat
            </p>
          </div>

          <div
            className="inline-flex p-1 bg-slate-100 rounded-xl border border-slate-200 text-xs font-medium"
            role="tablist"
            aria-label="Tab riwayat dan diagnostik"
          >
            <button
              type="button"
              role="tab"
              id="tab-history"
              aria-selected={activeTab === 'history'}
              aria-controls="panel-history"
              onClick={() => setActiveTab('history')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg transition-colors ${
                activeTab === 'history'
                  ? 'bg-white text-slate-900 font-semibold shadow-sm border border-slate-200/80'
                  : 'text-slate-700 hover:text-slate-900'
              }`}
            >
              <Calendar className="w-3.5 h-3.5" aria-hidden="true" />
              <span>Riwayat 7 Hari</span>
            </button>
            <button
              type="button"
              role="tab"
              id="tab-logs"
              aria-selected={activeTab === 'logs'}
              aria-controls="panel-logs"
              onClick={() => setActiveTab('logs')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg transition-colors ${
                activeTab === 'logs'
                  ? 'bg-white text-slate-900 font-semibold shadow-sm border border-slate-200/80'
                  : 'text-slate-700 hover:text-slate-900'
              }`}
            >
              <Terminal className="w-3.5 h-3.5" aria-hidden="true" />
              <span>Log Sensor ({logs.length})</span>
            </button>
            <button
              type="button"
              role="tab"
              id="tab-weight"
              aria-selected={activeTab === 'weight'}
              aria-controls="panel-weight"
              onClick={() => setActiveTab('weight')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg transition-colors ${
                activeTab === 'weight'
                  ? 'bg-white text-slate-900 font-semibold shadow-sm border border-slate-200/80'
                  : 'text-slate-700 hover:text-slate-900'
              }`}
            >
              <Activity className="w-3.5 h-3.5" aria-hidden="true" />
              <span>Kurva Berat</span>
            </button>
          </div>
        </div>

        {/* Panel 1: Riwayat 7 Hari */}
        {activeTab === 'history' && (
          <div
            id="panel-history"
            role="tabpanel"
            aria-labelledby="tab-history"
            className="pt-4 space-y-4"
          >
            <div className="flex items-center justify-between text-xs text-slate-600">
              <span>Perbandingan volume minum harian terhadap target {dailyGoal} ml</span>
              <span className="font-mono font-semibold text-water-800">
                Target: {dailyGoal} ml/hari
              </span>
            </div>

            <div className="grid grid-cols-7 gap-2 pt-2 items-end h-44 bg-slate-50 rounded-xl border border-slate-200 p-3">
              {days7.map((d) => {
                const heightPct = Math.min(100, Math.max(4, Math.round((d.ml / maxBarMl) * 100)));
                const reachedGoal = d.ml >= dailyGoal;
                return (
                  <div key={d.key} className="flex flex-col items-center h-full justify-end">
                    <span className="text-[11px] font-mono font-semibold text-slate-700 tabular-nums mb-1">
                      {d.ml > 0 ? `${d.ml}` : '0'}
                    </span>
                    <div className="w-full max-w-[36px] bg-slate-200/70 rounded-t-lg h-24 flex items-end overflow-hidden">
                      <div
                        className={`w-full rounded-t-lg transition-all duration-300 ${
                          reachedGoal
                            ? 'bg-emerald-600'
                            : d.isToday
                              ? 'bg-water-700'
                              : 'bg-water-500'
                        }`}
                        style={{ height: `${d.ml > 0 ? heightPct : 4}%` }}
                      />
                    </div>
                    <span
                      className={`mt-1.5 text-[11px] font-medium truncate max-w-full ${
                        d.isToday ? 'text-water-800 font-bold' : 'text-slate-700'
                      }`}
                    >
                      {d.isToday ? 'Hari ini' : d.label}
                    </span>
                    <span className="text-[10px] font-mono text-slate-600">
                      {d.drinks}x
                    </span>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* Panel 2: Log Aktivitas Sensor */}
        {activeTab === 'logs' && (
          <div
            id="panel-logs"
            role="tabpanel"
            aria-labelledby="tab-logs"
            className="pt-4 space-y-3"
          >
            <div className="flex flex-wrap items-center justify-between gap-2">
              <span className="text-xs text-slate-600">
                Catatan transisi FSM, pembacaan serial, dan sinkronisasi cloud
              </span>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={onExportCsv}
                  className="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-slate-800 text-xs font-semibold transition-colors"
                >
                  <Download className="w-3.5 h-3.5" aria-hidden="true" />
                  <span>Unduh CSV</span>
                </button>
                <button
                  type="button"
                  onClick={onClearLogs}
                  className="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-slate-700 text-xs font-medium transition-colors"
                >
                  <Trash2 className="w-3.5 h-3.5" aria-hidden="true" />
                  <span>Bersihkan</span>
                </button>
              </div>
            </div>

            <div className="bg-slate-50 rounded-xl border border-slate-200 p-3 h-48 overflow-y-auto font-mono text-xs space-y-1.5">
              {logs.length === 0 ? (
                <div className="text-slate-600 py-8 text-center">
                  Belum ada catatan aktivitas pada sesi ini.
                </div>
              ) : (
                logs.map((item, idx) => (
                  <div
                    key={idx}
                    className="flex items-start gap-2 py-1 border-b border-slate-200/60 last:border-b-0 text-slate-800"
                  >
                    <span className="text-slate-600 tabular-nums flex-shrink-0">
                      [{item.time}]
                    </span>
                    <span className="px-1.5 py-0.2 rounded bg-white border border-slate-300 text-slate-800 font-semibold text-[11px] flex-shrink-0">
                      {item.tag}
                    </span>
                    <span className="break-words">{item.msg}</span>
                  </div>
                ))
              )}
            </div>
          </div>
        )}

        {/* Panel 3: Kurva Berat */}
        {activeTab === 'weight' && (
          <div
            id="panel-weight"
            role="tabpanel"
            aria-labelledby="tab-weight"
            className="pt-4"
          >
            {renderWeightChart()}
          </div>
        )}
      </div>
    </section>
  );
}
