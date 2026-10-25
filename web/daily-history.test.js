'use strict';
// Regresi riwayat harian web/index.html. Dua bug pernah lolos di jalur ini:
// (1) tombol Reset menyimpan nol sebelum reset, (2) startSession() membalik
// urutan simpan/reset. Logikanya inline di index.html, jadi diuji dengan
// mengekstrak dua fungsi murni + localStorage tiruan, bukan DOM penuh.
const assert = require('assert');
const fs = require('fs');
const path = require('path');

const html = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8');

function extract(name) {
  const m = new RegExp(`function ${name}\\(`).exec(html);
  assert(m, `fungsi ${name} tidak ditemukan di index.html`);
  let i = html.indexOf('{', m.index), depth = 0, end = i;
  for (; end < html.length; end++) {
    if (html[end] === '{') depth++;
    else if (html[end] === '}' && --depth === 0) break;
  }
  return html.slice(m.index, end + 1);
}

// localStorage tiruan: hanya API yang dipakai kedua fungsi.
const store = {};
global.localStorage = {
  getItem: k => (k in store ? store[k] : null),
  setItem: (k, v) => { store[k] = String(v); },
};

const fsm = { totalDrank: 0, drinkCount: 0, refillCount: 0, cheatCount: 0 };
const renderHistoryList = () => {};
const todayKey = () => '2026-10-25';
// eslint-disable-next-line no-new-func
new Function('fsm', 'renderHistoryList', 'todayKey', 'localStorage',
  extract('loadDailyHistory') + '\n' + extract('saveTodayStatsToHistory') +
  '\nglobal.loadDailyHistory = loadDailyHistory; global.saveTodayStatsToHistory = saveTodayStatsToHistory;'
)(fsm, renderHistoryList, todayKey, global.localStorage);

const { loadDailyHistory, saveTodayStatsToHistory } = global;

// 1. Simpan-dulu-baru-reset mempertahankan catatan hari ini (precedent bReset).
fsm.totalDrank = 420; fsm.drinkCount = 3;
saveTodayStatsToHistory();
assert.strictEqual(loadDailyHistory()['2026-10-25'].total_ml, 420,
  'angka pra-reset harus tersimpan');

fsm.totalDrank = 0; fsm.drinkCount = 0;
assert.strictEqual(loadDailyHistory()['2026-10-25'].total_ml, 420,
  'reset setelah simpan tidak boleh menimpa riwayat yang sudah ada');

// 2. Urutan terbalik (reset dulu, simpan kemudian) memang merusak riwayat:
//    inilah pola yang dijaga oleh urutan di bReset dan startSession().
fsm.totalDrank = 0; fsm.drinkCount = 0;
saveTodayStatsToHistory();
assert.strictEqual(loadDailyHistory()['2026-10-25'].total_ml, 0,
  'menyimpan setelah reset menulis nol ke riwayat hari ini — pola yang harus dihindari');

// 3. Riwayat dipangkas ke 30 hari terbaru, bukan tumbuh selamanya.
const many = {};
for (let d = 1; d <= 40; d++) {
  many[`2026-09-${String(d).padStart(2, '0')}`] = { total_ml: d, drink_count: 1, refill_count: 0, cheat_count: 0 };
}
global.localStorage.setItem('shc_daily_history', JSON.stringify(many));
fsm.totalDrank = 0;
saveTodayStatsToHistory();
const trimmed = Object.keys(loadDailyHistory());
assert.strictEqual(trimmed.length, 30, `harus 30 entri, dapat ${trimmed.length}`);
assert(trimmed.includes('2026-10-25'), 'hari terbaru wajib ada');
assert(!trimmed.includes('2026-09-01'), 'entri terlama harus dibuang');

console.log('SEMUA LULUS (daily-history.test.js)');
