import React from 'react';

const STATUS_META = {
  IDLE: {
    label: 'Siap dipakai',
    desc: 'Letakkan gelas berisi air di atas tatakan untuk mulai memantau.',
    badge: 'bg-subtle text-ink-soft border-hairline',
    ringColor: 'var(--border-control)'
  },
  STABLE: {
    label: 'Gelas terdeteksi',
    desc: 'Gelas sudah tenang di tatakan dan siap memulai jadwal minum.',
    badge: 'bg-ok-bg text-ok border-ok-border',
    ringColor: 'var(--ok)'
  },
  TIMING: {
    label: 'Pemantauan aktif',
    desc: 'Jadwal pengingat minum sedang berjalan teratur.',
    badge: 'bg-accent-soft text-accent border-hairline',
    ringColor: 'var(--accent)'
  },
  ALERT_DRINK: {
    label: 'Waktunya minum',
    desc: 'Ambil gelas dan minum minimal satu tegukan air.',
    badge: 'bg-warn-bg text-warn border-warn-border',
    ringColor: 'var(--warn)'
  },
  ALERT_CHEAT: {
    label: 'Belum cukup minum',
    desc: 'Air berkurang sedikit. Silakan minum satu tegukan penuh lagi.',
    badge: 'bg-danger-bg text-danger border-danger-border',
    ringColor: 'var(--danger)'
  },
  ALERT_EMPTY_CUP: {
    label: 'Air hampir habis',
    desc: 'Isi ulang air ke dalam gelas sebelum meletakkannya kembali.',
    badge: 'bg-danger-bg text-danger border-danger-border',
    ringColor: 'var(--danger)'
  },
  ALERT_MISSING_CUP: {
    label: 'Gelas belum kembali',
    desc: 'Letakkan kembali gelasmu di atas tatakan agar jadwal berlanjut.',
    badge: 'bg-warn-bg text-warn border-warn-border',
    ringColor: 'var(--warn)'
  },
  ALERT_REFILL: {
    label: 'Air hampir habis',
    desc: 'Isi ulang air atau letakkan kembali gelasmu di atas tatakan.',
    badge: 'bg-danger-bg text-danger border-danger-border',
    ringColor: 'var(--danger)'
  },
  LIFTED: {
    label: 'Gelas diangkat',
    desc: 'Silakan nikmati air minummu lalu letakkan gelas kembali.',
    badge: 'bg-accent-soft text-accent border-hairline',
    ringColor: 'var(--accent)'
  }
};

export default function VisualTumblerCoaster({
  stateString = 'IDLE',
  weight = 0,
  isStable = false,
  standby = false,
  deviceOffline = false,
  cupMl = 0,
  cupMax = 500,
  emptyCup = 130,
  connMode = 'sim',
  onLift,
  onPlace,
  onSip,
  onPour,
  onEmpty
}) {
  const meta = deviceOffline
    ? {
        label: 'Alat terputus',
        desc: 'Data terakhir membeku karena ESP32 berhenti mengirim pembaruan. Pemantauan lanjut saat alat kembali terhubung.',
        badge: 'bg-danger-bg text-danger border-danger-border',
        ringColor: 'var(--danger)'
      }
    : standby
      ? {
          label: 'Mode istirahat',
          desc: 'Pengingat sedang diistirahatkan. Tekan Mulai sesi saat ingin memakai lagi.',
          badge: 'bg-subtle text-ink-soft border-hairline',
          ringColor: 'var(--border-control)'
        }
      : (STATUS_META[stateString] || STATUS_META.IDLE);

  const isLifted = stateString === 'LIFTED' || stateString === 'ALERT_MISSING_CUP';
  const isNoCup = !isLifted && weight < 25;
  const isCupOffCoaster = isLifted || isNoCup;
  const waterPct = isCupOffCoaster ? 0 : Math.min(1, Math.max(0, cupMl / cupMax));

  const stabilityLabel = deviceOffline
    ? 'Koneksi terputus'
    : standby
      ? 'Istirahat'
      : weight < 25
        ? 'Belum ada gelas'
        : isStable
          ? 'Gelas tenang'
          : 'Menyesuaikan posisi';

  return (
    <section
      className="bg-surface rounded-2xl p-4 sm:p-5 border border-hairline flex flex-col justify-between h-full"
      aria-label="Kondisi gelas di tatakan"
    >
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div>
          <h2 className="text-base font-semibold text-ink tracking-tight">
            Gelas di tatakan
          </h2>
          <p className="text-xs text-ink-soft mt-0.5">
            Kapasitas penuh {cupMax} ml
          </p>
        </div>
        <div
          className={`px-3 py-1 rounded-full text-xs font-semibold border whitespace-nowrap ${meta.badge}`}
          role="status"
          aria-live="polite"
        >
          {meta.label}
        </div>
      </div>

      <div className="py-2 sm:py-4 flex flex-col items-center justify-center">
        <div className="relative flex flex-col items-center justify-center">
          <svg
            width="148"
            height="172"
            viewBox="0 0 120 170"
            className="relative z-10 overflow-visible w-[112px] h-[132px] sm:w-[148px] sm:h-[172px]"
            aria-hidden="true"
          >
            <defs>
              <clipPath id="coasterCupClip">
                <path d="M30 20 L90 20 L82 138 Q81 146 72 146 L48 146 Q39 146 38 138 Z" />
              </clipPath>
              <linearGradient id="coasterWaterGrad" x1="0%" y1="0%" x2="0%" y2="100%">
                <stop offset="0%" stopColor="var(--water-top)" />
                <stop offset="100%" stopColor="var(--water-bottom)" />
              </linearGradient>
              <linearGradient id="coasterCeramicGrad" x1="0%" y1="0%" x2="100%" y2="0%">
                <stop offset="0%" stopColor="var(--bg-surface)" />
                <stop offset="60%" stopColor="var(--bg-canvas)" />
                <stop offset="100%" stopColor="var(--bg-subtle)" />
              </linearGradient>
            </defs>

            <g>
              <ellipse
                cx="60"
                cy="155"
                rx="48"
                ry="11"
                fill="var(--bg-subtle)"
                stroke="var(--border-hairline)"
                strokeWidth="1.5"
              />
              <ellipse
                cx="60"
                cy="152"
                rx="44"
                ry="9"
                fill="var(--bg-surface)"
                stroke="var(--border-hairline)"
                strokeWidth="1"
              />
              <ellipse
                cx="60"
                cy="152"
                rx="40"
                ry="7.5"
                fill="none"
                stroke={meta.ringColor}
                strokeWidth="2.5"
                className="transition-colors duration-300 ease-calm"
              />
            </g>

            <ellipse
              cx="60"
              cy="146"
              rx="28"
              ry="5"
              fill="none"
              stroke="var(--border-control)"
              strokeDasharray="3 3"
              strokeWidth="1.2"
            />

            <g
              className="transition-[transform,opacity] duration-300 ease-calm"
              style={{
                transform: isCupOffCoaster ? 'translateY(-22px)' : 'translateY(0px)',
                transformOrigin: '60px 140px',
                opacity: isCupOffCoaster ? 0.55 : 1
              }}
            >
              <path
                d="M30 20 L90 20 L82 138 Q81 146 72 146 L48 146 Q39 146 38 138 Z"
                fill="url(#coasterCeramicGrad)"
                stroke="var(--border-control)"
                strokeWidth="1.8"
              />

              <g clipPath="url(#coasterCupClip)">
                <rect
                  x="30"
                  y="30"
                  width="60"
                  height="116"
                  fill="url(#coasterWaterGrad)"
                  opacity="0.92"
                  className="transition-transform duration-300 ease-calm"
                  style={{
                    transformOrigin: '60px 146px',
                    transform: `scaleY(${waterPct})`
                  }}
                />
              </g>

              <ellipse
                cx="60"
                cy="20"
                rx="30"
                ry="4.5"
                fill="var(--bg-subtle)"
                stroke="var(--ink-muted)"
                strokeWidth="1.5"
              />
              <path
                d="M35 26 L39 134"
                stroke="var(--bg-surface)"
                strokeWidth="2.5"
                strokeLinecap="round"
                opacity="0.85"
              />
            </g>
          </svg>
          <div
            className="w-36 h-4 rounded-full bg-subtle shadow-coaster -mt-3 pointer-events-none"
            aria-hidden="true"
          />
        </div>

        <div className="mt-4 text-center w-full">
          {isLifted ? (
            <div className="text-xl font-semibold text-ink">
              Gelas diangkat
            </div>
          ) : isNoCup ? (
            <div className="text-xl font-semibold text-ink">
              Tatakan kosong
            </div>
          ) : (
            <div className="text-2xl font-semibold text-ink">
              <span>Air </span>
              <span className="font-mono tabular-nums">{Math.max(0, Math.round(cupMl))}</span>
              <span> ml</span>
            </div>
          )}

          <div className="mt-1 text-xs text-ink-soft">
            <span>{stabilityLabel}</span>
            <span>, berat terukur </span>
            <span className="font-mono tabular-nums text-ink">{weight.toFixed(1)}</span>
            <span> g</span>
            <span className="text-ink-muted"> (kosong {Math.round(emptyCup)} g)</span>
          </div>

          <p className="text-xs text-ink-soft mt-2 max-w-sm mx-auto leading-relaxed">
            {meta.desc}
          </p>
        </div>
      </div>

      {connMode === 'sim' ? (
        <div className="pt-3 border-t border-hairline">
          <div className="text-xs font-medium text-ink-soft mb-2 text-center">
            Simulasi sentuhan gelas
          </div>
          <div className="flex flex-wrap items-center justify-center gap-1.5" role="group" aria-label="Aksi simulasi gelas">
            <button
              type="button"
              onClick={onLift}
              className="px-2.5 py-1.5 rounded-lg border border-control bg-surface hover:bg-subtle text-ink text-xs font-medium whitespace-nowrap transition-colors duration-150"
            >
              Angkat
            </button>
            <button
              type="button"
              onClick={onPlace}
              className="px-2.5 py-1.5 rounded-lg border border-control bg-surface hover:bg-subtle text-ink text-xs font-medium whitespace-nowrap transition-colors duration-150"
            >
              Letakkan
            </button>
            <button
              type="button"
              onClick={onSip}
              className="px-2.5 py-1.5 rounded-lg border border-control bg-surface hover:bg-subtle text-ink text-xs font-medium whitespace-nowrap transition-colors duration-150"
            >
              Sedot 30 ml
            </button>
            <button
              type="button"
              onClick={onPour}
              className="px-2.5 py-1.5 rounded-lg border border-control bg-surface hover:bg-subtle text-ink text-xs font-medium whitespace-nowrap transition-colors duration-150"
            >
              Tuang 50 ml
            </button>
            <button
              type="button"
              onClick={onEmpty}
              className="px-2.5 py-1.5 rounded-lg border border-control bg-surface hover:bg-subtle text-ink text-xs font-medium whitespace-nowrap transition-colors duration-150"
            >
              Habiskan
            </button>
          </div>
        </div>
      ) : (
        <div className="pt-3 border-t border-hairline text-center">
          <p className="text-xs text-ink-soft">
            {connMode === 'usb'
              ? 'Membaca timbangan tatakan langsung lewat kabel USB.'
              : 'Membaca pembaruan langsung dari tatakan pintar secara online.'}
          </p>
        </div>
      )}
    </section>
  );
}
