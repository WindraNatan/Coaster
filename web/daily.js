'use strict';

function defaultTodayKey() {
  const d = new Date();
  return d.getFullYear() + '-' +
    String(d.getMonth() + 1).padStart(2, '0') + '-' +
    String(d.getDate()).padStart(2, '0');
}

function loadDailyHistory(storage = globalThis.localStorage) {
  try {
    const raw = storage && typeof storage.getItem === 'function'
      ? storage.getItem('shc_daily_history')
      : null;
    return JSON.parse(raw || '{}');
  } catch (_) {
    return {};
  }
}

function dayBaseline(storage = globalThis.localStorage) {
  try {
    const raw = storage && typeof storage.getItem === 'function'
      ? storage.getItem('shc_day_base')
      : null;
    return JSON.parse(raw || 'null');
  } catch (_) {
    return null;
  }
}

function ensureDayBaseline(totMl, drink, refill, cheat, storage = globalThis.localStorage, todayKeyFn = defaultTodayKey) {
  const k = todayKeyFn();
  const b = dayBaseline(storage);
  const turun = b && (totMl < b.total_ml || drink < b.drink_count);
  if (b && b.date === k && !turun) return b;
  const next = {
    date: k,
    total_ml: totMl,
    drink_count: drink,
    refill_count: refill,
    cheat_count: cheat
  };
  if (storage && typeof storage.setItem === 'function') {
    storage.setItem('shc_day_base', JSON.stringify(next));
  }
  return next;
}

function todayDelta(totMl, drink, refill, cheat, storage = globalThis.localStorage, todayKeyFn = defaultTodayKey) {
  const b = ensureDayBaseline(totMl, drink, refill, cheat, storage, todayKeyFn);
  return {
    total_ml: Math.max(0, totMl - b.total_ml),
    drink_count: Math.max(0, drink - b.drink_count),
    refill_count: Math.max(0, refill - b.refill_count),
    cheat_count: Math.max(0, cheat - b.cheat_count)
  };
}

function peekTodayDelta(totMl, drink, refill, cheat, storage = globalThis.localStorage, todayKeyFn = defaultTodayKey) {
  const b = dayBaseline(storage);
  const k = todayKeyFn();
  if (!b || b.date !== k || totMl < b.total_ml || drink < b.drink_count) {
    return { total_ml: 0, drink_count: 0, refill_count: 0, cheat_count: 0 };
  }
  return {
    total_ml: Math.max(0, totMl - b.total_ml),
    drink_count: Math.max(0, drink - b.drink_count),
    refill_count: Math.max(0, refill - b.refill_count),
    cheat_count: Math.max(0, cheat - b.cheat_count)
  };
}

function saveTodayStatsToHistory(fsm, onRender = null, storage = globalThis.localStorage, todayKeyFn = defaultTodayKey) {
  const hist = loadDailyHistory(storage);
  const k = todayKeyFn();
  const d = todayDelta(
    Math.round(fsm.totalDrank),
    fsm.drinkCount,
    fsm.refillCount,
    fsm.cheatCount,
    storage,
    todayKeyFn
  );
  hist[k] = {
    total_ml: d.total_ml,
    drink_count: d.drink_count,
    refill_count: d.refill_count,
    cheat_count: d.cheat_count
  };
  const keys = Object.keys(hist).sort().reverse();
  if (keys.length > 30) {
    keys.slice(30).forEach(old => { delete hist[old]; });
  }
  if (storage && typeof storage.setItem === 'function') {
    storage.setItem('shc_daily_history', JSON.stringify(hist));
  }
  if (typeof onRender === 'function') onRender(hist);
  return hist;
}

function resetDailyStatsGuarded({ connMode, fsm, onSaveHistory, onSendSerialReset }) {
  if (connMode === 'cloud') {
    return false;
  }
  if (typeof onSaveHistory === 'function') onSaveHistory();
  if (fsm && typeof fsm.resetStats === 'function') fsm.resetStats();
  if (connMode === 'usb' && typeof onSendSerialReset === 'function') {
    onSendSerialReset('r\n');
  }
  return true;
}

function createDailyCloudPusher({
  getConnMode,
  getCoasterUrl,
  ensureToken,
  getAuthSuffix,
  getTodayDelta,
  getTodayKey = defaultTodayKey,
  fetchFn = (...args) => globalThis.fetch(...args)
}) {
  let lastDailyJson = '';

  async function pushDailyCloud() {
    if (getConnMode() !== 'cloud') return false;
    const url = getCoasterUrl();
    if (!url) return false;
    try {
      if (!await ensureToken()) return false;
      const dd = getTodayDelta();
      const isi = JSON.stringify({
        total_ml: +Number(dd.total_ml || 0).toFixed(1),
        drink_count: Number(dd.drink_count || 0),
        refill_count: Number(dd.refill_count || 0),
        cheat_count: Number(dd.cheat_count || 0)
      });
      const k = getTodayKey();
      const stamp = k + '|' + isi;
      if (stamp === lastDailyJson) return false;
      lastDailyJson = stamp;
      await fetchFn(url + '/daily/' + k + '.json' + getAuthSuffix(), {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: isi
      });
      return true;
    } catch (_) {
      lastDailyJson = '';
      return false;
    }
  }

  return {
    pushDailyCloud,
    getLastMemo: () => lastDailyJson,
    resetMemo: () => { lastDailyJson = ''; }
  };
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    defaultTodayKey,
    loadDailyHistory,
    dayBaseline,
    ensureDayBaseline,
    todayDelta,
    peekTodayDelta,
    saveTodayStatsToHistory,
    resetDailyStatsGuarded,
    createDailyCloudPusher
  };
}
