/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        canvas: 'var(--bg-canvas)',
        surface: 'var(--bg-surface)',
        subtle: 'var(--bg-subtle)',
        hairline: 'var(--border-hairline)',
        control: 'var(--border-control)',
        ink: 'var(--ink-primary)',
        'ink-soft': 'var(--ink-secondary)',
        'ink-muted': 'var(--ink-muted)',
        accent: 'var(--accent)',
        'accent-hover': 'var(--accent-hover)',
        'accent-soft': 'var(--accent-soft)',
        'accent-ink': 'var(--accent-ink)',
        ok: 'var(--ok)',
        'ok-bg': 'var(--ok-bg)',
        'ok-border': 'var(--ok-border)',
        warn: 'var(--warn)',
        'warn-bg': 'var(--warn-bg)',
        'warn-border': 'var(--warn-border)',
        danger: 'var(--danger)',
        'danger-bg': 'var(--danger-bg)',
        'danger-border': 'var(--danger-border)',
      },
      fontFamily: {
        sans: ['Instrument Sans', 'system-ui', 'sans-serif'],
        mono: ['IBM Plex Mono', 'ui-monospace', 'monospace'],
      },
      boxShadow: {
        coaster: 'var(--shadow-coaster)',
      },
      transitionTimingFunction: {
        calm: 'var(--ease-calm)',
      },
    },
  },
  plugins: [],
};
