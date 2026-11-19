'use strict';
// Regresi riwayat harian web/daily.js (dipakai oleh web/src/App.jsx).
// Menguji modul produksi secara langsung:
// (1) urutan simpan-dulu-baru-reset mempertahankan catatan hari ini,
// (2) pemangkasan 30 hari terbaru,
// (3) guard Reset di mode cloud menolak reset sebelum fsm.resetStats(),
// (4) baseline tanggal, pergantian hari, dan pemulihan saat alat di-reset.
const assert = require('assert');
const {
  loadDailyHistory,
  todayDelta,
  saveTodayStatsToHistory,
  resetDailyStatsGuarded
} = require('./daily.js');

function makeStorage() {
  const store = {};
  return {
    getItem: k => (k in store ? store[k] : null),
    setItem: (k, v) => { store[k] = String(v); }
  };
}

const ls1 = makeStorage();
const fsm = {
  totalDrank: 0,
  drinkCount: 0,
  refillCount: 0,
  cheatCount: 0,
  resetCalled: 0,
  resetStats() {
    this.totalDrank = 0;
    this.drinkCount = 0;
    this.refillCount = 0;
    this.cheatCount = 0;
    this.resetCalled++;
  }
};
const todayKey = () => '2026-10-25';

// 1. Simpan-dulu-baru-reset mempertahankan catatan hari ini.
fsm.totalDrank = 420; fsm.drinkCount = 3;
saveTodayStatsToHistory(fsm, null, ls1, todayKey);
assert.strictEqual(loadDailyHistory(ls1)['2026-10-25'].total_ml, 0,
  'baseline dipasang pada penyimpanan pertama');

fsm.totalDrank = 620; fsm.drinkCount = 4;
saveTodayStatsToHistory(fsm, null, ls1, todayKey);
assert.strictEqual(loadDailyHistory(ls1)['2026-10-25'].total_ml, 200,
  'selisih terhadap baseline dicatat sebagai harian');

fsm.totalDrank = 0; fsm.drinkCount = 0;
assert.strictEqual(loadDailyHistory(ls1)['2026-10-25'].total_ml, 200,
  'reset setelah simpan tidak boleh menimpa riwayat yang sudah ada');

// 2. Urutan terbalik (reset dulu, simpan kemudian) memang merusak riwayat.
fsm.totalDrank = 0; fsm.drinkCount = 0;
saveTodayStatsToHistory(fsm, null, ls1, todayKey);
assert.strictEqual(loadDailyHistory(ls1)['2026-10-25'].total_ml, 0,
  'menyimpan setelah reset menulis nol ke riwayat hari ini');

// 3. Riwayat dipangkas ke 30 hari terbaru.
const many = {};
for (let d = 1; d <= 40; d++) {
  many[`2026-09-${String(d).padStart(2, '0')}`] = { total_ml: d, drink_count: 1, refill_count: 0, cheat_count: 0 };
}
ls1.setItem('shc_daily_history', JSON.stringify(many));
fsm.totalDrank = 0;
saveTodayStatsToHistory(fsm, null, ls1, todayKey);
const trimmed = Object.keys(loadDailyHistory(ls1));
assert.strictEqual(trimmed.length, 30, `harus 30 entri, dapat ${trimmed.length}`);
assert(trimmed.includes('2026-10-25'), 'hari terbaru wajib ada');
assert(!trimmed.includes('2026-09-01'), 'entri terlama harus dibuang');

// 4. Guard Reset di mode cloud: early-return sebelum saveHistory/resetStats,
//    dan di mode USB mengirim perintah serial 'r\n'.
let savedBeforeReset = false;
let serialCmd = '';
fsm.totalDrank = 350; fsm.drinkCount = 2; fsm.resetCalled = 0;
const cloudRes = resetDailyStatsGuarded({
  connMode: 'cloud',
  fsm,
  onSaveHistory: () => { savedBeforeReset = true; },
  onSendSerialReset: cmd => { serialCmd = cmd; }
});
assert.strictEqual(cloudRes, false, 'mode cloud wajib menolak reset lokal');
assert.strictEqual(fsm.resetCalled, 0, 'fsm.resetStats tidak boleh dipanggil di mode cloud');
assert.strictEqual(savedBeforeReset, false, 'saveHistory tidak dipanggil saat cloud ditolak');

let order = [];
const usbRes = resetDailyStatsGuarded({
  connMode: 'usb',
  fsm: {
    resetStats() { order.push('reset'); }
  },
  onSaveHistory: () => { order.push('save'); },
  onSendSerialReset: cmd => { order.push('serial:' + cmd.trim()); }
});
assert.strictEqual(usbRes, true);
assert.deepStrictEqual(order, ['save', 'reset', 'serial:r'],
  'urutan wajib: simpan riwayat -> reset FSM -> kirim perintah serial r');
console.log('[PASS] Guard Reset mode cloud & urutan simpan-reset-serial terverifikasi');

// 5. Logika harian: baseline tanggal, ganti hari, reset di alat.
const ls2 = makeStorage();
let FAKE_TODAY = '2026-11-03';
const dayKey = () => FAKE_TODAY;

assert.strictEqual(todayDelta(500, 2, 1, 0, ls2, dayKey).total_ml, 0,
  'baseline pertama = 0 ml hari ini');
assert.strictEqual(todayDelta(700, 3, 1, 0, ls2, dayKey).total_ml, 200, 'selisih dari baseline');
assert.strictEqual(todayDelta(700, 3, 1, 0, ls2, dayKey).drink_count, 1);

FAKE_TODAY = '2026-11-04';
assert.strictEqual(todayDelta(700, 3, 1, 0, ls2, dayKey).total_ml, 0, 'hari baru mulai dari nol');
assert.strictEqual(todayDelta(850, 4, 1, 0, ls2, dayKey).total_ml, 150, 'hari baru dihitung dari awal');

assert.strictEqual(todayDelta(0, 0, 0, 0, ls2, dayKey).total_ml, 0,
  'reset alat tidak menghasilkan angka negatif');
assert.strictEqual(todayDelta(120, 1, 0, 0, ls2, dayKey).total_ml, 120,
  'minum setelah reset tetap terhitung');

console.log('[PASS] Hitungan harian: baseline, ganti hari, reset alat');
console.log('SEMUA LULUS (daily-history.test.js)');
