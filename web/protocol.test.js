'use strict';
// Uji paritas protokol ESP32 <-> Firebase RTDB <-> Web (web/protocol.js).
const assert = require('assert');
const {
  canonicalState,
  stateBadgeLabel,
  parseCloudTelemetry,
  parseCloudConfig,
  buildConfigPatch,
  formatEmptyCupSerialCmd,
  parseSerialLine,
  computeEffectiveIntervalMs
} = require('./protocol.js');

// 1. Pemetaan state kanonik & label badge sesuai DESIGN.md §4 dan app/lib/telemetry.dart
assert.strictEqual(canonicalState('ALERT_EMPTY_CUP'), 'ALERT_REFILL');
assert.strictEqual(canonicalState('ALERT_MISSING_CUP'), 'ALERT_REFILL');
assert.strictEqual(canonicalState('ALERT_DRINK'), 'ALERT_DRINK');
assert.strictEqual(stateBadgeLabel('ALERT_EMPTY_CUP'), 'REFILL');
assert.strictEqual(stateBadgeLabel('ALERT_MISSING_CUP'), 'REFILL');
assert.strictEqual(stateBadgeLabel('ALERT_REFILL'), 'REFILL');
assert.strictEqual(stateBadgeLabel('ALERT_CHEAT'), 'CHEAT');
assert.strictEqual(stateBadgeLabel('ALERT_DRINK'), 'ALERT DRINK');
assert.strictEqual(stateBadgeLabel('TIMING'), 'TIMING');
console.log('[PASS] 1. Pemetaan canonicalState & stateBadgeLabel');

// 2. Parsing telemetry.json sesuai key firmware cloud_sync.h:440-443
const tlm = parseCloudTelemetry({
  weight_g: 345.5,
  water_ml: 215.5,
  temp_c: 30.2,
  humidity_pct: 58,
  fsm_state: 'ALERT_MISSING_CUP',
  remaining_sec: 12,
  target_interval_min: 0.25,
  total_ml: 840.0,
  drink_count: 5,
  refill_count: 2,
  cheat_count: 1,
  muted: true,
  standby: false,
  hb: 42
});
assert.strictEqual(tlm.rawState, 'ALERT_MISSING_CUP');
assert.strictEqual(tlm.state, 'ALERT_REFILL');
assert.strictEqual(tlm.missingCup, true);
assert.strictEqual(tlm.emptyCup, false);
assert.strictEqual(tlm.weightG, 345.5);
assert.strictEqual(tlm.waterMl, 215.5);
assert.strictEqual(tlm.tempC, 30.2);
assert.strictEqual(tlm.humidityPct, 58);
assert.strictEqual(tlm.remainingSec, 12);
assert.strictEqual(tlm.targetMs, 15000);
assert.strictEqual(tlm.totalMl, 840.0);
assert.strictEqual(tlm.drinkCount, 5);
assert.strictEqual(tlm.refillCount, 2);
assert.strictEqual(tlm.cheatCount, 1);
assert.strictEqual(tlm.muted, true);
assert.strictEqual(tlm.standby, false);
assert.strictEqual(tlm.hb, 42);
console.log('[PASS] 2. parseCloudTelemetry membaca skema cloud_sync.h dengan akurat');

// 3. Parsing & pembuatan PATCH config.json sesuai cloud_sync.h:471-472 & telemetry.dart:162
const cfg = parseCloudConfig({
  timer_mode: 'DEMO',
  manual_interval_min: 25,
  empty_cup_weight_g: 145.5,
  muted: true
});
assert.strictEqual(cfg.timerMode, 'DEMO');
assert.strictEqual(cfg.demo, true);
assert.strictEqual(cfg.autoDht, null, 'saat DEMO, autoDht dipertahankan (null)');
assert.strictEqual(cfg.manualIntervalMin, 25);
assert.strictEqual(cfg.emptyCupWeightG, 145.5);
assert.strictEqual(cfg.muted, true);

assert.deepStrictEqual(buildConfigPatch({ muted: true }), { muted: true },
  'PATCH parsial hanya mengirim field yang diubah');
assert.deepStrictEqual(
  buildConfigPatch({ demo: false, autoDht: false, manualIntervalMin: 20, emptyCupWeightG: 140 }),
  { timer_mode: 'MANUAL', manual_interval_min: 20, empty_cup_weight_g: 140.0 }
);
assert.deepStrictEqual(
  buildConfigPatch({ manualIntervalMin: 999, emptyCupWeightG: 10 }),
  {},
  'nilai di luar rentang [1,180] menit dan [35,300] gram ditolak'
);
console.log('[PASS] 3. parseCloudConfig & buildConfigPatch');

// 4. Format perintah serial USB & parser baris telemetri serial
assert.strictEqual(formatEmptyCupSerialCmd(145), 'e145.0\n',
  'kalibrasi numerik wajib memakai perintah e<gram>, bukan c<gram>');
assert.strictEqual(formatEmptyCupSerialCmd(20), null);
assert.strictEqual(formatEmptyCupSerialCmd(350), null);

const ser = parseSerialLine(
  'State: ALERT_EMPTY_CUP | Berat: 132.0g | Air: 2.0ml | Suhu: 29.5C | RH: 62% | SisaWaktu: 0s | Diminum: 640.5ml | Minum: 4x | Cheat: 1 | Refill: 2x | Target: 15s | Mode: DEMO-AUTO | Buzzer: MUTE | Sesi: AKTIF'
);
assert.strictEqual(ser.rawState, 'ALERT_EMPTY_CUP');
assert.strictEqual(ser.state, 'ALERT_REFILL');
assert.strictEqual(ser.emptyCup, true);
assert.strictEqual(ser.totalMl, 640.5, 'Diminum (totalMl) wajib ikut terparsing dari serial');
assert.strictEqual(ser.demo, true);
assert.strictEqual(ser.autoDht, true);
assert.strictEqual(ser.muted, true);
assert.strictEqual(ser.standby, false);
console.log('[PASS] 4. formatEmptyCupSerialCmd & parseSerialLine');

// 5. Interval efektif: mode Demo tidak boleh dikompensasi DHT11 (paritas SmartHydrationCoaster.ino:145)
assert.strictEqual(
  computeEffectiveIntervalMs({ demo: true, autoDht: true, baseIntervalMin: 30, tempC: 34, humidityPct: 30 }),
  15000,
  'mode demo wajib tetap 15000 ms walau autoDht aktif dan suhu panas'
);
assert.strictEqual(
  computeEffectiveIntervalMs({ demo: false, autoDht: true, baseIntervalMin: 30, tempC: 34, humidityPct: 55 }),
  900000,
  'mode normal + autoDht mengkompensasi 30 mnt @ 34C/55% menjadi 15 mnt (900000 ms)'
);
assert.strictEqual(
  computeEffectiveIntervalMs({ demo: false, autoDht: false, baseIntervalMin: 25, tempC: 34, humidityPct: 30 }),
  1500000,
  'mode normal + manual memakai baseIntervalMin apa adanya'
);
console.log('[PASS] 5. computeEffectiveIntervalMs menjaga paritas mode demo vs adaptif DHT11');
console.log('SEMUA LULUS (protocol.test.js)');
