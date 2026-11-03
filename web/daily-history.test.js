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
  extract('dayBaseline') + '\n' + extract('ensureDayBaseline') + '\n' +
  extract('todayDelta') + '\n' + extract('loadDailyHistory') + '\n' +
  extract('saveTodayStatsToHistory') +
  '\nglobal.loadDailyHistory = loadDailyHistory; global.saveTodayStatsToHistory = saveTodayStatsToHistory;'
)(fsm, renderHistoryList, todayKey, global.localStorage);

const { loadDailyHistory, saveTodayStatsToHistory } = global;

// 1. Simpan-dulu-baru-reset mempertahankan catatan hari ini (precedent bReset).
fsm.totalDrank = 420; fsm.drinkCount = 3;
saveTodayStatsToHistory();
// Penyimpanan pertama memasang baseline tanggal, jadi harian = 0. Angka
// kumulatif alat tidak lagi ditulis sebagai angka harian.
assert.strictEqual(loadDailyHistory()['2026-10-25'].total_ml, 0,
  'baseline dipasang pada penyimpanan pertama');

fsm.totalDrank = 620; fsm.drinkCount = 4;
saveTodayStatsToHistory();
assert.strictEqual(loadDailyHistory()['2026-10-25'].total_ml, 200,
  'selisih terhadap baseline dicatat sebagai harian');

fsm.totalDrank = 0; fsm.drinkCount = 0;
assert.strictEqual(loadDailyHistory()['2026-10-25'].total_ml, 200,
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

// Guard Reset di mode cloud: handler-nya anonim di addEventListener, jadi
// dibaca langsung dari sumber. Yang dijaga urutannya: early-return cloud harus
// muncul SEBELUM fsm.resetStats() — kalau kebalik, reset tetap jalan walau
// guard ada di file.
const resetHandler =
  /\$\('bReset'\)\.addEventListener\('click', \(\) => \{([\s\S]*?)\n\}\);/.exec(html);
assert(resetHandler, 'handler bReset tidak ditemukan di index.html');
const resetBody = resetHandler[1];
const iGuard = resetBody.indexOf("connMode === 'cloud'");
const iReset = resetBody.indexOf('fsm.resetStats()');
assert(iGuard >= 0, 'guard mode cloud hilang dari handler Reset');
assert(iReset > iGuard, 'guard cloud harus muncul sebelum fsm.resetStats()');
assert(resetBody.indexOf('return;') > iGuard && resetBody.indexOf('return;') < iReset,
  'guard cloud wajib return, bukan lanjut ke reset');

console.log('[PASS] Guard Reset mode cloud urut sebelum resetStats');
// Logika harian: alat tidak punya jam, jadi "hari ini" dihitung dari selisih
// terhadap baseline tanggal. Tiga kasus yang pernah salah: ganti hari, reset
// di alat, dan simulator yang menulis baseline.
const store2 = {};
const ls2 = {
  getItem: k => (k in store2 ? store2[k] : null),
  setItem: (k, v) => { store2[k] = String(v); },
};

let FAKE_TODAY = '2026-11-03';
const dayKey = () => FAKE_TODAY;

// eslint-disable-next-line no-new-func
const dayApi = new Function('localStorage', 'todayKey',
  extract('dayBaseline') + '\n' + extract('ensureDayBaseline') + '\n' +
  extract('todayDelta') +
  '\nreturn { dayBaseline, ensureDayBaseline, todayDelta };'
)(ls2, dayKey);

assert.strictEqual(dayApi.todayDelta(500, 2, 1, 0).total_ml, 0,
  'baseline pertama = 0 ml hari ini');
assert.strictEqual(dayApi.todayDelta(700, 3, 1, 0).total_ml, 200, 'selisih dari baseline');
assert.strictEqual(dayApi.todayDelta(700, 3, 1, 0).drink_count, 1);

// Ganti hari: baseline baru, bukan mewarisi kemarin.
FAKE_TODAY = '2026-11-04';
assert.strictEqual(dayApi.todayDelta(700, 3, 1, 0).total_ml, 0, 'hari baru mulai dari nol');
assert.strictEqual(dayApi.todayDelta(850, 4, 1, 0).total_ml, 150, 'hari baru dihitung dari awal');

// Reset di alat: total turun, baseline dipasang ulang agar tidak negatif.
assert.strictEqual(dayApi.todayDelta(0, 0, 0, 0).total_ml, 0,
  'reset alat tidak menghasilkan angka negatif');
assert.strictEqual(dayApi.todayDelta(120, 1, 0, 0).total_ml, 120,
  'minum setelah reset tetap terhitung');

console.log('[PASS] Hitungan harian: baseline, ganti hari, reset alat');
console.log('SEMUA LULUS (daily-history.test.js)');
