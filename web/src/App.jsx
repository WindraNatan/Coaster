import React, { useState, useEffect, useRef, useCallback } from 'react';
import CoasterFSM, { CFG, computeAdaptiveIntervalMs, mutedFrom } from './fsm';
import Header from './components/Header';
import RingGaugeTrio from './components/RingGaugeTrio';
import TremorKpiCards from './components/TremorKpiCards';
import VisualTumblerCoaster from './components/VisualTumblerCoaster';
import QuickControls from './components/QuickControls';
import FsmDemoTabs from './components/FsmDemoTabs';
import LoginModal from './components/LoginModal';
import {
  shcEnsureToken,
  shcAuthSuffix,
  shcCoasterUrl,
  shcUid,
  shcDeviceUid,
  getCleanFbUrl
} from './auth';

function todayKey() {
  const d = new Date();
  return (
    d.getFullYear() +
    '-' +
    String(d.getMonth() + 1).padStart(2, '0') +
    '-' +
    String(d.getDate()).padStart(2, '0')
  );
}

function loadStoredDailyHistory() {
  try {
    return JSON.parse(localStorage.getItem('shc_daily_history') || '{}');
  } catch (_) {
    return {};
  }
}

function getDayBaseline() {
  try {
    return JSON.parse(localStorage.getItem('shc_day_base') || 'null');
  } catch (_) {
    return null;
  }
}

function ensureBaseline(totMl, drink, refill, cheat) {
  const k = todayKey();
  const b = getDayBaseline();
  const turun = b && (totMl < b.total_ml || drink < b.drink_count);
  if (b && b.date === k && !turun) return b;
  const next = { date: k, total_ml: totMl, drink_count: drink, refill_count: refill, cheat_count: cheat };
  localStorage.setItem('shc_day_base', JSON.stringify(next));
  return next;
}

function calculateTodayDelta(totMl, drink, refill, cheat) {
  const b = ensureBaseline(totMl, drink, refill, cheat);
  return {
    total_ml: Math.max(0, totMl - b.total_ml),
    drink_count: Math.max(0, drink - b.drink_count),
    refill_count: Math.max(0, refill - b.refill_count),
    cheat_count: Math.max(0, cheat - b.cheat_count)
  };
}

export default function App() {
  // Modes & settings
  const [connMode, setConnMode] = useState('sim');
  const [weight, setWeightState] = useState(0);
  const [warp, setWarp] = useState(1);
  const [demo, setDemo] = useState(true);
  const [autoDht, setAutoDht] = useState(true);
  const [buzzerMuted, setBuzzerMuted] = useState(false);
  const [customBaseMin, setCustomBaseMin] = useState(
    +(localStorage.getItem('shc_base_min') || 30)
  );
  const [dailyGoalMl, setDailyGoalMl] = useState(
    +(localStorage.getItem('shc_goal_ml') || 2000)
  );
  const [roomT, setRoomT] = useState(27.0);
  const [roomHum, setRoomHum] = useState(60);

  // FSM instance & telemetry states
  const fsmRef = useRef(
    new CoasterFSM(+(localStorage.getItem('shc_empty_cup') || CFG.DEFAULT_EMPTY), CFG.DEMO_INTERVAL)
  );
  const simMsRef = useRef(0);
  const lastFullRef = useRef(380);
  const lastDailyJsonRef = useRef('');

  const [fsmState, setFsmState] = useState('IDLE');
  const [remSec, setRemSec] = useState(null);
  const [targetSec, setTargetSec] = useState(15);
  const [cupMl, setCupMl] = useState(0);
  const [todayDrank, setTodayDrank] = useState(0);
  const [drinkCount, setDrinkCount] = useState(0);
  const [cheatCount, setCheatCount] = useState(0);
  const [refillCount, setRefillCount] = useState(0);
  const [stableSamples, setStableSamples] = useState(0);
  const [isStable, setIsStable] = useState(false);
  const [isLifted, setIsLifted] = useState(false);

  // Serial & Cloud state
  const [usbConnected, setUsbConnected] = useState(false);
  const [cloudConnected, setCloudConnected] = useState(false);
  const [userEmail, setUserEmail] = useState(localStorage.getItem('shc_auth_email') || '');
  const [authModalOpen, setAuthModalOpen] = useState(false);
  const [timerHint, setTimerHint] = useState(null);

  // Logs & stream
  const [logs, setLogs] = useState([
    {
      time: new Date().toLocaleTimeString('id-ID'),
      msg: 'Sistem Smart Hydration Coaster siap. Mode awal: Simulator.',
      type: 'info'
    }
  ]);
  const [dailyHistory, setDailyHistory] = useState(loadStoredDailyHistory());
  const [telemetryStream, setTelemetryStream] = useState([]);

  // Hardware serial refs
  const serialPortRef = useRef(null);
  const serialReaderRef = useRef(null);
  const serialWriterRef = useRef(null);

  const addLog = useCallback((msg, type = 'info') => {
    const time = new Date().toLocaleTimeString('id-ID');
    setLogs((prev) => [...prev.slice(-99), { time, msg, type }]);
  }, []);

  const playChime = useCallback(() => {
    if (buzzerMuted) return;
    try {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (!AudioCtx) return;
      const ctx = new AudioCtx();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(587.33, ctx.currentTime); // D5
      osc.frequency.exponentialRampToValueAtTime(880, ctx.currentTime + 0.15); // A5
      gain.gain.setValueAtTime(0.12, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.35);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start();
      osc.stop(ctx.currentTime + 0.36);
    } catch (_) {}
  }, [buzzerMuted]);

  // Serial communication helper
  const sendSerialCmd = async (str) => {
    if (!serialWriterRef.current) return;
    try {
      const enc = new TextEncoder();
      await serialWriterRef.current.write(enc.encode(str));
    } catch (e) {
      addLog('Gagal mengirim perintah serial: ' + e.message, 'error');
    }
  };

  // Sync daily delta to localStorage
  const syncDailyStats = useCallback(() => {
    const f = fsmRef.current;
    const hist = loadStoredDailyHistory();
    const k = todayKey();
    const d = calculateTodayDelta(Math.round(f.totalDrank), f.drinkCount, f.refillCount, f.cheatCount);
    hist[k] = {
      total_ml: d.total_ml,
      drink_count: d.drink_count,
      refill_count: d.refill_count,
      cheat_count: d.cheat_count
    };
    const keys = Object.keys(hist).sort().reverse();
    if (keys.length > 30) keys.slice(30).forEach((old) => delete hist[old]);
    localStorage.setItem('shc_daily_history', JSON.stringify(hist));
    setDailyHistory(hist);
    setTodayDrank(d.total_ml);
  }, []);

  // Cloud push daily
  const pushDailyCloud = useCallback(async () => {
    if (connMode !== 'cloud') return;
    const base = getCleanFbUrl();
    const url = shcCoasterUrl(base);
    if (!url) return;
    try {
      if (!(await shcEnsureToken())) return;
      const f = fsmRef.current;
      const dd = calculateTodayDelta(Math.round(f.totalDrank), f.drinkCount, f.refillCount, f.cheatCount);
      const isi = JSON.stringify({
        total_ml: +dd.total_ml.toFixed(1),
        drink_count: dd.drink_count,
        refill_count: dd.refill_count,
        cheat_count: dd.cheat_count
      });
      const stamp = todayKey() + '|' + isi;
      if (stamp === lastDailyJsonRef.current) return;
      lastDailyJsonRef.current = stamp;
      await fetch(url + '/daily/' + todayKey() + '.json' + shcAuthSuffix(), {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: isi
      });
    } catch (_) {
      lastDailyJsonRef.current = '';
    }
  }, [connMode]);

  // Cloud push config
  const pushCloudConfig = useCallback(async () => {
    if (connMode !== 'cloud') return;
    const base = getCleanFbUrl();
    const url = shcCoasterUrl(base);
    if (!url) return;
    try {
      if (!(await shcEnsureToken())) return;
      const cfg = {
        demo,
        auto_dht: autoDht,
        base_interval_min: customBaseMin,
        muted: buzzerMuted,
        at: Date.now()
      };
      await fetch(url + '/config.json' + shcAuthSuffix(), {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(cfg)
      });
    } catch (_) {}
  }, [connMode, demo, autoDht, customBaseMin, buzzerMuted]);

  // Compute adaptive interval
  const currentBaseIntervalMs = useCallback(() => {
    if (demo) return CFG.DEMO_INTERVAL;
    return customBaseMin * 60000;
  }, [demo, customBaseMin]);

  const targetIntervalMs = useCallback(() => {
    const base = currentBaseIntervalMs();
    if (!autoDht) return base;
    return computeAdaptiveIntervalMs(base, roomT, roomHum);
  }, [currentBaseIntervalMs, autoDht, roomT, roomHum]);

  // Weight setting helper
  const setWeight = (w) => {
    setWeightState(w);
    if (w >= 300) lastFullRef.current = w;
  };

  // Main 100ms ticker for simulation and reactive UI
  useEffect(() => {
    const fsm = fsmRef.current;
    let prevSt = fsm.stateString;
    let prevDrink = fsm.drinkCount;
    let prevRefill = fsm.refillCount;
    let prevCheat = fsm.cheatCount;

    const timer = setInterval(() => {
      if (connMode === 'sim') {
        const deltaMs = 100 * warp;
        simMsRef.current += deltaMs;

        // Update target interval
        const effInt = targetIntervalMs();
        fsm.setInterval_(effInt);

        // Update FSM state machine
        fsm.update(weight, simMsRef.current);

        // Check transitions
        const currSt = fsm.stateString;
        if (currSt !== prevSt) {
          if (currSt === 'ALERT_DRINK') {
            addLog('Pengingat minum aktif! Saatnya minum air.', 'alert');
            playChime();
          } else if (currSt === 'ALERT_CHEAT') {
            addLog('Tegukan kecil terdeteksi (< 20 ml). Silakan minum lebih banyak.', 'alert');
            playChime();
          } else if (currSt === 'ALERT_EMPTY_CUP') {
            addLog('Gelas kosong! Silakan isi ulang air tumbler.', 'alert');
            playChime();
          } else if (currSt === 'ALERT_MISSING_CUP') {
            addLog('Gelas diangkat lebih dari 10 detik.', 'alert');
            playChime();
          } else if (currSt === 'STABLE') {
            addLog('Timbangan stabil, menyiapkan siklus minum.', 'info');
          } else if (currSt === 'TIMING') {
            addLog('Siklus minum aktif.', 'info');
          }
          prevSt = currSt;
        }

        if (fsm.drinkCount > prevDrink) {
          addLog(`Tegukan berhasil dicatat! (+${Math.round(fsm.totalDrank)} ml akumulatif)`, 'drink');
          prevDrink = fsm.drinkCount;
          syncDailyStats();
        }
        if (fsm.refillCount > prevRefill) {
          addLog('Isi ulang air terdeteksi di tatakan.', 'info');
          prevRefill = fsm.refillCount;
          syncDailyStats();
        }
        if (fsm.cheatCount > prevCheat) {
          prevCheat = fsm.cheatCount;
          syncDailyStats();
        }

        // Countdown calculation
        let sec = null;
        if (currSt === 'TIMING') {
          const rem = fsm.remaining(simMsRef.current);
          sec = rem != null ? Math.max(0, Math.ceil(rem / 1000)) : 0;
        } else if (currSt.startsWith('ALERT_')) {
          sec = 0;
        }
        setRemSec(sec);
        setTargetSec(Math.round(effInt / 1000));

        // Water level calculation
        const ml = fsm.waterMl(weight);
        setCupMl(ml);

        // Update state hooks
        setFsmState(currSt);
        setDrinkCount(fsm.drinkCount);
        setCheatCount(fsm.cheatCount);
        setRefillCount(fsm.refillCount);
        const elapsedStab = simMsRef.current - fsm.stableStart;
        const stableFlag = currSt === 'TIMING' || currSt === 'IDLE' || (currSt === 'STABLE' && elapsedStab >= 1500);
        setStableSamples(stableFlag ? 16 : Math.max(0, Math.min(15, Math.floor((elapsedStab / 1500) * 16))));
        setIsStable(Boolean(stableFlag));
        setIsLifted(currSt === 'LIFTED' || currSt === 'ALERT_MISSING_CUP' || weight < 25);

        // Stream telemetry point
        setTelemetryStream((prev) => [
          ...prev.slice(-29),
          { t: simMsRef.current, w: weight, ml: Math.max(0, ml) }
        ]);
      }
    }, 100);

    return () => clearInterval(timer);
  }, [connMode, weight, warp, targetIntervalMs, syncDailyStats, addLog, playChime]);

  // Web Serial connection handler
  const handleConnectUsb = async () => {
    if (!('serial' in navigator)) {
      alert('Web Serial API tidak didukung di browser ini. Gunakan Chrome atau Edge.');
      return;
    }
    try {
      const port = await navigator.serial.requestPort();
      await port.open({ baudRate: 115200 });
      serialPortRef.current = port;
      setUsbConnected(true);
      addLog('Terhubung ke ESP32 melalui Web Serial (115200 baud).', 'info');

      const textDecoder = new TextDecoderStream();
      port.readable.pipeTo(textDecoder.writable);
      const reader = textDecoder.readable.getReader();
      serialReaderRef.current = reader;

      const textEncoder = new TextEncoderStream();
      textEncoder.readable.pipeTo(port.writable);
      serialWriterRef.current = textEncoder.writable.getWriter();

      // Read loop
      let buf = '';
      (async () => {
        try {
          while (true) {
            const { value, done } = await reader.read();
            if (done) break;
            buf += value;
            let nl;
            while ((nl = buf.indexOf('\n')) >= 0) {
              const line = buf.slice(0, nl).trim();
              buf = buf.slice(nl + 1);
              if (line) handleSerialLine(line);
            }
          }
        } catch (_) {}
      })();
    } catch (err) {
      addLog('Gagal menghubungkan serial USB: ' + err.message, 'error');
    }
  };

  const handleSerialLine = (line) => {
    if (!line.startsWith('State:')) {
      return;
    }
    const mState = /State:\s*([A-Z_]+)/.exec(line);
    const mWeight = /Berat:\s*([-\d.]+)g/.exec(line);
    const mWater = /Air:\s*([-\d.]+)ml/.exec(line);
    const mTemp = /Suhu:\s*([-\d.]+)C/.exec(line);
    const mHum = /RH:\s*([-\d.]+)%/.exec(line);
    const mRem = /SisaWaktu:\s*(\d+)s/.exec(line);
    const mDrank = /Diminum:\s*([-\d.]+)ml/.exec(line);
    const mDrinkCnt = /Minum:\s*(\d+)x/.exec(line);
    const mCheatCnt = /Cheat:\s*(\d+)/.exec(line);
    const mRefillCnt = /Refill:\s*(\d+)x/.exec(line);
    const mTarget = /Target:\s*(\d+)s/.exec(line);

    if (mState) setFsmState(mState[1]);
    if (mWeight) setWeightState(parseFloat(mWeight[1]));
    if (mWater) setCupMl(parseFloat(mWater[1]));
    if (mTemp) setRoomT(parseFloat(mTemp[1]));
    if (mHum) setRoomHum(parseFloat(mHum[1]));
    if (mRem) setRemSec(parseInt(mRem[1], 10));
    if (mTarget) setTargetSec(parseInt(mTarget[1], 10));
    if (mDrinkCnt) setDrinkCount(parseInt(mDrinkCnt[1], 10));
    if (mCheatCnt) setCheatCount(parseInt(mCheatCnt[1], 10));
    if (mRefillCnt) setRefillCount(parseInt(mRefillCnt[1], 10));
  };

  // Firebase polling loop for cloud mode
  useEffect(() => {
    if (connMode !== 'cloud') {
      setCloudConnected(false);
      return;
    }
    const base = getCleanFbUrl();
    const url = shcCoasterUrl(base);
    if (!url) {
      setCloudConnected(false);
      return;
    }

    let active = true;
    const poll = async () => {
      try {
        if (!(await shcEnsureToken())) {
          if (active) setCloudConnected(false);
          return;
        }
        const res = await fetch(url + '/telemetry.json' + shcAuthSuffix());
        if (res.ok) {
          const t = await res.json();
          if (t && active) {
            setCloudConnected(true);
            if (t.state) setFsmState(t.state);
            if (typeof t.weight_g === 'number') setWeightState(t.weight_g);
            if (typeof t.water_ml === 'number') setCupMl(t.water_ml);
            if (typeof t.temperature_c === 'number') setRoomT(t.temperature_c);
            if (typeof t.humidity_pct === 'number') setRoomHum(t.humidity_pct);
            if (typeof t.remaining_sec === 'number') setRemSec(t.remaining_sec);
            if (typeof t.target_sec === 'number') setTargetSec(t.target_sec);
            if (typeof t.drink_count === 'number') setDrinkCount(t.drink_count);
            if (typeof t.cheat_count === 'number') setCheatCount(t.cheat_count);
            if (typeof t.refill_count === 'number') setRefillCount(t.refill_count);
          }
        }
      } catch (_) {
        if (active) setCloudConnected(false);
      }
    };

    poll();
    const interval = setInterval(poll, 1500);
    return () => {
      active = false;
      clearInterval(interval);
    };
  }, [connMode]);

  // Mode switcher handler
  const handleSetConnMode = (mode) => {
    setConnMode(mode);
    if (mode === 'usb' && !usbConnected) {
      handleConnectUsb();
    }
    addLog(`Mode koneksi berganti ke: ${mode.toUpperCase()}`, 'info');
  };

  // Quick Action Handlers
  const handleTare = () => {
    if (connMode === 'usb') sendSerialCmd('t');
    setWeight(0);
    addLog('Timbangan di-nolkan (Tare).', 'info');
  };

  const handleCalibrateCup = (val) => {
    if (fsmRef.current.setEmptyCup(val)) {
      localStorage.setItem('shc_empty_cup', String(val));
      if (connMode === 'usb') sendSerialCmd('c' + val + '\n');
      addLog(`Berat gelas kosong disimpan: ${val} g`, 'info');
    }
  };

  const handleToggleAuto = () => {
    const next = !autoDht;
    setAutoDht(next);
    if (connMode === 'usb') sendSerialCmd('m');
    pushCloudConfig();
    addLog(`Mode timer: ${next ? 'Otomatis (DHT11)' : 'Manual'}`, 'info');
  };

  const handleToggleDemo = () => {
    const next = !demo;
    setDemo(next);
    if (connMode === 'usb') sendSerialCmd('d');
    pushCloudConfig();
    addLog(`Mode demo 15 detik: ${next ? 'AKTIF' : 'NONAKTIF'}`, 'info');
  };

  const handleToggleMute = () => {
    const next = !buzzerMuted;
    setBuzzerMuted(next);
    if (connMode === 'usb') sendSerialCmd('q');
    pushCloudConfig();
    addLog(`Mode suara buzzer: ${next ? 'HENING' : 'AKTIF'}`, 'info');
  };

  const handleSetInterval = (val) => {
    setCustomBaseMin(val);
    localStorage.setItem('shc_base_min', String(val));
    setDemo(false);
    if (connMode === 'usb') sendSerialCmd('i' + val + '\n');
    pushCloudConfig();
    addLog(`Interval dasar diatur ke ${val} menit`, 'info');
  };

  const handleSaveGoal = (val) => {
    setDailyGoalMl(val);
    localStorage.setItem('shc_goal_ml', String(val));
    addLog(`Target hidrasi harian disimpan: ${val} ml`, 'info');
  };

  const handleResetDaily = () => {
    if (connMode === 'cloud') {
      addLog('Reset harian ditolak: mode cloud aktif.', 'error');
      return;
    }
    syncDailyStats();
    fsmRef.current.resetStats();
    setDrinkCount(0);
    setCheatCount(0);
    setRefillCount(0);
    setTodayDrank(0);
    addLog('Statistik harian berhasil di-reset untuk hari baru.', 'info');
  };

  // Tactile cup actions
  const handleLift = () => {
    setWeight(0);
    addLog('Aksi fisik: Gelas diangkat dari tatakan.', 'info');
  };

  const handlePlace = () => {
    setWeight(lastFullRef.current);
    addLog('Aksi fisik: Gelas diletakkan kembali di tatakan.', 'info');
  };

  const handleSip = () => {
    const next = Math.max(0, weight - 30);
    setWeight(next);
    addLog('Aksi fisik: Sedot air -30 g via sedotan.', 'info');
  };

  const handlePour = () => {
    const next = Math.min(500, weight + 50);
    setWeight(next);
    addLog('Aksi fisik: Tuang air +50 g ke dalam tumbler.', 'info');
  };

  const handleEmpty = () => {
    const next = fsmRef.current.emptyCup + 5;
    setWeight(next);
    addLog('Aksi fisik: Gelas dikosongkan (sisa 5g air).', 'info');
  };

  // 8 Demo Scenarios
  const handleRunScenario = (idx) => {
    const fsm = fsmRef.current;
    if (idx === 0) {
      // 1. Taruh gelas terisi
      setWeight(380);
      addLog('Skenario 1: Taruh gelas terisi 380 g -> Stabil 1.5s menuju TIMING.', 'info');
    } else if (idx === 1) {
      // 2. Timer habis -> ALERT_DRINK
      if (fsm.stateString === 'TIMING') {
        const remaining = fsm.remaining(simMsRef.current) ?? 15000;
        simMsRef.current += remaining + 100;
        addLog('Skenario 2: Waktu dipercepat -> ALERT_DRINK aktif.', 'alert');
      } else {
        setWeight(380);
        setTimeout(() => {
          simMsRef.current += 16000;
        }, 1600);
      }
    } else if (idx === 2) {
      // 3. Tegukan kecil (< 20 ml)
      const next = weight - 10;
      setWeight(next);
      addLog('Skenario 3: Sentuh tatakan / tegukan kecil -10 g -> ALERT_CHEAT.', 'alert');
    } else if (idx === 3) {
      // 4. Minum 120 ml
      setWeight(0);
      addLog('Skenario 4: Angkat gelas untuk minum 120 ml...', 'info');
      setTimeout(() => {
        const next = Math.max(fsm.emptyCup, lastFullRef.current - 120);
        setWeight(next);
        addLog(`Skenario 4: Gelas diletakkan kembali dengan beban ${next} g.`, 'drink');
      }, 1200);
    } else if (idx === 4) {
      // 5. Gelas kosong
      setWeight(fsm.emptyCup + 5);
      addLog('Skenario 5: Air hampir habis -> ALERT_EMPTY_CUP.', 'alert');
    } else if (idx === 5) {
      // 6. Isi ulang air
      const next = Math.min(480, weight + 240);
      setWeight(next);
      addLog(`Skenario 6: Isi ulang air +240 g (total ${next} g).`, 'info');
    } else if (idx === 6) {
      // 7. Gelas diangkat > 10 dtk
      setWeight(0);
      addLog('Skenario 7: Gelas diangkat > 10 dtk...', 'info');
      setTimeout(() => {
        simMsRef.current += 11000;
        addLog('Skenario 7: Waktu lift terlewati -> ALERT_MISSING_CUP.', 'alert');
      }, 1000);
    } else if (idx === 7) {
      // 8. Sedotan di tatakan
      const next = Math.max(fsm.emptyCup, weight - 30);
      setWeight(next);
      addLog('Skenario 8: Minum via sedotan -30 g tanpa mengangkat gelas.', 'drink');
    }
  };

  // CSV Export handler
  const handleExportCsv = () => {
    let csv = 'Timestamp,Tipe,Pesan\r\n';
    logs.forEach((lg) => {
      csv += `"${lg.time}","${lg.type}","${lg.msg.replace(/"/g, '""')}"\r\n`;
    });
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `shc_sensor_log_${todayKey()}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  // Format target display string
  const targetMntDisplay = demo ? '15 detik' : `${customBaseMin} menit`;

  // Sim clock display
  const clockSec = Math.floor(simMsRef.current / 1000);
  const clockStr = `${String(Math.floor(clockSec / 60)).padStart(2, '0')}:${String(
    clockSec % 60
  ).padStart(2, '0')}`;

  return (
    <div className="min-h-screen bg-slate-50 text-slate-800 antialiased flex flex-col selection:bg-water-200 selection:text-water-900">
      {/* Top Header */}
      <Header
        connMode={connMode}
        setConnMode={handleSetConnMode}
        usbConnected={usbConnected}
        cloudConnected={cloudConnected}
        userEmail={userEmail}
        onOpenAuth={() => setAuthModalOpen(true)}
        onTare={handleTare}
      />

      {/* Main Content Dashboard */}
      <main className="flex-1 max-w-7xl w-full mx-auto p-4 sm:p-6 space-y-6">
        {/* Row 1: Ring Gauge Trio */}
        <RingGaugeTrio
          goalCur={todayDrank}
          goalMax={dailyGoalMl}
          cupMl={cupMl}
          cupMax={500}
          remSec={remSec}
          targetSec={targetSec}
          stateString={fsmState}
          targetMntStr={targetMntDisplay}
        />

        {/* Row 2: Tremor KPI Cards */}
        <TremorKpiCards
          weight={weight}
          stableSamples={stableSamples}
          isStable={isStable}
          isLifted={isLifted}
          temp={roomT}
          humidity={roomHum}
          drinkCount={drinkCount}
          cheatCount={cheatCount}
          refillCount={refillCount}
          totalDrank={todayDrank}
        />

        {/* Row 3: Bento 8:4 Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
          {/* Left Column (8 cols): Visualizer Stage */}
          <div className="lg:col-span-8 flex flex-col">
            <VisualTumblerCoaster
              stateString={fsmState}
              weight={weight}
              cupMl={cupMl}
              cupMax={500}
              onLift={handleLift}
              onPlace={handlePlace}
              onSip={handleSip}
              onPour={handlePour}
              onEmpty={handleEmpty}
            />
          </div>

          {/* Right Column (4 cols): Quick Controls */}
          <div className="lg:col-span-4 flex flex-col">
            <QuickControls
              emptyCup={fsmRef.current.emptyCup}
              onCalibrateCup={handleCalibrateCup}
              onTare={handleTare}
              autoDht={autoDht}
              onToggleAuto={handleToggleAuto}
              demo={demo}
              onToggleDemo={handleToggleDemo}
              buzzerMuted={buzzerMuted}
              onToggleMute={handleToggleMute}
              baseMin={customBaseMin}
              onSetInterval={handleSetInterval}
              dailyGoal={dailyGoalMl}
              onSaveGoal={handleSaveGoal}
              onResetDaily={handleResetDaily}
              timerHint={timerHint}
            />
          </div>
        </div>

        {/* Row 4: FSM Demo, Logs & Telemetry Tabs */}
        <FsmDemoTabs
          weight={weight}
          onWeightChange={setWeight}
          warp={warp}
          onWarpChange={setWarp}
          simClock={clockStr}
          onRunScenario={handleRunScenario}
          logs={logs}
          onExportCsv={handleExportCsv}
          dailyHistory={dailyHistory}
          dailyGoal={dailyGoalMl}
          temp={roomT}
          onTempChange={setRoomT}
          humidity={roomHum}
          onHumidityChange={setRoomHum}
          telemetryStream={telemetryStream}
        />
      </main>

      {/* Login & Cloud Linking Modal */}
      <LoginModal
        isOpen={authModalOpen}
        onClose={() => setAuthModalOpen(false)}
        onAuthChanged={() => {
          setUserEmail(localStorage.getItem('shc_auth_email') || '');
          pushDailyCloud();
        }}
      />
    </div>
  );
}
