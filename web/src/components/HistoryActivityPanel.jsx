import React, { useState } from 'react';
import { Calendar, ListChecks, Download, Trash2 } from 'lucide-react';

export default function HistoryActivityPanel({
  dailyHistory = {},
  todayDateKey = '',
  todayMl = 0,
  todayDrinks = 0,
  dailyGoal = 2000,
  logs = [],
  onClearLogs,
  onExportCsv
}) {
  const [activeTab, setActiveTab] = useState('history'); // 'history' | 'logs'

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
      const shortDay = d.toLocaleDateString('id-ID', { weekday: 'short' });
      const rec = dailyHistory[key] || {};
      const isToday = key === todayDateKey;
      const ml = isToday
        ? Math.max(Number(rec.total_ml || 0), Math.round(todayMl))
        : Math.round(Number(rec.total_ml || 0));
      const drinks = isToday
        ? Math.max(Number(rec.drink_count || 0), todayDrinks)
        : Number(rec.drink_count || 0);
      days.push({ key, label, shortDay, ml, drinks, isToday });
    }
    return days;
  };

  const days7 = getLast7Days();
  const maxBarMl = Math.max(dailyGoal, ...days7.map((d) => d.ml), 500);
  const weekHasIntake = days7.some((d) => d.ml > 0);

  return (
    <section
      className="bg-surface rounded-2xl p-5 border border-hairline flex flex-col justify-between"
      aria-label="Riwayat minum 7 hari dan catatan aktivitas"
    >
      <div>
        <div className="flex flex-wrap items-center justify-between gap-3 pb-4 border-b border-hairline">
          <div>
            <h2 className="text-base font-semibold text-ink tracking-tight">
              Riwayat minum
            </h2>
            <p className="text-xs text-ink-soft mt-0.5">
              Capaian 7 hari terakhir dan catatan aktivitas minum
            </p>
          </div>

          <div
            className="inline-flex p-1 bg-subtle rounded-xl border border-hairline text-xs font-medium"
            role="tablist"
            aria-label="Pilihan tampilan riwayat"
          >
            <button
              type="button"
              role="tab"
              id="tab-history"
              aria-selected={activeTab === 'history'}
              aria-controls="panel-history"
              onClick={() => setActiveTab('history')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg whitespace-nowrap transition-colors duration-150 ${
                activeTab === 'history'
                  ? 'bg-surface text-ink font-semibold border border-hairline'
                  : 'text-ink-soft hover:text-ink'
              }`}
            >
              <Calendar className="w-3.5 h-3.5" strokeWidth={1.75} aria-hidden="true" />
              <span>7 hari terakhir</span>
            </button>
            <button
              type="button"
              role="tab"
              id="tab-logs"
              aria-selected={activeTab === 'logs'}
              aria-controls="panel-logs"
              onClick={() => setActiveTab('logs')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg whitespace-nowrap transition-colors duration-150 ${
                activeTab === 'logs'
                  ? 'bg-surface text-ink font-semibold border border-hairline'
                  : 'text-ink-soft hover:text-ink'
              }`}
            >
              <ListChecks className="w-3.5 h-3.5" strokeWidth={1.75} aria-hidden="true" />
              <span>Catatan aktivitas ({logs.length})</span>
            </button>
          </div>
        </div>

        {/* Tab 1: Riwayat 7 hari terakhir */}
        {activeTab === 'history' && (
          <div
            id="panel-history"
            role="tabpanel"
            aria-labelledby="tab-history"
            className="pt-4 space-y-3"
          >
            <div className="flex flex-wrap items-center justify-between gap-2 text-xs text-ink-soft">
              <span>Perbandingan jumlah air minum setiap hari</span>
              <span className="font-semibold text-ink">
                Target harian: <span className="font-mono tabular-nums">{dailyGoal}</span> ml
              </span>
            </div>

            <div className="grid grid-cols-7 gap-2 pt-2 items-end h-44 bg-subtle rounded-xl p-3">
              {days7.map((d) => {
                const scaleY = d.ml > 0 ? Math.min(1, Math.max(0.06, d.ml / maxBarMl)) : 0.04;
                const reachedGoal = d.ml >= dailyGoal;
                return (
                  <div key={d.key} className="flex flex-col items-center h-full justify-end">
                    <span className="text-xs font-mono font-medium text-ink tabular-nums mb-1">
                      {d.ml > 0 ? d.ml : '0'}
                    </span>
                    <div className="w-full max-w-[36px] bg-surface rounded-t-lg h-24 flex items-end overflow-hidden border border-hairline">
                      <div
                        className={`w-full h-full origin-bottom rounded-t-lg transition-transform duration-300 ease-calm ${
                          reachedGoal || d.isToday ? 'bg-accent' : 'bg-control'
                        }`}
                        style={{ transform: `scaleY(${scaleY})` }}
                      />
                    </div>
                    <span
                      className={`mt-1.5 text-xs truncate max-w-full ${
                        d.isToday ? 'text-accent font-semibold' : 'text-ink-soft font-medium'
                      }`}
                    >
                      <span className="hidden sm:inline">{d.isToday ? 'Hari ini' : d.label}</span>
                      <span className="sm:hidden">{d.isToday ? 'Kini' : d.shortDay}</span>
                    </span>
                    <span className="text-xs text-ink-muted">
                      {d.drinks} kali
                    </span>
                  </div>
                );
              })}
            </div>

            {!weekHasIntake && (
              <p className="text-xs text-ink-muted">
                Belum ada catatan minum yang tersimpan selama 7 hari terakhir. Setiap tegukan akan tercatat otomatis.
              </p>
            )}
          </div>
        )}

        {/* Tab 2: Catatan aktivitas */}
        {activeTab === 'logs' && (
          <div
            id="panel-logs"
            role="tabpanel"
            aria-labelledby="tab-logs"
            className="pt-4 space-y-3"
          >
            <div className="flex flex-wrap items-center justify-between gap-2">
              <span className="text-xs text-ink-soft">
                Urutan kejadian minum, isi ulang, dan pengingat selama sesi berjalan
              </span>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={onExportCsv}
                  className="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg border border-control bg-surface hover:bg-subtle text-ink text-xs font-semibold whitespace-nowrap transition-colors duration-150"
                >
                  <Download className="w-3.5 h-3.5" strokeWidth={1.75} aria-hidden="true" />
                  <span>Unduh CSV</span>
                </button>
                <button
                  type="button"
                  onClick={onClearLogs}
                  className="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg border border-hairline bg-surface hover:bg-subtle text-ink-soft text-xs font-medium whitespace-nowrap transition-colors duration-150"
                >
                  <Trash2 className="w-3.5 h-3.5" strokeWidth={1.75} aria-hidden="true" />
                  <span>Hapus daftar</span>
                </button>
              </div>
            </div>

            <div className="bg-subtle rounded-xl p-3 h-48 overflow-y-auto text-xs space-y-1.5">
              {logs.length === 0 ? (
                <div className="text-ink-muted py-10 text-center">
                  Belum ada aktivitas minum atau perubahan pengaturan pada sesi ini.
                </div>
              ) : (
                logs.map((item, idx) => (
                  <div
                    key={idx}
                    className="flex items-start gap-2.5 py-1.5 border-b border-hairline last:border-b-0 text-ink"
                  >
                    <span className="font-mono tabular-nums text-ink-muted flex-shrink-0">
                      {item.time}
                    </span>
                    <span className="px-2 py-0.5 rounded-md bg-surface text-ink-soft font-semibold flex-shrink-0">
                      {item.tag}
                    </span>
                    <span className="leading-relaxed">{item.msg}</span>
                  </div>
                ))
              )}
            </div>
          </div>
        )}
      </div>
    </section>
  );
}
