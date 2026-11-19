import React, { useState, useEffect, useRef, useCallback } from 'react';
import { CoasterFSM, CFG, mutedFrom } from './fsm';
import {
  defaultTodayKey,
  loadDailyHistory,
  todayDelta,
  saveTodayStatsToHistory,
  resetDailyStatsGuarded,
  createDailyCloudPusher
} from './daily';
import {
  parseCloudTelemetry,
  parseCloudConfig,
  buildConfigPatch,
  formatEmptyCupSerialCmd,
  parseSerialLine,
  computeEffectiveIntervalMs
} from './protocol';
import {
  shcEnsureToken,
  shcAuthSuffix,
  shcCoasterUrl,
  shcDiscoverDevice,
  shcSetSession,
  shcUid,
  getCleanFbUrl
} from './auth';

import Header from './components/Header';
import VisualTumblerCoaster from './components/VisualTumblerCoaster';
import RingGaugeTrio from './components/RingGaugeTrio';
import EnvironmentSessionBar from './components/EnvironmentSessionBar';
import QuickControls from './components/QuickControls';
import HistoryActivityPanel from './components/HistoryActivityPanel';
import LabSimulatorPanel from './components/LabSimulatorPanel';
import LoginModal from './components/LoginModal';
import SessionModeModal from './components/SessionModeModal';

export default function App() {
  const fsmRef = useRef(null);
  if (!fsmRef.current) {
    fsmRef.current = new CoasterFSM();
  }
  const fsm = fsmRef.current;

  const [connMode, setConnMode] = useState('sim'); // 'sim' | 'usb' | 'cloud'
  const [usbConnected, setUsbConnected] = useState(false);
  const [cloudConnected, setCloudConnected] = useState(false);

  const [weight, setWeight] = useState(0);
  const [temp, setTemp] = useState(27.0);
  const [hum, setHum] = useState(60);
  const [warp, setWarp] = useState(1);

  const [stateString, setStateString] = useState('IDLE');
  const [isStable, setIsStable] = useState(false);
  const [standby, setStandby] = useState(false);
  const [cupMl, setCupMl] = useState(0);
  const [remSec, setRemSec] = useState(null);
  const [targetSec, setTargetSec] = useState(15);

  const [sessionMl, setSessionMl] = useState(0);
  const [drinkCount, setDrinkCount] = useState(0);
  const [refillCount, setRefillCount] = useState(0);
  const [cheatCount, setCheatCount] = useState(0);

  const [emptyCup, setEmptyCup] = useState(() => {
    const saved = parseFloat(localStorage.getItem('shc_empty_cup'));
    return !isNaN(saved) && saved >= 35 && saved <= 300 ? saved : CFG.DEFAULT_EMPTY;
  });
  const [baseMin, setBaseMin] = useState(() => {
    const saved = parseInt(localStorage.getItem('shc_base_min'), 10);
    return !isNaN(saved) && saved >= 1 && saved <= 180 ? saved : 30;
  });
  const [autoDht, setAutoDht] = useState(true);
  const [demo, setDemo] = useState(true);
  const [buzzerMuted, setBuzzerMuted] = useState(false);
  const [dailyGoal, setDailyGoal] = useState(() => {
    const saved = parseInt(localStorage.getItem('shc_daily_goal'), 10);
    return !isNaN(saved) && saved >= 500 && saved <= 6000 ? saved : 2000;
  });
  const [timerHint, setTimerHint] = useState(null);

  const [dailyHistory, setDailyHistory] = useState(() => loadDailyHistory());
  const [weightHistory, setWeightHistory] = useState(() => Array(30).fill(0));
  const [logs, setLogs] = useState([]);

  const [simClockSec, setSimClockSec] = useState(0);
  const [activeScenario, setActiveScenario] = useState(null);
  const [scenarioStepText, setScenarioStepText] = useState('');

  const [authModalOpen, setAuthModalOpen] = useState(false);
  const [sessionModalOpen, setSessionModalOpen] = useState(false);
  const [sessionBusy, setSessionBusy] = useState(false);
  const [userEmail, setUserEmail] = useState(() => localStorage.getItem('shc_auth_email') || '');

  const simClockRef = useRef(0);
  const lastPlacedWeightRef = useRef(350);
  const prevFsmStateRef = useRef('IDLE');
  const scenarioTimerRef = useRef(null);
  const serialPortRef = useRef(null);
  const serialReaderRef = useRef(null);
  const audioCtxRef = useRef(null);
  const lastBeepMsRef = useRef(0);

  const cloudCfgCacheRef = useRef(null);
  const cloudTlmCacheRef = useRef(null);
  const sseTlmRef = useRef(null);
  const sseCfgRef = useRef(null);

  const simParamsRef = useRef({
    weight: 0,
    temp: 27.0,
    hum: 60,
    warp: 1,
    standby: false,
    demo: true,
    autoDht: true,
    baseMin: 30,
    buzzerMuted: false
  });
  useEffect(() => {
    simParamsRef.current = {
      weight,
      temp,
      hum,
      warp,
      standby,
      demo,
      autoDht,
      baseMin,
      buzzerMuted
    };
  }, [weight, temp, hum, warp, standby, demo, autoDht, baseMin, buzzerMuted]);

  const connModeRef = useRef(connMode);
  useEffect(() => {
    connModeRef.current = connMode;
  }, [connMode]);

  const addLog = useCallback((tag, msg) => {
    const now = new Date();
    const time =
      String(now.getHours()).padStart(2, '0') +
      ':' +
      String(now.getMinutes()).padStart(2, '0') +
      ':' +
      String(now.getSeconds()).padStart(2, '0');
    setLogs((prev) => [{ time, tag, msg }, ...prev.slice(0, 79)]);
  }, []);

  const playBeep = useCallback((freq = 880, durMs = 110) => {
    if (simParamsRef.current.buzzerMuted) return;
    try {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (!AudioCtx) return;
      if (!audioCtxRef.current) {
        audioCtxRef.current = new AudioCtx();
      }
      const ctx = audioCtxRef.current;
      if (ctx.state === 'suspended') {
        ctx.resume().catch(() => {});
      }
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(0.06, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + durMs / 1000);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start();
      osc.stop(ctx.currentTime + durMs / 1000);
    } catch (_) {}
  }, []);

  // Init FSM empty cup & interval on mount
  useEffect(() => {
    fsm.setEmptyCup(emptyCup);
    const effMs = computeEffectiveIntervalMs({
      demo,
      autoDht,
      baseIntervalMin: baseMin,
      tempC: temp,
      humidityPct: hum
    });
    fsm.setInterval_(effMs);
    fsm.setMaxLift(demo ? CFG.DEMO_MAX_LIFT : CFG.MAX_LIFT);
    setTargetSec(Math.round(effMs / 1000));
    addLog('BOOT', 'Dashboard Smart Hydration Coaster siap.');
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Sync adaptive interval & maxLift whenever mode/temp/hum/baseMin changes in Sim mode
  useEffect(() => {
    if (connMode !== 'sim') return;
    const effMs = computeEffectiveIntervalMs({
      demo,
      autoDht,
      baseIntervalMin: baseMin,
      tempC: temp,
      humidityPct: hum
    });
    fsm.setInterval_(effMs);
    fsm.setMaxLift(demo ? CFG.DEMO_MAX_LIFT : CFG.MAX_LIFT);
    setTargetSec(Math.round(effMs / 1000));
  }, [connMode, demo, autoDht, baseMin, temp, hum, fsm]);

  // Daily cloud pusher instance
  const dailyPusherRef = useRef(null);
  if (!dailyPusherRef.current) {
    dailyPusherRef.current = createDailyCloudPusher({
      getConnMode: () => connModeRef.current,
      getCoasterUrl: () => shcCoasterUrl(getCleanFbUrl()),
      ensureToken: () => shcEnsureToken(),
      getAuthSuffix: () => shcAuthSuffix(),
      getTodayDelta: () =>
        todayDelta(
          Math.round(fsm.totalDrank),
          fsm.drinkCount,
          fsm.refillCount,
          fsm.cheatCount
        )
    });
  }

  const syncHistoryNow = useCallback(() => {
    saveTodayStatsToHistory(fsm, (hist) => {
      setDailyHistory({ ...hist });
    });
    if (connModeRef.current === 'cloud') {
      dailyPusherRef.current.pushDailyCloud();
    }
  }, [fsm]);

  // Send partial PATCH to Firebase /config.json
  const pushCloudConfig = useCallback(
    async (partial) => {
      const patch = buildConfigPatch(partial);
      if (Object.keys(patch).length === 0) return false;
      const base = getCleanFbUrl();
      const url = shcCoasterUrl(base);
      if (!url) return false;
      try {
        if (!(await shcEnsureToken())) return false;
        const res = await fetch(url + '/config.json' + shcAuthSuffix(), {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(patch)
        });
        if (res.ok) {
          cloudCfgCacheRef.current = { ...(cloudCfgCacheRef.current || {}), ...patch };
          return true;
        }
      } catch (_) {}
      return false;
    },
    []
  );

  // Simulator 100ms loop (single stable interval using simParamsRef)
  useEffect(() => {
    if (connMode !== 'sim') return undefined;

    let tickCounter = 0;
    const id = setInterval(() => {
      const p = simParamsRef.current;
      const dt = 100 * p.warp;
      simClockRef.current += dt;
      const now = simClockRef.current;

      if (!p.standby) {
        fsm.update(p.weight, now);
      }

      const rawSt = p.standby ? 'IDLE' : fsm.stateString;
      const prevSt = prevFsmStateRef.current;
      if (rawSt !== prevSt) {
        prevFsmStateRef.current = rawSt;
        addLog('FSM', `Transisi ${prevSt} -> ${rawSt} (${p.weight.toFixed(1)} g)`);
        if (rawSt !== 'TIMING') {
          setTimerHint(null);
        }
        syncHistoryNow();
      }

      const stableNow =
        p.weight >= CFG.CUP_ON &&
        Math.abs(p.weight - fsm.stableCand) <= CFG.STAB_BAND &&
        now - fsm.stableStart >= CFG.STAB_MS;

      setStateString(rawSt);
      setIsStable(Boolean(stableNow));
      setCupMl(fsm.waterMl(p.weight));
      const remMs = fsm.remaining(now);
      setRemSec(remMs !== null ? Math.ceil(remMs / 1000) : null);
      setTargetSec(Math.round(fsm.targetIntervalMs() / 1000));

      setSessionMl(fsm.totalDrank);
      setDrinkCount(fsm.drinkCount);
      setRefillCount(fsm.refillCount);
      setCheatCount(fsm.cheatCount);

      if (!p.standby && fsm.alertActive && Date.now() - lastBeepMsRef.current >= 1200) {
        lastBeepMsRef.current = Date.now();
        playBeep(rawSt === 'ALERT_CHEAT' ? 1040 : 880, 100);
      }

      tickCounter++;
      if (tickCounter % 5 === 0) {
        setSimClockSec(Math.floor(now / 1000));
        setWeightHistory((prev) => [...prev.slice(1), p.weight]);
      }
    }, 100);

    return () => clearInterval(id);
  }, [connMode, fsm, addLog, playBeep, syncHistoryNow]);

  // Apply parsed cloud telemetry & config
  const applyCloudTelemetry = useCallback(
    (rawTlm) => {
      const t = parseCloudTelemetry(rawTlm);
      if (!t) return;
      cloudTlmCacheRef.current = rawTlm;
      setCloudConnected(true);

      setWeight(t.weightG);
      setCupMl(t.waterMl);
      setTemp(t.tempC);
      setHum(t.humidityPct);
      setStateString(t.rawState);
      setStandby(t.standby);
      setIsStable(t.state === 'TIMING' || t.state === 'STABLE');
      setRemSec(t.remainingSec);
      setTargetSec(Math.round(t.targetMs / 1000));

      const drinkIncreased = t.drinkCount > fsm.drinkCount || t.totalMl > fsm.totalDrank;
      fsm.totalDrank = t.totalMl;
      fsm.drinkCount = t.drinkCount;
      fsm.refillCount = t.refillCount;
      fsm.cheatCount = t.cheatCount;

      setSessionMl(t.totalMl);
      setDrinkCount(t.drinkCount);
      setRefillCount(t.refillCount);
      setCheatCount(t.cheatCount);
      setWeightHistory((prev) => [...prev.slice(1), t.weightG]);

      const resolvedMute = mutedFrom(cloudCfgCacheRef.current, rawTlm);
      if (typeof resolvedMute === 'boolean') {
        setBuzzerMuted(resolvedMute);
      }

      if (drinkIncreased) {
        syncHistoryNow();
      }
    },
    [fsm, syncHistoryNow]
  );

  const applyCloudConfig = useCallback(
    (rawCfg) => {
      const c = parseCloudConfig(rawCfg);
      if (!c) return;
      cloudCfgCacheRef.current = rawCfg;
      if (c.demo !== null) setDemo(c.demo);
      if (c.autoDht !== null) setAutoDht(c.autoDht);
      if (c.manualIntervalMin !== null) setBaseMin(c.manualIntervalMin);
      if (c.emptyCupWeightG !== null) {
        setEmptyCup(c.emptyCupWeightG);
        fsm.setEmptyCup(c.emptyCupWeightG);
      }
      const resolvedMute = mutedFrom(rawCfg, cloudTlmCacheRef.current);
      if (typeof resolvedMute === 'boolean') {
        setBuzzerMuted(resolvedMute);
      }
    },
    [fsm]
  );

  // Cloud mode: discovery + REST poll + SSE realtime stream
  const closeCloudStreams = useCallback(() => {
    if (sseTlmRef.current) {
      sseTlmRef.current.close();
      sseTlmRef.current = null;
    }
    if (sseCfgRef.current) {
      sseCfgRef.current.close();
      sseCfgRef.current = null;
    }
  }, []);

  const fetchCloudDailyHistory = useCallback(async (coasterUrl) => {
    try {
      const res = await fetch(coasterUrl + '/daily.json' + shcAuthSuffix());
      if (!res.ok) return;
      const data = await res.json();
      if (!data || typeof data !== 'object') return;
      const merged = { ...loadDailyHistory() };
      Object.entries(data).forEach(([dateKey, val]) => {
        if (val && typeof val === 'object') {
          merged[dateKey] = {
            total_ml: Number(val.total_ml ?? val.ml ?? 0),
            drink_count: Number(val.drink_count ?? val.drinks ?? 0),
            refill_count: Number(val.refill_count ?? 0),
            cheat_count: Number(val.cheat_count ?? 0)
          };
        }
      });
      localStorage.setItem('shc_daily_history', JSON.stringify(merged));
      setDailyHistory(merged);
    } catch (_) {}
  }, []);

  const pollCloudOnce = useCallback(async () => {
    const base = getCleanFbUrl();
    if (!(await shcEnsureToken())) {
      setCloudConnected(false);
      return;
    }
    const url = shcCoasterUrl(base);
    if (!url) {
      setCloudConnected(false);
      return;
    }
    try {
      const [tRes, cRes] = await Promise.all([
        fetch(url + '/telemetry.json' + shcAuthSuffix()),
        fetch(url + '/config.json' + shcAuthSuffix())
      ]);
      if (cRes.ok) {
        const cData = await cRes.json();
        if (cData && typeof cData === 'object') applyCloudConfig(cData);
      }
      if (tRes.ok) {
        const tData = await tRes.json();
        if (tData && typeof tData === 'object') {
          applyCloudTelemetry(tData);
        } else {
          setCloudConnected(false);
        }
      } else {
        setCloudConnected(false);
      }
    } catch (_) {
      setCloudConnected(false);
    }
  }, [applyCloudConfig, applyCloudTelemetry]);

  const startCloudStreams = useCallback(async () => {
    closeCloudStreams();
    const base = getCleanFbUrl();
    if (!(await shcEnsureToken())) {
      setCloudConnected(false);
      return;
    }
    await shcDiscoverDevice(base);
    const url = shcCoasterUrl(base);
    if (!url) {
      setCloudConnected(false);
      return;
    }
    await pollCloudOnce();
    await fetchCloudDailyHistory(url);

    if (typeof window !== 'undefined' && typeof window.EventSource !== 'undefined') {
      try {
        const esTlm = new window.EventSource(url + '/telemetry.json' + shcAuthSuffix());
        esTlm.addEventListener('put', (e) => {
          try {
            const payload = JSON.parse(e.data);
            if (payload && payload.path === '/' && payload.data) {
              applyCloudTelemetry(payload.data);
            } else if (payload && payload.data !== undefined) {
              pollCloudOnce();
            }
          } catch (_) {}
        });
        esTlm.addEventListener('patch', (e) => {
          try {
            const payload = JSON.parse(e.data);
            if (payload && payload.data && typeof payload.data === 'object') {
              const merged = { ...(cloudTlmCacheRef.current || {}), ...payload.data };
              applyCloudTelemetry(merged);
            }
          } catch (_) {}
        });
        sseTlmRef.current = esTlm;

        const esCfg = new window.EventSource(url + '/config.json' + shcAuthSuffix());
        esCfg.addEventListener('put', (e) => {
          try {
            const payload = JSON.parse(e.data);
            if (payload && payload.path === '/' && payload.data) {
              applyCloudConfig(payload.data);
            }
          } catch (_) {}
        });
        esCfg.addEventListener('patch', (e) => {
          try {
            const payload = JSON.parse(e.data);
            if (payload && payload.data && typeof payload.data === 'object') {
              const merged = { ...(cloudCfgCacheRef.current || {}), ...payload.data };
              applyCloudConfig(merged);
            }
          } catch (_) {}
        });
        sseCfgRef.current = esCfg;
      } catch (_) {}
    }
  }, [closeCloudStreams, pollCloudOnce, fetchCloudDailyHistory, applyCloudTelemetry, applyCloudConfig]);

  useEffect(() => {
    if (connMode !== 'cloud') {
      closeCloudStreams();
      return undefined;
    }
    startCloudStreams();
    const safetyPoll = setInterval(pollCloudOnce, 20000);
    return () => {
      clearInterval(safetyPoll);
      closeCloudStreams();
    };
  }, [connMode, startCloudStreams, pollCloudOnce, closeCloudStreams]);

  // USB Web Serial handling
  const disconnectUsbSerial = useCallback(async () => {
    try {
      if (serialReaderRef.current) {
        await serialReaderRef.current.cancel().catch(() => {});
        serialReaderRef.current = null;
      }
      if (serialPortRef.current) {
        await serialPortRef.current.close().catch(() => {});
        serialPortRef.current = null;
      }
    } catch (_) {}
    setUsbConnected(false);
  }, []);

  const sendSerialCmd = useCallback(async (cmd) => {
    if (!serialPortRef.current || !serialPortRef.current.writable) return false;
    try {
      const writer = serialPortRef.current.writable.getWriter();
      await writer.write(new TextEncoder().encode(cmd));
      writer.releaseLock();
      return true;
    } catch (_) {
      return false;
    }
  }, []);

  const handleSerialLine = useCallback(
    (line) => {
      const parsed = parseSerialLine(line);
      if (!parsed) {
        if (line.startsWith('[')) addLog('ESP32', line);
        return;
      }
      setStateString(parsed.rawState);
      if (parsed.weightG !== null) {
        setWeight(parsed.weightG);
        setWeightHistory((prev) => [...prev.slice(1), parsed.weightG]);
      }
      if (parsed.waterMl !== null) setCupMl(parsed.waterMl);
      if (parsed.tempC !== null) setTemp(parsed.tempC);
      if (parsed.humidityPct !== null) setHum(parsed.humidityPct);
      if (parsed.remainingSec !== null) setRemSec(parsed.remainingSec);
      if (parsed.targetSec !== null) setTargetSec(parsed.targetSec);
      if (parsed.totalMl !== null) {
        fsm.totalDrank = parsed.totalMl;
        setSessionMl(parsed.totalMl);
      }
      if (parsed.drinkCount !== null) {
        const up = parsed.drinkCount > fsm.drinkCount;
        fsm.drinkCount = parsed.drinkCount;
        setDrinkCount(parsed.drinkCount);
        if (up) syncHistoryNow();
      }
      if (parsed.refillCount !== null) {
        fsm.refillCount = parsed.refillCount;
        setRefillCount(parsed.refillCount);
      }
      if (parsed.cheatCount !== null) {
        fsm.cheatCount = parsed.cheatCount;
        setCheatCount(parsed.cheatCount);
      }
      if (parsed.demo !== null) setDemo(parsed.demo);
      if (parsed.autoDht !== null) setAutoDht(parsed.autoDht);
      if (parsed.muted !== null) setBuzzerMuted(parsed.muted);
      if (parsed.standby !== null) setStandby(parsed.standby);
      setIsStable(parsed.state === 'TIMING' || parsed.state === 'STABLE');
    },
    [fsm, addLog, syncHistoryNow]
  );

  const connectUsbSerial = useCallback(async () => {
    if (!('serial' in navigator)) {
      addLog('USB', 'Browser ini belum mendukung Web Serial API (gunakan Chrome atau Edge).');
      return;
    }
    try {
      await disconnectUsbSerial();
      const port = await navigator.serial.requestPort();
      await port.open({ baudRate: 115200 });
      serialPortRef.current = port;
      setUsbConnected(true);
      addLog('USB', 'Terhubung ke ESP32 melalui USB Serial.');

      const decoder = new TextDecoderStream();
      port.readable.pipeTo(decoder.writable).catch(() => {});
      const reader = decoder.readable.getReader();
      serialReaderRef.current = reader;

      let buffer = '';
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        if (value) {
          buffer += value;
          const lines = buffer.split(/\r?\n/);
          buffer = lines.pop() || '';
          lines.forEach((l) => {
            if (l.trim()) handleSerialLine(l.trim());
          });
        }
      }
    } catch (err) {
      addLog('USB', `Koneksi USB dibatalkan atau terputus: ${err.message || err}`);
      setUsbConnected(false);
    }
  }, [addLog, disconnectUsbSerial, handleSerialLine]);

  const handleSelectConnMode = (nextMode) => {
    if (scenarioTimerRef.current) {
      clearTimeout(scenarioTimerRef.current);
      scenarioTimerRef.current = null;
      setActiveScenario(null);
      setScenarioStepText('');
    }
    if (connMode === 'usb' && nextMode !== 'usb') {
      disconnectUsbSerial();
    }
    setConnMode(nextMode);
    if (nextMode === 'usb') {
      connectUsbSerial();
    } else if (nextMode === 'cloud') {
      if (!shcUid()) {
        setAuthModalOpen(true);
      }
    }
  };

  // Actions: Tare, Empty Cup Calibration, Timer Mode, Interval, Mute, Goal, Reset, Session
  const handleTare = () => {
    if (connMode === 'cloud') return;
    if (connMode === 'usb') {
      sendSerialCmd('t\n');
      addLog('AKSI', 'Perintah Tare dikirim ke ESP32 lewat USB.');
      return;
    }
    setWeight(0);
    fsm.toIdle(simClockRef.current);
    addLog('AKSI', 'Timbangan simulator dinolkan (0,0 g).');
  };

  const handleCalibrateCup = (val) => {
    const g = Number(val);
    if (!fsm.setEmptyCup(g)) return;
    setEmptyCup(g);
    localStorage.setItem('shc_empty_cup', String(g));
    addLog('KONFIG', `Berat gelas kosong disimpan: ${g.toFixed(1)} g.`);
    if (connMode === 'usb') {
      const cmd = formatEmptyCupSerialCmd(g);
      if (cmd) sendSerialCmd(cmd);
    } else if (connMode === 'cloud') {
      pushCloudConfig({ emptyCupWeightG: g });
    }
  };

  const handleSelectTimerMode = (mode) => {
    const nextDemo = mode === 'DEMO';
    const nextAuto = mode === 'DEMO' ? autoDht : mode === 'AUTO_DHT';
    setDemo(nextDemo);
    if (mode !== 'DEMO') setAutoDht(nextAuto);

    if (stateString === 'TIMING') {
      setTimerHint('Perubahan mode timer akan berlaku penuh pada siklus minum berikutnya.');
    }
    addLog('KONFIG', `Mode timer diubah ke ${mode}.`);

    if (connMode === 'usb') {
      if (nextDemo !== demo) sendSerialCmd('d\n');
      if (mode !== 'DEMO' && nextAuto !== autoDht) sendSerialCmd('m\n');
    } else if (connMode === 'cloud') {
      pushCloudConfig({ timerMode: mode });
    }
  };

  const handleSetInterval = (mins) => {
    const m = Math.round(Number(mins));
    if (isNaN(m) || m < 1 || m > 180) return;
    setBaseMin(m);
    setDemo(false);
    localStorage.setItem('shc_base_min', String(m));
    if (stateString === 'TIMING') {
      setTimerHint(`Interval dasar ${m} menit disimpan; siklus berjalan tetap menyelesaikan target saat ini.`);
    }
    addLog('KONFIG', `Interval dasar diatur ke ${m} menit (Mode Normal).`);
    if (connMode === 'usb') {
      sendSerialCmd(`i${m}\n`);
    } else if (connMode === 'cloud') {
      pushCloudConfig({
        timerMode: autoDht ? 'AUTO_DHT' : 'MANUAL',
        manualIntervalMin: m
      });
    }
  };

  const handleToggleMute = () => {
    const next = !buzzerMuted;
    setBuzzerMuted(next);
    addLog('KONFIG', next ? 'Buzzer diheningkan (getar tetap aktif).' : 'Suara buzzer diaktifkan.');
    if (connMode === 'usb') {
      sendSerialCmd('q\n');
    } else if (connMode === 'cloud') {
      pushCloudConfig({ muted: next });
    }
  };

  const handleSaveGoal = (val) => {
    const g = Math.round(Number(val));
    if (isNaN(g) || g < 500 || g > 6000) return;
    setDailyGoal(g);
    localStorage.setItem('shc_daily_goal', String(g));
    addLog('KONFIG', `Target hidrasi harian disimpan: ${g} ml.`);
  };

  const handleResetDaily = () => {
    const didReset = resetDailyStatsGuarded({
      connMode,
      fsm,
      onSaveHistory: () => syncHistoryNow(),
      onSendSerialReset: (cmd) => sendSerialCmd(cmd)
    });
    if (!didReset) return;
    setSessionMl(0);
    setDrinkCount(0);
    setRefillCount(0);
    setCheatCount(0);
    addLog('AKSI', 'Statistik sesi di-reset setelah menyimpan riwayat hari ini.');
  };

  const handleConfirmStartSession = async (chosenMode) => {
    setSessionBusy(true);
    try {
      syncHistoryNow();
      const nextDemo = chosenMode === 'DEMO';
      const nextAuto = chosenMode === 'DEMO' ? autoDht : chosenMode === 'AUTO_DHT';
      setDemo(nextDemo);
      if (chosenMode !== 'DEMO') setAutoDht(nextAuto);

      if (connMode === 'cloud') {
        const base = getCleanFbUrl();
        await pushCloudConfig({ timerMode: chosenMode });
        await shcSetSession(base, shcUid(), true);
      } else if (connMode === 'usb') {
        sendSerialCmd('x\n');
      } else {
        fsm.toIdle(simClockRef.current);
      }
      setStandby(false);
      setSessionModalOpen(false);
      addLog('SESI', `Sesi dimulai dengan mode ${chosenMode}.`);
    } finally {
      setSessionBusy(false);
    }
  };

  const handleEndSession = async () => {
    setSessionBusy(true);
    try {
      syncHistoryNow();
      if (connMode === 'cloud') {
        const base = getCleanFbUrl();
        await shcSetSession(base, shcUid(), false);
      } else if (connMode === 'usb') {
        sendSerialCmd('z\n');
      } else {
        fsm.toIdle(simClockRef.current);
      }
      setStandby(true);
      setStateString('IDLE');
      setRemSec(null);
      addLog('SESI', 'Sesi diakhiri; tatakan masuk ke mode tidur (standby).');
    } finally {
      setSessionBusy(false);
    }
  };

  // Tactile Simulator Cup Actions
  const handleSimLift = () => {
    if (connMode !== 'sim') return;
    if (weight >= CFG.CUP_ON) lastPlacedWeightRef.current = weight;
    setWeight(0);
  };

  const handleSimPlace = () => {
    if (connMode !== 'sim') return;
    setWeight(lastPlacedWeightRef.current >= CFG.CUP_ON ? lastPlacedWeightRef.current : emptyCup + 220);
  };

  const handleSimSip = () => {
    if (connMode !== 'sim') return;
    const baseW = weight >= CFG.CUP_ON ? weight : lastPlacedWeightRef.current;
    const nextW = Math.max(emptyCup, baseW - 30);
    lastPlacedWeightRef.current = nextW;
    setWeight(nextW);
  };

  const handleSimPour = () => {
    if (connMode !== 'sim') return;
    const baseW = weight >= CFG.CUP_ON ? weight : Math.max(emptyCup, lastPlacedWeightRef.current);
    const nextW = Math.min(550, baseW + 50);
    lastPlacedWeightRef.current = nextW;
    setWeight(nextW);
  };

  const handleSimEmpty = () => {
    if (connMode !== 'sim') return;
    const nextW = emptyCup + 5;
    lastPlacedWeightRef.current = nextW;
    setWeight(nextW);
  };

  // Automated 8 Verification Scenarios (deterministic step runner)
  const runScenario = (id) => {
    if (connMode !== 'sim') return;
    if (scenarioTimerRef.current) {
      clearTimeout(scenarioTimerRef.current);
      scenarioTimerRef.current = null;
    }
    setStandby(false);
    setActiveScenario(id);

    const step = (delayMs, fn) => {
      scenarioTimerRef.current = setTimeout(fn, delayMs);
    };

    const settleInTiming = (wTarget) => {
      let t = simClockRef.current;
      fsm.toIdle(t);
      t += 100;
      fsm.update(wTarget, t);
      for (let i = 1; i <= 16; i++) {
        t += 100;
        fsm.update(wTarget, t);
      }
      simClockRef.current = t;
      lastPlacedWeightRef.current = wTarget;
      setWeight(wTarget);
    };

    if (id === 1) {
      setDemo(true);
      fsm.toIdle(simClockRef.current);
      setWeight(350);
      lastPlacedWeightRef.current = 350;
      setScenarioStepText('Skenario 1: Gelas 350 g diletakkan, menunggu stabil 1,5 dtk...');
      step(1700, () => {
        setScenarioStepText('Skenario 1 selesai: Beban stabil -> TIMING.');
        setActiveScenario(null);
      });
    } else if (id === 2) {
      setDemo(true);
      settleInTiming(350);
      setScenarioStepText('Skenario 2: Memajukan waktu 15 detik hingga target habis...');
      step(400, () => {
        simClockRef.current += 15500;
        fsm.update(350, simClockRef.current);
        setStateString(fsm.stateString);
        setScenarioStepText('Skenario 2 selesai: Timer habis -> ALERT_DRINK.');
        setActiveScenario(null);
      });
    } else if (id === 3) {
      // Tegukan kecil (< 20 g): wajib angkat (0 g -> LIFTED) lalu taruh kembali (-10 g -> CHEAT)
      setDemo(true);
      settleInTiming(350);
      simClockRef.current += 15500;
      fsm.update(350, simClockRef.current);
      setWeight(0);
      simClockRef.current += 500;
      fsm.update(0, simClockRef.current);
      setStateString(fsm.stateString);
      setScenarioStepText('Skenario 3: Gelas diangkat, lalu ditaruh kembali hanya berkurang 10 g...');
      step(600, () => {
        setWeight(340);
        lastPlacedWeightRef.current = 340;
        let t = simClockRef.current;
        fsm.update(340, t);
        for (let i = 1; i <= 16; i++) {
          t += 100;
          fsm.update(340, t);
        }
        simClockRef.current = t;
        setStateString(fsm.stateString);
        setCheatCount(fsm.cheatCount);
        setScenarioStepText('Skenario 3 selesai: Tegukan < 20 ml terdeteksi -> CHEAT.');
        setActiveScenario(null);
      });
    } else if (id === 4) {
      setDemo(true);
      settleInTiming(350);
      simClockRef.current += 15500;
      fsm.update(350, simClockRef.current);
      setWeight(0);
      simClockRef.current += 1000;
      fsm.update(0, simClockRef.current);
      setScenarioStepText('Skenario 4: Gelas diangkat dan diminum 150 ml...');
      step(600, () => {
        setWeight(200);
        lastPlacedWeightRef.current = 200;
        let t = simClockRef.current;
        fsm.update(200, t);
        for (let i = 1; i <= 16; i++) {
          t += 100;
          fsm.update(200, t);
        }
        simClockRef.current = t;
        setStateString(fsm.stateString);
        setSessionMl(fsm.totalDrank);
        setDrinkCount(fsm.drinkCount);
        setScenarioStepText('Skenario 4 selesai: Minum +150 ml tercatat -> TIMING.');
        setActiveScenario(null);
      });
    } else if (id === 5) {
      setDemo(true);
      settleInTiming(350);
      setScenarioStepText('Skenario 5: Minum lewat sedotan (-30 g) tanpa mengangkat gelas...');
      step(500, () => {
        setWeight(320);
        lastPlacedWeightRef.current = 320;
        let t = simClockRef.current;
        fsm.update(320, t);
        for (let i = 1; i <= 16; i++) {
          t += 100;
          fsm.update(320, t);
        }
        simClockRef.current = t;
        setStateString(fsm.stateString);
        setSessionMl(fsm.totalDrank);
        setDrinkCount(fsm.drinkCount);
        setScenarioStepText('Skenario 5 selesai: Sedotan 30 ml tercatat tanpa angkat.');
        setActiveScenario(null);
      });
    } else if (id === 6) {
      setDemo(true);
      settleInTiming(300);
      const emptyW = emptyCup + 5;
      setWeight(0);
      simClockRef.current += 500;
      fsm.update(0, simClockRef.current);
      let t = simClockRef.current;
      fsm.update(emptyW, t);
      for (let i = 1; i <= 16; i++) {
        t += 100;
        fsm.update(emptyW, t);
      }
      simClockRef.current = t;
      setWeight(emptyW);
      setStateString(fsm.stateString);
      setScenarioStepText('Skenario 6: Gelas kosong (REFILL), menuang air +240 ml...');
      step(900, () => {
        const fullW = emptyW + 240;
        setWeight(fullW);
        lastPlacedWeightRef.current = fullW;
        let t2 = simClockRef.current;
        fsm.update(fullW, t2);
        for (let i = 1; i <= 16; i++) {
          t2 += 100;
          fsm.update(fullW, t2);
        }
        simClockRef.current = t2;
        setStateString(fsm.stateString);
        setRefillCount(fsm.refillCount);
        setScenarioStepText('Skenario 6 selesai: Isi ulang tercatat -> TIMING.');
        setActiveScenario(null);
      });
    } else if (id === 7) {
      setDemo(true);
      settleInTiming(350);
      setWeight(0);
      simClockRef.current += 200;
      fsm.update(0, simClockRef.current);
      setScenarioStepText('Skenario 7: Gelas diangkat > 10 detik...');
      step(500, () => {
        simClockRef.current += 11000;
        fsm.update(0, simClockRef.current);
        setStateString(fsm.stateString);
        setScenarioStepText('Skenario 7 selesai: Gelas lupa ditaruh -> REFILL (ALERT_MISSING_CUP).');
        setActiveScenario(null);
      });
    } else if (id === 8) {
      setDemo(false);
      setAutoDht(true);
      setBaseMin(30);
      setTemp(33.0);
      setHum(35);
      const effMs = computeEffectiveIntervalMs({
        demo: false,
        autoDht: true,
        baseIntervalMin: 30,
        tempC: 33.0,
        humidityPct: 35
      });
      fsm.setInterval_(effMs);
      settleInTiming(350);
      setTargetSec(Math.round(effMs / 1000));
      setScenarioStepText(
        `Skenario 8 selesai: Suhu 33 °C / RH 35% mempercepat interval 30 mnt menjadi ${(effMs / 60000).toFixed(1)} mnt.`
      );
      setActiveScenario(null);
    }
  };

  const handleExportCsv = () => {
    const header = 'Waktu,Kategori,Pesan\n';
    const body = logs
      .map((l) => `"${l.time}","${l.tag}","${String(l.msg).replace(/"/g, '""')}"`)
      .join('\n');
    const blob = new Blob([header + body], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `shc-log-${defaultTodayKey()}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const todayKeyStr = defaultTodayKey();
  const todayStats = todayDelta(
    Math.round(sessionMl),
    drinkCount,
    refillCount,
    cheatCount
  );
  const goalCurrentMl =
    connMode === 'cloud'
      ? Math.max(todayStats.total_ml, Number(dailyHistory[todayKeyStr]?.total_ml || 0))
      : Math.max(Math.round(sessionMl), todayStats.total_ml);

  const effectiveIntervalMs = computeEffectiveIntervalMs({
    demo,
    autoDht,
    baseIntervalMin: baseMin,
    tempC: temp,
    humidityPct: hum
  });
  const effectiveMin = effectiveIntervalMs / 60000;
  const targetMntStr = demo
    ? '15 detik (Demo)'
    : `${(targetSec / 60).toFixed(targetSec % 60 === 0 ? 0 : 1)} menit`;

  const currentTimerMode = demo ? 'DEMO' : autoDht ? 'AUTO_DHT' : 'MANUAL';

  return (
    <div className="min-h-screen bg-porcelain text-slate-900 flex flex-col">
      <Header
        connMode={connMode}
        setConnMode={handleSelectConnMode}
        usbConnected={usbConnected}
        cloudConnected={cloudConnected}
        standby={standby}
        userEmail={userEmail}
        onOpenAuth={() => setAuthModalOpen(true)}
      />

      <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 py-4 space-y-4">
        {/* ROW 1: Above-the-Fold Primary Grid (Hero Stage Col 1-5 + Ring Gauges & Env/Session Col 6-12) */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-4 items-stretch">
          <div className="lg:col-span-5">
            <VisualTumblerCoaster
              stateString={stateString}
              weight={weight}
              isStable={isStable}
              standby={standby}
              cupMl={cupMl}
              cupMax={500}
              emptyCup={emptyCup}
              connMode={connMode}
              onLift={handleSimLift}
              onPlace={handleSimPlace}
              onSip={handleSimSip}
              onPour={handleSimPour}
              onEmpty={handleSimEmpty}
            />
          </div>

          <div className="lg:col-span-7 flex flex-col justify-between gap-4">
            <RingGaugeTrio
              goalCur={goalCurrentMl}
              goalMax={dailyGoal}
              cupMl={cupMl}
              cupMax={500}
              weight={weight}
              remSec={remSec}
              targetSec={targetSec}
              stateString={stateString}
              standby={standby}
              targetMntStr={targetMntStr}
            />

            <EnvironmentSessionBar
              temp={temp}
              hum={hum}
              autoDht={autoDht}
              demo={demo}
              baseMin={baseMin}
              effectiveMin={effectiveMin}
              sessionMl={sessionMl}
              drinkCount={drinkCount}
              refillCount={refillCount}
              cheatCount={cheatCount}
              standby={standby}
              onOpenStartSession={() => setSessionModalOpen(true)}
              onEndSession={handleEndSession}
              sessionBusy={sessionBusy}
            />
          </div>
        </div>

        {/* ROW 2: Controls (Col 1-4) & History/Activity Tabs (Col 5-12) */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-4 items-start">
          <div className="lg:col-span-4">
            <QuickControls
              connMode={connMode}
              emptyCup={emptyCup}
              onCalibrateCup={handleCalibrateCup}
              onTare={handleTare}
              autoDht={autoDht}
              demo={demo}
              onSelectTimerMode={handleSelectTimerMode}
              buzzerMuted={buzzerMuted}
              onToggleMute={handleToggleMute}
              baseMin={baseMin}
              onSetInterval={handleSetInterval}
              dailyGoal={dailyGoal}
              onSaveGoal={handleSaveGoal}
              onResetDaily={handleResetDaily}
              timerHint={timerHint}
            />
          </div>

          <div className="lg:col-span-8">
            <HistoryActivityPanel
              dailyHistory={dailyHistory}
              todayDateKey={todayKeyStr}
              todayMl={goalCurrentMl}
              todayDrinks={drinkCount}
              dailyGoal={dailyGoal}
              logs={logs}
              onClearLogs={() => setLogs([])}
              onExportCsv={handleExportCsv}
              weightHistory={weightHistory}
              emptyCup={emptyCup}
            />
          </div>
        </div>

        {/* ROW 3: Lab Simulator Panel (ONLY rendered in Simulator mode) */}
        {connMode === 'sim' && (
          <LabSimulatorPanel
            weight={weight}
            onWeightChange={(w) => {
              setWeight(w);
              if (w >= CFG.CUP_ON) lastPlacedWeightRef.current = w;
            }}
            temp={temp}
            onTempChange={setTemp}
            hum={hum}
            onHumChange={setHum}
            warp={warp}
            onWarpChange={setWarp}
            simClockSec={simClockSec}
            activeScenario={activeScenario}
            scenarioStepText={scenarioStepText}
            onRunScenario={runScenario}
          />
        )}
      </main>

      <LoginModal
        isOpen={authModalOpen}
        onClose={() => setAuthModalOpen(false)}
        onAuthChanged={() => {
          setUserEmail(localStorage.getItem('shc_auth_email') || '');
          if (connMode === 'cloud') {
            startCloudStreams();
          }
        }}
      />

      <SessionModeModal
        isOpen={sessionModalOpen}
        onClose={() => setSessionModalOpen(false)}
        onConfirmStart={handleConfirmStartSession}
        currentMode={currentTimerMode}
        busy={sessionBusy}
      />
    </div>
  );
}
