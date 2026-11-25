'use strict';
// Regresi jalur tulis /daily/<tanggal> di mode cloud melalui modul produksi web/daily.js.
const assert = require('assert');
const { createDailyCloudPusher } = require('./daily.js');

let connMode = 'cloud';
let tanggal = '2026-11-07';
let delta = { total_ml: 300, drink_count: 2, refill_count: 0, cheat_count: 0 };
let jawabFetch = true;
const panggilan = [];

const fakeFetch = async (url, opt) => {
  panggilan.push({ url, opt });
  if (!jawabFetch) throw new Error('jaringan mati');
  return { ok: true };
};

const pusher = createDailyCloudPusher({
  getConnMode: () => connMode,
  getCoasterUrl: () => 'https://rtdb.test/users/u1/smart_coaster',
  ensureToken: async () => true,
  getAuthSuffix: () => '?auth=tok',
  getTodayDelta: () => ({ ...delta }),
  getTodayKey: () => tanggal,
  fetchFn: fakeFetch
});

(async () => {
  await pusher.pushDailyCloud();
  assert.strictEqual(panggilan.length, 1, 'satu tulisan saat angka harian berubah');
  const { url, opt } = panggilan[0];
  assert.ok(url.endsWith('/daily/2026-11-07.json?auth=tok'), 'node tujuan: ' + url);
  assert.ok(!url.includes('telemetry.json'), 'mode cloud tidak menulis telemetry.json');
  assert.strictEqual(opt.method, 'PATCH');
  assert.deepStrictEqual(JSON.parse(opt.body), {
    total_ml: 300, drink_count: 2, refill_count: 0, cheat_count: 0
  });

  await pusher.pushDailyCloud();
  assert.strictEqual(panggilan.length, 1, 'isi identik tidak ditulis dua kali');

  delta = { total_ml: 450, drink_count: 3, refill_count: 0, cheat_count: 0 };
  await pusher.pushDailyCloud();
  assert.strictEqual(panggilan.length, 2, 'angka harian baru ikut tertulis');
  assert.strictEqual(JSON.parse(panggilan[1].opt.body).total_ml, 450);

  await pusher.pushDailyCloud();
  assert.strictEqual(panggilan.length, 2, 'isi sama pada hari yang sama: lewati');
  tanggal = '2026-11-08';
  await pusher.pushDailyCloud();
  assert.strictEqual(panggilan.length, 3, 'hari baru ditulis walau angkanya sama');
  assert.ok(panggilan[2].url.includes('/daily/2026-11-08.json'), 'tanggal baru dipakai');

  connMode = 'sim';
  delta = { total_ml: 900, drink_count: 9, refill_count: 1, cheat_count: 0 };
  await pusher.pushDailyCloud();
  connMode = 'usb';
  await pusher.pushDailyCloud();
  assert.strictEqual(panggilan.length, 3, 'sim dan usb tidak menulis /daily dari jalur ini');

  connMode = 'cloud';
  jawabFetch = false;
  await pusher.pushDailyCloud();
  assert.strictEqual(panggilan.length, 4, 'percobaan pertama tetap dikirim');
  assert.strictEqual(pusher.getLastMemo(), '', 'memo dibuang setelah gagal');
  jawabFetch = true;
  await pusher.pushDailyCloud();
  assert.strictEqual(panggilan.length, 5, 'gagal tidak mengunci tulisan berikutnya');

  console.log('[PASS] Riwayat cloud: node /daily, memo tanggal+isi, gerbang mode, pulih setelah gagal');
  console.log('SEMUA LULUS (daily-cloud.test.js)');
})().catch(e => { console.error(e); process.exit(1); });
