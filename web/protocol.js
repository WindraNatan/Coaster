'use strict';

const { CFG, computeAdaptiveIntervalMs } = require('./fsm.js');

function canonicalState(rawState) {
  const s = typeof rawState === 'string' && rawState.trim() ? rawState.trim() : 'IDLE';
  if (s === 'ALERT_EMPTY_CUP' || s === 'ALERT_MISSING_CUP') return 'ALERT_REFILL';
  return s;
}

function stateBadgeLabel(rawState) {
  const canon = canonicalState(rawState);
  if (canon === 'ALERT_REFILL') return 'REFILL';
  if (canon === 'ALERT_CHEAT') return 'CHEAT';
  return canon.replace(/_/g, ' ');
}

function parseCloudTelemetry(t) {
  if (!t || typeof t !== 'object') return null;
  const rawState = typeof t.fsm_state === 'string' && t.fsm_state.trim()
    ? t.fsm_state.trim()
    : 'IDLE';
  const state = canonicalState(rawState);
  const weightG = Number.isFinite(Number(t.weight_g)) ? Number(t.weight_g) : 0;
  const waterMl = Number.isFinite(Number(t.water_ml)) ? Math.max(0, Number(t.water_ml)) : 0;
  const tempC = Number.isFinite(Number(t.temp_c)) ? Number(t.temp_c) : 27.0;
  const humidityPct = Number.isFinite(Number(t.humidity_pct)) ? Number(t.humidity_pct) : 60;
  const remainingSec = Number.isFinite(Number(t.remaining_sec))
    ? Math.max(0, Math.round(Number(t.remaining_sec)))
    : 0;
  const targetIntervalMin = Number.isFinite(Number(t.target_interval_min)) && Number(t.target_interval_min) > 0
    ? Number(t.target_interval_min)
    : 30;
  const targetMs = Math.max(CFG.FLOOR, Math.round(targetIntervalMin * 60000));
  const totalMl = Number.isFinite(Number(t.total_ml)) ? Math.max(0, Number(t.total_ml)) : 0;
  const drinkCount = Number.isFinite(Number(t.drink_count)) ? Math.max(0, Math.trunc(Number(t.drink_count))) : 0;
  const refillCount = Number.isFinite(Number(t.refill_count)) ? Math.max(0, Math.trunc(Number(t.refill_count))) : 0;
  const cheatCount = Number.isFinite(Number(t.cheat_count)) ? Math.max(0, Math.trunc(Number(t.cheat_count))) : 0;
  const muted = typeof t.muted === 'boolean' ? t.muted : null;
  const standby = t.standby === true;
  const hb = Number.isFinite(Number(t.hb)) ? Math.trunc(Number(t.hb)) : 0;

  return {
    rawState,
    state,
    missingCup: rawState === 'ALERT_MISSING_CUP',
    emptyCup: rawState === 'ALERT_EMPTY_CUP',
    weightG,
    waterMl,
    tempC,
    humidityPct,
    remainingSec,
    targetIntervalMin,
    targetMs,
    totalMl,
    drinkCount,
    refillCount,
    cheatCount,
    muted,
    standby,
    hb
  };
}

function parseCloudConfig(c) {
  if (!c || typeof c !== 'object') return null;
  const mode = (c.timer_mode === 'DEMO' || c.timer_mode === 'AUTO_DHT' || c.timer_mode === 'MANUAL')
    ? c.timer_mode
    : null;
  const mins = Number(c.manual_interval_min);
  const manualIntervalMin = (Number.isFinite(mins) && mins >= 1 && mins <= 180)
    ? Math.round(mins)
    : null;
  const emptyG = Number(c.empty_cup_weight_g);
  const emptyCupWeightG = (Number.isFinite(emptyG) && emptyG >= CFG.CUP_ON && emptyG <= CFG.MAX_EMPTY)
    ? emptyG
    : null;
  const muted = typeof c.muted === 'boolean' ? c.muted : null;

  return {
    timerMode: mode,
    demo: mode ? mode === 'DEMO' : null,
    autoDht: mode ? (mode === 'DEMO' ? null : mode === 'AUTO_DHT') : null,
    manualIntervalMin,
    emptyCupWeightG,
    muted
  };
}

function buildConfigPatch(partial) {
  const out = {};
  if (!partial || typeof partial !== 'object') return out;
  if (partial.timerMode === 'DEMO' || partial.timerMode === 'AUTO_DHT' || partial.timerMode === 'MANUAL') {
    out.timer_mode = partial.timerMode;
  } else if (typeof partial.demo === 'boolean' || typeof partial.autoDht === 'boolean') {
    const isDemo = Boolean(partial.demo);
    const isAuto = partial.autoDht !== undefined ? Boolean(partial.autoDht) : true;
    out.timer_mode = isDemo ? 'DEMO' : (isAuto ? 'AUTO_DHT' : 'MANUAL');
  }
  if (partial.manualIntervalMin !== undefined) {
    const m = Math.round(Number(partial.manualIntervalMin));
    if (Number.isFinite(m) && m >= 1 && m <= 180) {
      out.manual_interval_min = m;
    }
  }
  if (partial.emptyCupWeightG !== undefined) {
    const g = Number(partial.emptyCupWeightG);
    if (Number.isFinite(g) && g >= CFG.CUP_ON && g <= CFG.MAX_EMPTY) {
      out.empty_cup_weight_g = +g.toFixed(1);
    }
  }
  if (typeof partial.muted === 'boolean') {
    out.muted = partial.muted;
  }
  return out;
}

function formatEmptyCupSerialCmd(weightG) {
  const g = Number(weightG);
  if (!Number.isFinite(g) || g < CFG.CUP_ON || g > CFG.MAX_EMPTY) return null;
  return 'e' + g.toFixed(1) + '\n';
}

function parseSerialLine(line) {
  if (typeof line !== 'string' || !line.includes('State:')) return null;
  const mState = /State:\s*([A-Z_]+)/.exec(line);
  const mWeight = /Berat:\s*([\d.-]+)g/.exec(line);
  const mWater = /Air:\s*([\d.-]+)ml/.exec(line);
  const mTemp = /Suhu:\s*([\d.-]+)C/.exec(line);
  const mHum = /RH:\s*([\d.-]+)%/.exec(line);
  const mRem = /SisaWaktu:\s*(\d+)s/.exec(line);
  const mDrank = /Diminum:\s*([\d.-]+)ml/.exec(line);
  const mDrink = /Minum:\s*(\d+)x/.exec(line);
  const mCheat = /Cheat:\s*(\d+)/.exec(line);
  const mRefill = /Refill:\s*(\d+)x/.exec(line);
  const mTarget = /Target:\s*(\d+)s/.exec(line);
  const mMode = /Mode:\s*(DEMO|NORM)-(AUTO|MANUAL)/.exec(line);
  const mBuzzer = /Buzzer:\s*(MUTE|ON)/.exec(line);
  const mSesi = /Sesi:\s*(TIDUR|AKTIF)/.exec(line);

  const rawState = mState ? mState[1] : 'IDLE';
  return {
    rawState,
    state: canonicalState(rawState),
    missingCup: rawState === 'ALERT_MISSING_CUP',
    emptyCup: rawState === 'ALERT_EMPTY_CUP',
    weightG: mWeight ? parseFloat(mWeight[1]) : null,
    waterMl: mWater ? parseFloat(mWater[1]) : null,
    tempC: mTemp ? parseFloat(mTemp[1]) : null,
    humidityPct: mHum ? parseFloat(mHum[1]) : null,
    remainingSec: mRem ? parseInt(mRem[1], 10) : null,
    totalMl: mDrank ? parseFloat(mDrank[1]) : null,
    drinkCount: mDrink ? parseInt(mDrink[1], 10) : null,
    cheatCount: mCheat ? parseInt(mCheat[1], 10) : null,
    refillCount: mRefill ? parseInt(mRefill[1], 10) : null,
    targetSec: mTarget ? parseInt(mTarget[1], 10) : null,
    demo: mMode ? mMode[1] === 'DEMO' : null,
    autoDht: mMode ? mMode[2] === 'AUTO' : null,
    muted: mBuzzer ? mBuzzer[1] === 'MUTE' : null,
    standby: mSesi ? mSesi[1] === 'TIDUR' : null
  };
}

function computeEffectiveIntervalMs({ demo, autoDht, baseIntervalMin, tempC, humidityPct }) {
  const baseMs = demo ? CFG.DEMO_INTERVAL : Math.max(1, Number(baseIntervalMin) || 30) * 60000;
  if (autoDht && !demo) {
    return computeAdaptiveIntervalMs(baseMs, tempC, humidityPct);
  }
  return baseMs;
}

function setNestedPath(root, parts, value, mergeObj = false) {
  let cur = root;
  for (let i = 0; i < parts.length - 1; i++) {
    const k = parts[i];
    const next = cur[k];
    cur[k] = next && typeof next === 'object' ? { ...next } : {};
    cur = cur[k];
  }
  const leaf = parts[parts.length - 1];
  if (value === null || value === undefined) {
    delete cur[leaf];
  } else if (mergeObj && cur[leaf] && typeof cur[leaf] === 'object' && typeof value === 'object') {
    cur[leaf] = { ...cur[leaf], ...value };
  } else {
    cur[leaf] = value;
  }
}

function applySseEvent(cache, eventType, payload) {
  const base = cache && typeof cache === 'object' ? cache : {};
  if (!payload || typeof payload !== 'object') {
    return { changed: false, next: cache || null };
  }
  const path = typeof payload.path === 'string' && payload.path ? payload.path : '/';
  const data = payload.data;

  if (eventType === 'put') {
    if (path === '/') {
      return {
        changed: true,
        next: data && typeof data === 'object' ? { ...data } : null
      };
    }
    const root = { ...base };
    const parts = path.split('/').filter(Boolean);
    if (parts.length > 0) setNestedPath(root, parts, data, false);
    return { changed: true, next: root };
  }

  if (eventType === 'patch') {
    if (path === '/') {
      if (data && typeof data === 'object') {
        return { changed: true, next: { ...base, ...data } };
      }
      return { changed: false, next: cache || null };
    }
    const root = { ...base };
    const parts = path.split('/').filter(Boolean);
    if (parts.length > 0) setNestedPath(root, parts, data, true);
    return { changed: true, next: root };
  }

  return { changed: false, next: cache || null };
}

function isNewTelemetryFrame(prevTlm, nextTlm) {
  if (!nextTlm) return false;
  if (!prevTlm) return true;
  if (nextTlm.hb > 0 || prevTlm.hb > 0) {
    return nextTlm.hb !== prevTlm.hb;
  }
  return (
    nextTlm.rawState !== prevTlm.rawState ||
    nextTlm.standby !== prevTlm.standby ||
    nextTlm.remainingSec !== prevTlm.remainingSec
  );
}

function computeLiveRemainingSec(tlm, anchoredAtMs, nowMs) {
  if (!tlm || tlm.standby) return null;
  if (tlm.state === 'ALERT_DRINK') return 0;
  if (tlm.state !== 'TIMING') return null;
  const base = Math.max(0, Math.round(Number(tlm.remainingSec) || 0));
  if (!Number.isFinite(anchoredAtMs) || !Number.isFinite(nowMs)) return base;
  const elapsedSec = Math.max(0, Math.floor((nowMs - anchoredAtMs) / 1000));
  return Math.max(0, base - elapsedSec);
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    canonicalState,
    stateBadgeLabel,
    parseCloudTelemetry,
    parseCloudConfig,
    buildConfigPatch,
    formatEmptyCupSerialCmd,
    parseSerialLine,
    computeEffectiveIntervalMs,
    applySseEvent,
    isNewTelemetryFrame,
    computeLiveRemainingSec
  };
}
