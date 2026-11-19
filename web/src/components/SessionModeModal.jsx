import React, { useEffect, useRef } from 'react';
import { X, Zap, ThermometerSun, Clock } from 'lucide-react';

const MODES = [
  {
    id: 'AUTO_DHT',
    title: 'Otomatis Adaptif (DHT11)',
    desc: 'Interval dasar disesuaikan suhu & kelembapan ruang secara kontinu.',
    icon: ThermometerSun
  },
  {
    id: 'MANUAL',
    title: 'Interval Manual Tetap',
    desc: 'Memakai interval dasar pilihan Anda tanpa kompensasi suhu.',
    icon: Clock
  },
  {
    id: 'DEMO',
    title: 'Presentasi / Demo (15 detik)',
    desc: 'Siklus cepat 15 detik tanpa kompensasi suhu untuk demonstrasi.',
    icon: Zap
  }
];

export default function SessionModeModal({
  isOpen,
  onClose,
  onConfirmStart,
  currentMode = 'AUTO_DHT',
  busy = false
}) {
  const dialogRef = useRef(null);

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;
    if (isOpen) {
      if (!dialog.open) dialog.showModal();
    } else if (dialog.open) {
      dialog.close();
    }
  }, [isOpen]);

  const handleBackdropPointerDown = (e) => {
    const dialog = dialogRef.current;
    if (!dialog || e.target !== dialog) return;
    const rect = dialog.getBoundingClientRect();
    const clickedOutside =
      e.clientX < rect.left ||
      e.clientX > rect.right ||
      e.clientY < rect.top ||
      e.clientY > rect.bottom;
    if (clickedOutside) {
      dialog.close('light-dismiss');
    }
  };

  return (
    <dialog
      ref={dialogRef}
      closedby="any"
      onClose={() => { if (isOpen && onClose) onClose(); }}
      onPointerDown={handleBackdropPointerDown}
      aria-labelledby="session-dialog-title"
      className="rounded-2xl border border-slate-200 bg-white text-slate-900 shadow-soft p-0 overflow-y-auto"
    >
      <div className="flex items-center justify-between px-5 py-4 border-b border-slate-200">
        <div>
          <h2 id="session-dialog-title" className="font-display text-base font-bold text-slate-900 tracking-tight">
            Mulai Sesi Hidrasi
          </h2>
          <p className="text-xs text-slate-600 mt-0.5">
            Pilih mode pengingat untuk membangunkan tatakan dan memulai sesi Anda
          </p>
        </div>
        <button
          type="button"
          onClick={() => dialogRef.current?.close()}
          aria-label="Tutup pilihan sesi"
          className="p-1.5 rounded-lg text-slate-600 hover:text-slate-900 hover:bg-slate-100 transition-colors"
        >
          <X className="w-4 h-4" aria-hidden="true" />
        </button>
      </div>

      <div className="p-5 space-y-2.5">
        {MODES.map((m) => {
          const Icon = m.icon;
          const isCurrent = currentMode === m.id;
          return (
            <button
              key={m.id}
              type="button"
              disabled={busy}
              onClick={() => onConfirmStart(m.id)}
              className={`w-full p-3.5 rounded-xl border text-left transition-colors flex items-start gap-3 ${
                isCurrent
                  ? 'bg-sky-50 border-sky-300 text-slate-900'
                  : 'bg-white hover:bg-slate-50 border-slate-200 text-slate-800'
              }`}
            >
              <div className="w-8 h-8 rounded-lg bg-white border border-slate-200 flex items-center justify-center text-water-700 flex-shrink-0 mt-0.5">
                <Icon className="w-4 h-4" aria-hidden="true" />
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center justify-between gap-2">
                  <span className="text-xs font-bold text-slate-900">{m.title}</span>
                  {isCurrent && (
                    <span className="text-[11px] font-mono font-semibold text-water-800">
                      Aktif
                    </span>
                  )}
                </div>
                <p className="text-xs text-slate-600 mt-0.5 leading-relaxed">{m.desc}</p>
              </div>
            </button>
          );
        })}
      </div>
    </dialog>
  );
}
