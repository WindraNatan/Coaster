import React from 'react';
import { Scale, Thermometer, Droplets, Activity } from 'lucide-react';

export default function TremorKpiCards({
  weight = 0,
  stableSamples = 0,
  isStable = false,
  isLifted = false,
  temp = 27.0,
  humidity = 60,
  drinkCount = 0,
  cheatCount = 0,
  refillCount = 0,
  totalDrank = 0
}) {
  // Stability calculation: 16 samples needed for full stability in FSM
  const stabPct = isStable ? 100 : Math.min(100, Math.round((stableSamples / 16) * 100));
  let stabLabel = 'menunggu gelas';
  if (isLifted) {
    stabLabel = 'gelas diangkat';
  } else if (isStable) {
    stabLabel = 'timbangan stabil';
  } else if (weight > 25) {
    stabLabel = `menstabilkan (${Math.round(stabPct)}%)`;
  }

  const getHumidityTag = (h) => {
    if (h < 40) return { text: 'Kering', color: 'bg-amber-50 text-amber-700 border-amber-200' };
    if (h > 70) return { text: 'Lembap', color: 'bg-sky-50 text-sky-700 border-sky-200' };
    return { text: 'Nyaman', color: 'bg-emerald-50 text-emerald-700 border-emerald-200' };
  };

  const humTag = getHumidityTag(humidity);

  return (
    <section className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4" aria-label="Metrik KPI penting">
      {/* KPI 1: Beban Aktual */}
      <div className="bg-white rounded-2xl p-5 border border-slate-200/80 shadow-soft hover:shadow-soft-lg transition-all flex flex-col justify-between">
        <div>
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
              Beban Aktual Tatakan
            </span>
            <Scale className="w-4 h-4 text-slate-400" />
          </div>
          <div className="mt-3 flex items-baseline gap-1.5">
            <span className="text-3xl font-bold text-slate-900 font-mono tabular-nums tracking-tight">
              {Number(weight).toFixed(1)}
            </span>
            <span className="text-sm font-medium text-slate-500">g</span>
          </div>
        </div>

        <div className="mt-4 pt-3 border-t border-slate-100">
          <div className="flex items-center justify-between text-xs text-slate-500 mb-1.5">
            <span>Kestabilan</span>
            <span className="font-medium text-slate-700">{stabLabel}</span>
          </div>
          <div className="w-full bg-slate-100 rounded-full h-1.5 overflow-hidden">
            <div
              className={`h-full transition-all duration-300 rounded-full ${
                isStable ? 'bg-emerald-500' : 'bg-water-500'
              }`}
              style={{ width: `${stabPct}%` }}
            />
          </div>
        </div>
      </div>

      {/* KPI 2: Suhu Ruangan */}
      <div className="bg-white rounded-2xl p-5 border border-slate-200/80 shadow-soft hover:shadow-soft-lg transition-all flex flex-col justify-between">
        <div>
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
              Suhu Ruangan
            </span>
            <Thermometer className="w-4 h-4 text-slate-400" />
          </div>
          <div className="mt-3 flex items-baseline gap-1.5">
            <span className="text-3xl font-bold text-slate-900 font-mono tabular-nums tracking-tight">
              {Number(temp).toFixed(1)}
            </span>
            <span className="text-sm font-medium text-slate-500">°C</span>
          </div>
        </div>

        <div className="mt-4 pt-3 border-t border-slate-100 flex items-center justify-between text-xs">
          <span className="text-slate-500">Sensor iklim DHT11</span>
          <span className="px-2 py-0.5 rounded-full text-[11px] font-semibold bg-sky-50 text-sky-700 border border-sky-100">
            Adaptif
          </span>
        </div>
      </div>

      {/* KPI 3: Kelembapan Ruang */}
      <div className="bg-white rounded-2xl p-5 border border-slate-200/80 shadow-soft hover:shadow-soft-lg transition-all flex flex-col justify-between">
        <div>
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
              Kelembapan Ruang
            </span>
            <Droplets className="w-4 h-4 text-slate-400" />
          </div>
          <div className="mt-3 flex items-baseline gap-1.5">
            <span className="text-3xl font-bold text-slate-900 font-mono tabular-nums tracking-tight">
              {Math.round(humidity)}
            </span>
            <span className="text-sm font-medium text-slate-500">% RH</span>
          </div>
        </div>

        <div className="mt-4 pt-3 border-t border-slate-100 flex items-center justify-between text-xs">
          <span className="text-slate-500">Kondisi kelembapan</span>
          <span className={`px-2 py-0.5 rounded-full text-[11px] font-semibold border ${humTag.color}`}>
            {humTag.text}
          </span>
        </div>
      </div>

      {/* KPI 4: Tegukan Sesi */}
      <div className="bg-white rounded-2xl p-5 border border-slate-200/80 shadow-soft hover:shadow-soft-lg transition-all flex flex-col justify-between">
        <div>
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
              Tegukan Sesi Ini
            </span>
            <Activity className="w-4 h-4 text-slate-400" />
          </div>
          <div className="mt-3 flex items-baseline gap-1.5">
            <span className="text-3xl font-bold text-slate-900 font-mono tabular-nums tracking-tight">
              {drinkCount}
            </span>
            <span className="text-sm font-medium text-slate-500">kali</span>
          </div>
        </div>

        <div className="mt-4 pt-3 border-t border-slate-100 text-xs text-slate-500 truncate">
          <span className="font-mono text-slate-700 font-medium">{cheatCount}</span> kecil ·{' '}
          <span className="font-mono text-slate-700 font-medium">{refillCount}</span> refill ·{' '}
          <span className="font-mono text-slate-700 font-medium">{Math.round(totalDrank)}</span> ml
        </div>
      </div>
    </section>
  );
}
