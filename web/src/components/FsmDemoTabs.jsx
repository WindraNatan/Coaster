import React, { useState, useRef, useEffect } from 'react';
import { Play, Download, BarChart2, ListFilter, Activity, Sliders, FastForward } from 'lucide-react';

export default function FsmDemoTabs({
  weight = 0,
  onWeightChange,
  warp = 1,
  onWarpChange,
  simClock = '00:00',
  onRunScenario,
  logs = [],
  onExportCsv,
  dailyHistory = {},
  dailyGoal = 2000,
  temp = 27.0,
  onTempChange,
  humidity = 60,
  onHumidityChange,
  telemetryStream = []
}) {
  const [activeTab, setActiveTab] = useState('scen');
  const logEndRef = useRef(null);

  useEffect(() => {
    if (activeTab === 'log' && logEndRef.current) {
      logEndRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  }, [logs, activeTab]);

  const demoScenarios = [
    { title: '1. Taruh gelas terisi', desc: 'Beban 380g, stabil 1.5s menuju TIMING' },
    { title: '2. Timer habis', desc: 'Hitung mundur habis, ALERT_DRINK aktif' },
    { title: '3. Tegukan kecil', desc: 'Sentuh tatakan / turun < 20ml (ALERT_CHEAT)' },
    { title: '4. Minum 120 ml', desc: 'Angkat, minum valid 120ml, taruh kembali' },
    { title: '5. Gelas kosong', desc: 'Air habis, memicu ALERT_EMPTY_CUP' },
    { title: '6. Isi ulang air', desc: 'Tambah +240ml air ke dalam gelas' },
    { title: '7. Gelas diangkat > 10s', desc: 'Angkat lama -> ALERT_MISSING_CUP' },
    { title: '8. Sedotan di tatakan', desc: 'Minum -30g via sedotan tanpa angkat gelas' }
  ];

  // 7-day intake chart calculation
  const renderChartData = () => {
    const days = [];
    const now = new Date();
    for (let i = 6; i >= 0; i--) {
      const d = new Date(now);
      d.setDate(d.getDate() - i);
      const k =
        d.getFullYear() +
        '-' +
        String(d.getMonth() + 1).padStart(2, '0') +
        '-' +
        String(d.getDate()).padStart(2, '0');
      const dayName = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'][d.getDay()];
      const entry = dailyHistory[k] || { total_ml: 0, drink_count: 0 };
      days.push({
        key: k,
        label: dayName,
        dateStr: `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}`,
        ml: entry.total_ml || 0,
        drinks: entry.drink_count || 0,
        isToday: i === 0
      });
    }
    return days;
  };

  const chartDays = renderChartData();
  const maxCap = Math.max(dailyGoal * 1.25, 2500);
  const chartH = 130;
  const targetY = chartH - 26 - Math.round((dailyGoal / maxCap) * (chartH - 48));

  // Telemetry stream line chart
  const teleW = 540;
  const teleH = 140;
  const maxWeightVal = 500;
  const telePoints = telemetryStream.slice(-30);
  const weightPath = telePoints
    .map((pt, i) => {
      const x = (i / Math.max(1, telePoints.length - 1)) * teleW;
      const y = teleH - (Math.min(maxWeightVal, Math.max(0, pt.w)) / maxWeightVal) * (teleH - 20) - 10;
      return `${i === 0 ? 'M' : 'L'} ${x} ${y}`;
    })
    .join(' ');

  return (
    <div className="bg-white rounded-2xl border border-slate-200/80 shadow-soft overflow-hidden">
      {/* Tab Switcher Header */}
      <div className="flex border-b border-slate-200/80 bg-slate-50/70 px-4 pt-3 gap-2 overflow-x-auto">
        <button
          type="button"
          onClick={() => setActiveTab('scen')}
          className={`flex items-center gap-2 px-4 py-2.5 rounded-t-xl text-xs font-semibold border-b-2 transition-all whitespace-nowrap ${
            activeTab === 'scen'
              ? 'border-water-600 bg-white text-slate-900 shadow-sm'
              : 'border-transparent text-slate-500 hover:text-slate-800'
          }`}
        >
          <Play className="w-3.5 h-3.5 text-water-600" />
          <span>Skenario Demo FSM (8 Tombol)</span>
        </button>

        <button
          type="button"
          onClick={() => setActiveTab('log')}
          className={`flex items-center gap-2 px-4 py-2.5 rounded-t-xl text-xs font-semibold border-b-2 transition-all whitespace-nowrap ${
            activeTab === 'log'
              ? 'border-water-600 bg-white text-slate-900 shadow-sm'
              : 'border-transparent text-slate-500 hover:text-slate-800'
          }`}
        >
          <Activity className="w-3.5 h-3.5 text-emerald-600" />
          <span>Log Sensor Real-time</span>
          <span className="ml-1 px-1.5 py-0.2 rounded-full text-[10px] bg-slate-200/80 text-slate-700">
            {logs.length}
          </span>
        </button>

        <button
          type="button"
          onClick={() => setActiveTab('history')}
          className={`flex items-center gap-2 px-4 py-2.5 rounded-t-xl text-xs font-semibold border-b-2 transition-all whitespace-nowrap ${
            activeTab === 'history'
              ? 'border-water-600 bg-white text-slate-900 shadow-sm'
              : 'border-transparent text-slate-500 hover:text-slate-800'
          }`}
        >
          <BarChart2 className="w-3.5 h-3.5 text-sky-600" />
          <span>Riwayat 7 Hari & Telemetri</span>
        </button>
      </div>

      {/* Tab Panels */}
      <div className="p-5">
        {/* Panel 1: Skenario Demo */}
        {activeTab === 'scen' && (
          <div className="space-y-6">
            {/* Header & Warp Speed */}
            <div className="flex flex-wrap items-center justify-between gap-3 pb-3 border-b border-slate-100">
              <div>
                <h3 className="text-sm font-bold text-slate-900">
                  Simulator Beban & Skenario Demo Laboratorium
                </h3>
                <p className="text-xs text-slate-500 mt-0.5">
                  Injeksi bobot tatakan dan pengujian otomatis 8 skenario evaluasi FSM
                </p>
              </div>

              <div className="flex items-center gap-3">
                <span className="text-xs font-mono font-medium text-slate-600 bg-slate-100 px-2.5 py-1 rounded-lg border border-slate-200">
                  T+<b>{simClock}</b>
                </span>
                <div className="inline-flex p-0.5 bg-slate-100 rounded-lg border border-slate-200 text-xs">
                  {[1, 10, 60, 600].map((w) => (
                    <button
                      key={w}
                      type="button"
                      onClick={() => onWarpChange(w)}
                      className={`px-2 py-0.5 rounded-md font-mono text-[11px] transition-all ${
                        warp === w
                          ? 'bg-water-600 text-white font-semibold shadow-sm'
                          : 'text-slate-600 hover:text-slate-900'
                      }`}
                    >
                      x{w}
                    </button>
                  ))}
                </div>
              </div>
            </div>

            {/* Manual Weight Slider */}
            <div>
              <div className="flex items-center justify-between text-xs text-slate-600 mb-2 font-medium">
                <span>Injeksi Beban Manual (Slider)</span>
                <span className="font-mono text-water-700 font-bold text-sm">
                  {Number(weight).toFixed(1)} g
                </span>
              </div>
              <input
                type="range"
                min="0"
                max="500"
                step="1"
                value={Math.round(weight)}
                onChange={(e) => onWeightChange(Number(e.target.value))}
                className="w-full h-2 bg-slate-200 rounded-lg appearance-none cursor-pointer accent-water-600"
              />
              <div className="flex justify-between text-[11px] text-slate-400 mt-1 font-mono">
                <span>0 g (diangkat)</span>
                <span>380 g (penuh)</span>
                <span>500 g</span>
              </div>
            </div>

            {/* 8 Scenario Buttons */}
            <div>
              <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider block mb-3">
                8 Skenario Uji Otomatis Demo Dosen
              </span>
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
                {demoScenarios.map((sc, idx) => (
                  <button
                    key={idx}
                    type="button"
                    onClick={() => onRunScenario(idx)}
                    className="p-3 rounded-xl border border-slate-200 hover:border-water-400 bg-white hover:bg-water-50/50 text-left transition-all shadow-sm hover:shadow group"
                  >
                    <div className="text-xs font-bold text-slate-800 group-hover:text-water-700">
                      {sc.title}
                    </div>
                    <div className="text-[11px] text-slate-500 mt-1 line-clamp-2">
                      {sc.desc}
                    </div>
                  </button>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* Panel 2: Log Sensor Real-time */}
        {activeTab === 'log' && (
          <div className="space-y-4">
            <div className="flex items-center justify-between pb-3 border-b border-slate-100">
              <div>
                <h3 className="text-sm font-bold text-slate-900">
                  Log Aktivitas & Telemetri Real-time
                </h3>
                <p className="text-xs text-slate-500 mt-0.5">
                  Total tercatat: <span className="font-mono font-semibold">{logs.length}</span> rekaman
                </p>
              </div>
              <button
                type="button"
                onClick={onExportCsv}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 text-xs font-medium transition-colors shadow-sm"
              >
                <Download className="w-3.5 h-3.5 text-slate-500" />
                <span>Unduh CSV</span>
              </button>
            </div>

            <div className="bg-slate-900 rounded-xl p-3 font-mono text-xs text-slate-300 h-72 overflow-y-auto space-y-1.5">
              {logs.length === 0 ? (
                <div className="text-slate-500 text-center py-10">Belum ada rekaman log sensor...</div>
              ) : (
                logs.map((lg, i) => (
                  <div key={i} className="flex items-start gap-2 leading-relaxed">
                    <span className="text-slate-500 flex-shrink-0 select-none">[{lg.time}]</span>
                    <span
                      className={`break-all ${
                        lg.type === 'alert'
                          ? 'text-amber-400 font-semibold'
                          : lg.type === 'drink'
                          ? 'text-emerald-400 font-semibold'
                          : lg.type === 'error'
                          ? 'text-rose-400'
                          : 'text-slate-200'
                      }`}
                    >
                      {lg.msg}
                    </span>
                  </div>
                ))
              )}
              <div ref={logEndRef} />
            </div>
          </div>
        )}

        {/* Panel 3: Riwayat 7 Hari & Telemetri */}
        {activeTab === 'history' && (
          <div className="space-y-6">
            {/* 7-Day Bar Chart */}
            <div>
              <div className="flex items-center justify-between mb-2">
                <h3 className="text-sm font-bold text-slate-900">
                  Grafik Batang Asupan 7 Hari Terakhir
                </h3>
                <span className="text-xs font-mono text-slate-500">
                  Target harian: {dailyGoal} ml
                </span>
              </div>

              <div className="bg-slate-50 rounded-xl p-3 border border-slate-200/80">
                <svg
                  viewBox={`0 0 540 ${chartH}`}
                  width="100%"
                  height={chartH}
                  preserveAspectRatio="none"
                  className="overflow-visible"
                >
                  {/* Target reference dashed line */}
                  <line
                    x1="30"
                    y1={targetY}
                    x2="520"
                    y2={targetY}
                    stroke="#94A3B8"
                    strokeDasharray="4 4"
                    strokeWidth="1"
                    opacity="0.6"
                  />
                  <text
                    x="525"
                    y={targetY + 3}
                    fill="#64748B"
                    fontSize="9"
                    fontFamily="JetBrains Mono"
                    textAnchor="end"
                  >
                    Target {dailyGoal} ml
                  </text>

                  {/* 7 Daily Bars */}
                  {chartDays.map((d, idx) => {
                    const colW = (500 - 30) / 7;
                    const cx = 35 + idx * colW + colW / 2;
                    const barW = Math.min(28, colW - 10);
                    const barH = Math.max(4, Math.round((d.ml / maxCap) * (chartH - 48)));
                    const barY = chartH - 24 - barH;
                    const isMet = d.ml >= dailyGoal;
                    const fill = isMet ? '#10B981' : d.isToday ? '#0284C7' : '#94A3B8';

                    return (
                      <g key={d.key}>
                        <rect
                          x={cx - barW / 2}
                          y={barY}
                          width={barW}
                          height={barH}
                          rx="4"
                          ry="4"
                          fill={fill}
                          opacity={d.isToday ? 1 : 0.85}
                        />
                        <text
                          x={cx}
                          y={barY - 4}
                          fill="#0F172A"
                          fontSize="9.5"
                          fontFamily="JetBrains Mono"
                          fontWeight="600"
                          textAnchor="middle"
                        >
                          {Math.round(d.ml)}
                        </text>
                        <text
                          x={cx}
                          y={chartH - 8}
                          fill={d.isToday ? '#0284C7' : '#64748B'}
                          fontSize="9.5"
                          fontFamily="Plus Jakarta Sans"
                          fontWeight={d.isToday ? '700' : '500'}
                          textAnchor="middle"
                        >
                          {d.label}
                        </text>
                      </g>
                    );
                  })}
                </svg>
              </div>
            </div>

            {/* Climate Sliders & Telemetry Line Chart */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pt-2 border-t border-slate-100">
              {/* Climate Simulation Controls */}
              <div className="bg-slate-50 p-4 rounded-xl border border-slate-200/80 space-y-4">
                <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider block">
                  Simulasi Suhu & Kelembaban (DHT11)
                </span>

                <div>
                  <div className="flex justify-between text-xs text-slate-700 font-medium mb-1.5">
                    <span>Suhu Ruangan</span>
                    <span className="font-mono text-slate-900 font-bold">{Number(temp).toFixed(1)} °C</span>
                  </div>
                  <input
                    type="range"
                    min="18"
                    max="40"
                    step="0.5"
                    value={temp}
                    onChange={(e) => onTempChange(Number(e.target.value))}
                    className="w-full h-1.5 bg-slate-200 rounded-lg appearance-none cursor-pointer accent-water-600"
                  />
                </div>

                <div>
                  <div className="flex justify-between text-xs text-slate-700 font-medium mb-1.5">
                    <span>Kelembaban Udara</span>
                    <span className="font-mono text-slate-900 font-bold">{Math.round(humidity)} % RH</span>
                  </div>
                  <input
                    type="range"
                    min="20"
                    max="95"
                    step="1"
                    value={humidity}
                    onChange={(e) => onHumidityChange(Number(e.target.value))}
                    className="w-full h-1.5 bg-slate-200 rounded-lg appearance-none cursor-pointer accent-water-600"
                  />
                </div>
              </div>

              {/* Real-time Streaming Telemetry Chart */}
              <div className="bg-slate-50 p-4 rounded-xl border border-slate-200/80 flex flex-col justify-between">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Aliran Beban Real-time (30 Titik)
                  </span>
                  <span className="text-xs font-mono text-water-700 font-bold">
                    {Number(weight).toFixed(1)} g
                  </span>
                </div>

                <div className="w-full h-24 bg-white rounded-lg border border-slate-200 overflow-hidden relative">
                  <svg viewBox={`0 0 ${teleW} ${teleH}`} width="100%" height="100%" preserveAspectRatio="none">
                    <line x1="0" y1={teleH / 2} x2={teleW} y2={teleH / 2} stroke="#F1F5F9" strokeWidth="1" />
                    {telePoints.length > 1 && (
                      <path
                        d={weightPath}
                        fill="none"
                        stroke="#0284C7"
                        strokeWidth="2.5"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      />
                    )}
                  </svg>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
