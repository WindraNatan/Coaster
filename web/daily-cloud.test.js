'use strict';
// Regresi jalur tulis /daily/<tanggal> di mode cloud. Alat tidak punya jam, jadi
// node /daily hanya bisa diisi klien. Dulu penulisnya cuma jalur USB
// (pushCloudTelemetry), sehingga pengguna cloud — termasuk yang membuka riwayat
// 7 hari di aplikasi — tidak pernah punya baris riwayat sama sekali.
// Yang dijaga di sini: mode selain cloud tidak menulis apa pun (mode Simulator
// tidak boleh menyentuh node alat nyata), node telemetry tidak pernah ditulis
// dari jalur cloud, dan isi yang sama tidak ditulis dua kali.
const assert = require('assert');
const fs = require('fs');
const path = require('path');

const html = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8');

function extract(name) {
  const m = new RegExp(`function ${name}\\(`).exec(html);
  assert(m, `fungsi ${name} tidak ditemukan di index.html`);
  // `async` berdiri sebelum kata `function`, jadi ikut diambil.
  const start = html.slice(m.index - 6, m.index) === 'async ' ? m.index - 6 : m.index;
  let i = html.indexOf('{', m.index), depth = 0, end = i;
  for (; end < html.length; end++) {
    if (html[end] === '{') depth++;
    else if (html[end] === '}' && --depth === 0) break;
  }
  return html.slice(start, end + 1);
}

const fsm = { totalDrank: 300, drinkCount: 2, refillCount: 0, cheatCount: 0 };
let delta = { total_ml: 300, drink_count: 2, refill_count: 0, cheat_count: 0 };
let jawabFetch = true;
const panggilan = [];

global.fetch = async (url, opt) => {
  panggilan.push({ url, opt });
  if (!jawabFetch) throw new Error('jaringan mati');
  return { ok: true };
};

// eslint-disable-next-line no-new-func
const api = new Function('fsm', 'todayDelta', 'shcCoasterUrl', 'getCleanFbUrl',
  'shcEnsureToken', 'shcAuthSuffix', 'fetch',
  `let connMode = 'cloud';
   let todayKey = () => '';  // diganti lewat setTanggal
   let lastDailyJson = '';
   ${extract('pushDailyCloud')}
   return { pushDailyCloud, setMode: v => { connMode = v; },
            setTanggal: v => { todayKey = () => v; }, bacaMemo: () => lastDailyJson };`
)(fsm, () => ({ ...delta }),
  base => base + '/users/u1/smart_coaster', () => 'https://rtdb.test',
  async () => true, () => '?auth=tok', global.fetch);
api.setTanggal('2026-11-07');

(async () => {
  // 1. Mode cloud: satu PATCH ke node hari ini, tanpa menyentuh telemetry.
  await api.pushDailyCloud();
  assert.strictEqual(panggilan.length, 1, 'satu tulisan saat angka harian berubah');
  const { url, opt } = panggilan[0];
  assert.ok(url.endsWith('/daily/2026-11-07.json?auth=tok'), 'node tujuan: ' + url);
  assert.ok(!url.includes('telemetry.json'), 'mode cloud tidak menulis telemetry.json');
  assert.strictEqual(opt.method, 'PATCH');
  assert.deepStrictEqual(JSON.parse(opt.body), {
    total_ml: 300, drink_count: 2, refill_count: 0, cheat_count: 0
  });

  // 2. Isi sama: tidak ditulis ulang (yang berubah hanya detak telemetri).
  await api.pushDailyCloud();
  assert.strictEqual(panggilan.length, 1, 'isi identik tidak ditulis dua kali');

  // 3. Angka harian berubah: ditulis lagi.
  delta = { total_ml: 450, drink_count: 3, refill_count: 0, cheat_count: 0 };
  await api.pushDailyCloud();
  assert.strictEqual(panggilan.length, 2, 'angka harian baru ikut tertulis');
  assert.strictEqual(JSON.parse(panggilan[1].opt.body).total_ml, 450);

  // 4. Isi yang sama pada hari yang sama dilewati; hari baru tetap ditulis
  //    walau isinya kebetulan sama, kalau tidak baris hari baru tidak muncul.
  await api.pushDailyCloud();
  assert.strictEqual(panggilan.length, 2, 'isi sama pada hari yang sama: lewati');
  api.setTanggal('2026-11-08');
  await api.pushDailyCloud();
  assert.strictEqual(panggilan.length, 3, 'hari baru ditulis walau angkanya sama');
  assert.ok(panggilan[2].url.includes('/daily/2026-11-08.json'), 'tanggal baru dipakai');

  // 5. Mode Simulator dan USB tidak menulis dari sini: sim tidak boleh menyentuh
  //    alat nyata, USB sudah menulis lewat pushCloudTelemetry.
  api.setMode('sim');
  delta = { total_ml: 900, drink_count: 9, refill_count: 1, cheat_count: 0 };
  await api.pushDailyCloud();
  api.setMode('usb');
  await api.pushDailyCloud();
  assert.strictEqual(panggilan.length, 3, 'sim dan usb tidak menulis /daily dari jalur ini');

  // 6. Gagal jaringan: memo dibuang supaya percobaan berikutnya jalan lagi.
  api.setMode('cloud');
  jawabFetch = false;
  await api.pushDailyCloud();
  assert.strictEqual(panggilan.length, 4, 'percobaan pertama tetap dikirim');
  assert.strictEqual(api.bacaMemo(), '', 'memo dibuang setelah gagal');
  jawabFetch = true;
  await api.pushDailyCloud();
  assert.strictEqual(panggilan.length, 5, 'gagal tidak mengunci tulisan berikutnya');

  console.log('[PASS] Riwayat cloud: node /daily, memo tanggal+isi, gerbang mode, pulih setelah gagal');
  console.log('SEMUA LULUS (daily-cloud.test.js)');
})().catch(e => { console.error(e); process.exit(1); });
