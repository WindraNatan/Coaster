'use strict';
// ponytail: hanya uji regresi tekan-lepas, kalibrasi, dan paritas adaptif di JS; suite penuh ada di test_simulation.py dan uji_fsm.cpp.
const assert = require('assert');
const { CFG, computeAdaptiveIntervalMs, CoasterFSM, mutedFrom } = require('./fsm.js');

function settle(f, w, t0){
  f.update(w, t0);
  for (let i = 1; i <= 16; i++) f.update(w, t0 + i * 100);
}

function mk(){
  const f = new CoasterFSM(130.0, 15000);
  f.setMaxLift(10000);
  return f;
}

const k = mk();
settle(k, 380, 1000);
assert.strictEqual(k.state, 'TIMING');
assert.strictEqual(k.baseline, 380);
k.update(380, 30000);
assert.strictEqual(k.state, 'ALERT_DRINK');
settle(k, 415, 30000);
assert.strictEqual(k.refillCount, 1);
settle(k, 380, 33000);
assert.strictEqual(k.refillCount, 0);
assert.strictEqual(k.drinkCount, 0);
assert.strictEqual(k.totalDrank, 0);
assert.strictEqual(k.baseline, 380);
assert.strictEqual(k.state, 'ALERT_DRINK');
console.log('[PASS] 18. Tekan-lepas 35g: refill pending dibatalkan, 0 minum palsu, baseline utuh, alarm pulih');

k.setEmptyCup(130);
assert.strictEqual(k.stateString, 'ALERT_EMPTY_CUP');
settle(k, 380, 36000);
assert.strictEqual(k.refillCount, 0);
assert.strictEqual(k.drinkCount, 0);
assert.strictEqual(k.totalDrank, 0);
assert.strictEqual(k.state, 'TIMING');
assert.strictEqual(k.baseline, 380);
console.log('[PASS] 19. Kalibrasi dengan gelas berisi 380g: 0 refill palsu, baseline = berat aktual');

const m = mk();
settle(m, 380, 1000);
assert.strictEqual(m.state, 'TIMING');
assert.strictEqual(m.baseline, 380);
settle(m, 415, 12000);
assert.strictEqual(m.refillCount, 1);
settle(m, 380, 14000);
assert.strictEqual(m.refillCount, 0);
assert.strictEqual(m.drinkCount, 0);
assert.strictEqual(m.baseline, 380);
assert.strictEqual(m.state, 'TIMING');
m.update(380, 17700);
assert.strictEqual(m.state, 'ALERT_DRINK');
console.log('[PASS] 20. Tekan-lepas di TIMING: timer dipulihkan, alarm tidak tertunda');

const n = mk();
settle(n, 380, 1000);
n.setEmptyCup(130);
assert.strictEqual(n.stateString, 'ALERT_EMPTY_CUP');
n.update(0, 3000);
assert.strictEqual(n.state, 'LIFTED');
settle(n, 100, 4000);
assert.strictEqual(n.stateString, 'ALERT_EMPTY_CUP');
assert.strictEqual(n.drinkCount, 1);
settle(n, 400, 5700);
// drinkCount == 1 di atas adalah quirk baseline kalibrasi; align tidak boleh menyerap refill berikutnya.
assert.strictEqual(n.refillCount, 1);
assert.strictEqual(n.state, 'TIMING');
assert.strictEqual(n.baseline, 400);
console.log('[PASS] 21. Flag kalibrasi tidak basi: isi ulang cepat setelah lift tetap terhitung');

assert.strictEqual(mutedFrom({muted: true}, {muted: false}), true,
  'config.muted=true harus menang walau telemetry masih false');
assert.strictEqual(mutedFrom({muted: false}, {muted: true}), false,
  'config.muted=false harus menang walau telemetry masih true');
assert.strictEqual(mutedFrom(null, {muted: true}), true,
  'tanpa config, telemetry dipakai sebagai cadangan');
assert.strictEqual(mutedFrom({}, {muted: false}), false,
  'config tanpa field muted jatuh ke telemetry');
assert.strictEqual(mutedFrom(null, null), null,
  'tanpa keduanya, nilai yang sedang dipakai dipertahankan');
assert.strictEqual(mutedFrom({muted: true}, null), true,
  'config saja sudah cukup');
console.log('[PASS] 22. muted dari config, bukan echo telemetry');
assert.strictEqual(computeAdaptiveIntervalMs(CFG.DEMO_INTERVAL, 34.0, 55.0), 7500,
  '34C/55% -> 15 detik jadi 7,5 detik');
assert.strictEqual(computeAdaptiveIntervalMs(1800000, 30.0, 55.0), 1350000,
  '30C/55% -> 22,5 menit');
assert.strictEqual(computeAdaptiveIntervalMs(1800000, 22.0, 75.0), 1980000,
  '22C/75% -> 33 menit');
assert.strictEqual(computeAdaptiveIntervalMs(1800000, 26.0, 30.0), 1530000,
  '26C/30% -> 25,5 menit');
assert.strictEqual(computeAdaptiveIntervalMs(60000, NaN, 50.0), 60000,
  'NaN -> interval dasar');
assert.strictEqual(computeAdaptiveIntervalMs(1000, 40.0, 10.0), CFG.FLOOR,
  'lantai 5 detik berlaku');
console.log('[PASS] 23. rumus adaptif JS sama dengan C++ dan Python');

const r = new CoasterFSM(130.0, 15000);
r.setMaxLift(10000);
r.setInterval_(5000);
settle(r, 380, 1000);
assert.strictEqual(r.state, 'TIMING');
r.update(0, 3000);
settle(r, 340, 3100);
assert.strictEqual(r.drinkCount, 1);
r.toIdle(4000);
assert.strictEqual(r.state, 'IDLE');
assert.strictEqual(r.alertActive, false);
assert.strictEqual(r.drinkCount, 1);
r.update(340, 5000);
assert.strictEqual(r.state, 'STABLE');
console.log('[PASS] 24. Standby: toIdle mematikan alarm, statistik utuh, siklus lama tidak dilanjutkan');

console.log('\nSEMUA LULUS (fsm.test.js)');
