'use strict';
const assert = require('assert');
const {
  loadDailyHistory,
  dayBaseline,
  ensureDayBaseline,
  todayDelta,
  peekTodayDelta,
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

fsm.totalDrank = 0; fsm.drinkCount = 0;
saveTodayStatsToHistory(fsm, null, ls1, todayKey);
assert.strictEqual(loadDailyHistory(ls1)['2026-10-25'].total_ml, 0,
  'menyimpan setelah reset menulis nol ke riwayat hari ini');

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

const ls3 = makeStorage();
const peekEmpty = peekTodayDelta(0, 0, 0, 0, ls3, dayKey);
assert.strictEqual(peekEmpty.total_ml, 0);
assert.strictEqual(dayBaseline(ls3), null, 'peekTodayDelta tidak menulis baseline kosong');

ensureDayBaseline(512, 7, 11, 7, ls3, dayKey);
const peekInit = peekTodayDelta(512, 7, 11, 7, ls3, dayKey);
assert.strictEqual(peekInit.total_ml, 0);
assert.strictEqual(peekInit.drink_count, 0);

const peekDrink = peekTodayDelta(662, 8, 11, 7, ls3, dayKey);
assert.strictEqual(peekDrink.total_ml, 150);
assert.strictEqual(peekDrink.drink_count, 1);

console.log('[PASS] Hitungan harian: baseline, ganti hari, reset alat');
console.log('SEMUA LULUS (daily-history.test.js)');
