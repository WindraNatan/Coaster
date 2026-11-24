import React, { useEffect, useRef } from 'react';
import { X, Zap, ThermometerSun, Clock } from 'lucide-react';

const MODES = [
  {
    id: 'AUTO_DHT',
    title: 'Otomatis sesuai suhu',
    desc: 'Jeda pengingat menyesuaikan suhu dan kelembapan ruangan.',
    icon: ThermometerSun
  },
  {
    id: 'MANUAL',
    title: 'Jadwal tetap',
    desc: 'Memakai jeda menit pilihanmu tanpa dipengaruhi suhu ruangan.',
    icon: Clock
  },
  {
    id: 'DEMO',
    title: 'Mode demo (15 detik)',
    desc: 'Siklus cepat 15 detik untuk keperluan demonstrasi atau presentasi.',
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
      className="rounded-2xl border border-hairline bg-surface text-ink p-0 overflow-y-auto"
    >
      <div className="flex items-center justify-between px-5 py-4 border-b border-hairline">
        <div>
          <h2 id="session-dialog-title" className="text-base font-semibold text-ink tracking-tight">
            Mulai sesi baru
          </h2>
          <p className="text-xs text-ink-soft mt-0.5">
            Pilih cara tatakan mengatur jadwal pengingat minum
          </p>
        </div>
        <button
          type="button"
          onClick={() => dialogRef.current?.close()}
          aria-label="Tutup pilihan sesi"
          className="p-1.5 rounded-lg text-ink-soft hover:text-ink hover:bg-subtle transition-colors duration-150"
        >
          <X className="w-4 h-4" strokeWidth={1.75} aria-hidden="true" />
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
              className={`w-full p-3.5 rounded-xl border text-left transition-colors duration-150 flex items-start gap-3 ${
                isCurrent
                  ? 'bg-accent-soft border-accent text-ink'
                  : 'bg-surface hover:bg-subtle border-hairline text-ink'
              }`}
            >
              <div className="w-8 h-8 rounded-lg bg-surface flex items-center justify-center text-accent flex-shrink-0 mt-0.5">
                <Icon className="w-4 h-4" strokeWidth={1.75} aria-hidden="true" />
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center justify-between gap-2">
                  <span className="text-xs font-semibold text-ink">{m.title}</span>
                  {isCurrent && (
                    <span className="text-xs font-semibold text-accent whitespace-nowrap">
                      Aktif
                    </span>
                  )}
                </div>
                <p className="text-xs text-ink-soft mt-0.5 leading-relaxed">{m.desc}</p>
              </div>
            </button>
          );
        })}
      </div>
    </dialog>
  );
}
