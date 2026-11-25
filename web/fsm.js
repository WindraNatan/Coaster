'use strict';
// Mirror 1:1 dengan SmartHydrationCoaster/fsm.h dan test_simulation.py.

const CFG = {
  CUP_ON:35.0, CUP_OFF:25.0, DEFAULT_EMPTY:130.0, MAX_EMPTY:300.0,
  EMPTY_TOL:15.0, MIN_DRINK:20.0, REFILL:30.0,
  STAB_BAND:3.0, STAB_MS:1500,
  // Jendela konfirmasi isi ulang di tatakan untuk menolak pola tekan-lepas.
  CONFIRM_MS:5000,
  DEMO_INTERVAL:15000,
  DEMO_MAX_LIFT:10000, MAX_LIFT:180000,
  TEMP_COLD:18.0, TEMP_NORM:26.0, TEMP_HOT:34.0,
  K_COLD:1.20, K_NORM:1.00, K_HOT:0.50,
  HUM_DRY:30.0, HUM_NORM:50.0,
  K_DRY:0.85, K_HUM_NORM:1.00, FLOOR:5000
};

function computeAdaptiveIntervalMs(baseMs, tempC, hum){
  if (!isFinite(tempC) || !isFinite(hum)) return baseMs;
  let kt;
  if (tempC <= CFG.TEMP_COLD) kt = CFG.K_COLD;
  else if (tempC <= CFG.TEMP_NORM) {
    kt = CFG.K_COLD - (CFG.K_COLD - CFG.K_NORM) * ((tempC - CFG.TEMP_COLD) / (CFG.TEMP_NORM - CFG.TEMP_COLD));
  } else if (tempC < CFG.TEMP_HOT) {
    kt = CFG.K_NORM - (CFG.K_NORM - CFG.K_HOT) * ((tempC - CFG.TEMP_NORM) / (CFG.TEMP_HOT - CFG.TEMP_NORM));
  } else kt = CFG.K_HOT;

  let kh;
  if (hum <= CFG.HUM_DRY) kh = CFG.K_DRY;
  else if (hum < CFG.HUM_NORM) {
    kh = CFG.K_DRY + (CFG.K_HUM_NORM - CFG.K_DRY) * ((hum - CFG.HUM_DRY) / (CFG.HUM_NORM - CFG.HUM_DRY));
  } else kh = CFG.K_HUM_NORM;

  return Math.max(CFG.FLOOR, Math.round(baseMs * kt * kh));
}

class CoasterFSM {
  constructor(emptyCup = CFG.DEFAULT_EMPTY, interval = CFG.DEMO_INTERVAL){
    this.state = 'IDLE';
    this.baseline = 0; this.emptyCup = emptyCup;
    this.timerStart = 0; this.liftStart = 0;
    this.interval = interval; this.cycleTarget = interval; this.maxLift = CFG.DEMO_MAX_LIFT;
    this.stableCand = 0; this.stableStart = 0;
    this.totalDrank = 0; this.drinkCount = 0;
    this.cheatCount = 0; this.refillCount = 0;
    this.missing = false;
    this.refillPending = false;
    this.preRefillBaseline = 0;
    this.lastRefill = 0;
    this.calibrationAlign = false;
    this.preRefillState = 'IDLE';
    this.preRefillTimerStart = 0; this.preRefillCycleTarget = interval;
  }
  get emptyLimit(){ return this.emptyCup + CFG.EMPTY_TOL; }
  get stateString(){
    return this.state === 'ALERT_REFILL'
      ? (this.missing ? 'ALERT_MISSING_CUP' : 'ALERT_EMPTY_CUP') : this.state;
  }
  setState(next, w, now){ this.state = next; this.stableCand = w; this.stableStart = now; }
  isStable(w, now){
    if (w - this.stableCand > CFG.STAB_BAND || this.stableCand - w > CFG.STAB_BAND){
      this.stableCand = w; this.stableStart = now; return false;
    }
    return (now - this.stableStart) >= CFG.STAB_MS;
  }
  setInterval_(ms){ this.interval = ms; }
  // Kunci target per siklus agar perubahan suhu tidak memicu alarm mendadak.
  startCycle(now){ this.timerStart = now; this.cycleTarget = this.interval; }
  // Reset siklus untuk mode istirahat tanpa menghapus statistik harian.
  toIdle(now){
    this.state = 'IDLE';
    this.missing = false;
    this.refillPending = false;
    this.calibrationAlign = false;
    this.stableCand = 0; this.stableStart = now;
    this.timerStart = now; this.liftStart = now;
    this.cycleTarget = this.interval;
  }
  setMaxLift(ms){ this.maxLift = ms; }
  setEmptyCup(g){
    if (g >= CFG.CUP_ON && g <= CFG.MAX_EMPTY){
      this.emptyCup = g; this.baseline = g;
      if (this.state !== 'IDLE'){
        this.missing = false;
        // Tandai agar update() menyelaraskan baseline tanpa menghitung refill.
        this.calibrationAlign = true;
        this.state = 'ALERT_REFILL';
      }
      return true;
    }
    return false;
  }
  resetStats(){ this.totalDrank = 0; this.drinkCount = 0; this.cheatCount = 0; this.refillCount = 0; }
  restoreStats(totalMl, drinks, refills, cheats){
    this.totalDrank = totalMl >= 0 ? totalMl : 0;
    this.drinkCount = drinks;
    this.refillCount = refills;
    this.cheatCount = cheats;
  }
  get alertActive(){
    return this.state === 'ALERT_DRINK' || this.state === 'ALERT_CHEAT'
        || this.state === 'ALERT_REFILL';
  }
  remaining(now){
    if (this.state !== 'TIMING') return null;
    return Math.max(0, this.cycleTarget - (now - this.timerStart));
  }
  targetIntervalMs(){ return this.state === 'TIMING' ? this.cycleTarget : this.interval; }
  waterMl(w){ return w <= this.emptyCup ? 0 : w - this.emptyCup; }

  // Batalkan refill langsung jika berat kembali ke baseline lama dalam CONFIRM_MS.
  // Heuristik tekan-lepas; penekanan lebih lama tetap lolos.
  refillReversed(w, now){
    if (!this.refillPending || now - this.lastRefill > CFG.CONFIRM_MS) return false;
    const d = w - this.preRefillBaseline;
    return d <= CFG.STAB_BAND && d >= -CFG.STAB_BAND;
  }
  registerRefill(oldBase, w, now){
    this.preRefillState = this.state;
    this.preRefillTimerStart = this.timerStart; this.preRefillCycleTarget = this.cycleTarget;
    this.baseline = w; this.startCycle(now); this.refillCount++;
    this.refillPending = true; this.preRefillBaseline = oldBase; this.lastRefill = now;
  }
  cancelPendingRefill(now){
    this.refillCount--; this.refillPending = false;
    this.baseline = this.preRefillBaseline;
    // Pulihkan state dan timer pra-tekanan agar tekan-lepas tidak menunda alarm.
    // LIFTED dan ALERT_REFILL dilewati agar tidak memicu evaluasi cheat atau kosong palsu.
    if (this.preRefillState === 'TIMING' || this.preRefillState === 'ALERT_DRINK' || this.preRefillState === 'ALERT_CHEAT'){
      this.state = this.preRefillState;
      this.timerStart = this.preRefillTimerStart; this.cycleTarget = this.preRefillCycleTarget;
    } else {
      this.startCycle(now);
    }
  }
  recordDrink(g, w, now){
    if (this.refillReversed(w, now)){ this.cancelPendingRefill(now); return false; }
    this.refillPending = false;
    this.totalDrank += g; this.drinkCount++;
    return true;
  }

  update(w, now){
    const el = this.emptyCup + CFG.EMPTY_TOL;
    switch (this.state){
      case 'IDLE':
        this.missing = false;
        if (w >= CFG.CUP_ON) this.setState('STABLE', w, now);
        break;
      case 'STABLE':
        if (w < CFG.CUP_OFF){ this.setState('IDLE', w, now); break; }
        if (this.isStable(w, now)){
          this.baseline = w;
          if (w <= el){ this.missing = false; this.setState('ALERT_REFILL', w, now); }
          else { this.startCycle(now); this.setState('TIMING', w, now); }
        }
        break;
      case 'TIMING':
        if (w < CFG.CUP_OFF){ this.liftStart = now; this.setState('LIFTED', w, now); break; }
        if (w - this.baseline >= CFG.REFILL){
          if (this.isStable(w, now)) this.registerRefill(this.baseline, w, now);
          break;
        }
        if (this.baseline - w >= CFG.MIN_DRINK){
          if (this.isStable(w, now)){
            if (this.recordDrink(this.baseline - w, w, now)){
              this.baseline = w;
              if (w <= el){ this.missing = false; this.setState('ALERT_REFILL', w, now); }
              else this.startCycle(now);
            }
          }
          break;
        }
        if (now - this.timerStart >= this.cycleTarget) this.setState('ALERT_DRINK', w, now);
        break;
      case 'LIFTED':
        if (w >= CFG.CUP_ON){
          if (this.isStable(w, now)) this.evalReturned(w, el, now);
        } else if (now - this.liftStart >= this.maxLift){
          this.missing = true; this.setState('ALERT_REFILL', w, now);
        }
        break;
      case 'ALERT_DRINK':
      case 'ALERT_CHEAT':
        if (w < CFG.CUP_OFF){ this.liftStart = now; this.setState('LIFTED', w, now); break; }
        if (w - this.baseline >= CFG.REFILL){
          if (this.isStable(w, now)){
            this.registerRefill(this.baseline, w, now);
            this.setState('TIMING', w, now);
          }
          break;
        }
        if (this.baseline - w >= CFG.MIN_DRINK){
          if (this.isStable(w, now)){
            if (this.recordDrink(this.baseline - w, w, now)){
              this.baseline = w;
              if (w <= el){ this.missing = false; this.setState('ALERT_REFILL', w, now); }
              else { this.startCycle(now); this.setState('TIMING', w, now); }
            }
          }
          break;
        }
        break;
      case 'ALERT_REFILL':
        if (this.missing){
          if (w >= CFG.CUP_ON && this.isStable(w, now)) this.evalReturned(w, el, now);
          break;
        }
        if (w < CFG.CUP_OFF){ this.liftStart = now; this.setState('LIFTED', w, now); break; }
        if (w <= el){
          // Hapus flag kalibrasi begitu gelas benar-benar kosong teramati.
          this.calibrationAlign = false;
          break;
        }
        if (this.calibrationAlign){
          // Selaraskan baseline ke isi gelas yang sudah ada sebelum kalibrasi.
          if (this.isStable(w, now)){
            this.calibrationAlign = false;
            if (w > el){ this.baseline = w; this.startCycle(now); this.setState('TIMING', w, now); }
          }
          break;
        }
        if (w > el && this.isStable(w, now)){
          this.registerRefill(this.baseline, w, now);
          this.setState('TIMING', w, now);
        }
        break;
    }
  }
  evalReturned(w, el, now){
    const dec = this.baseline - w, inc = w - this.baseline;
    this.missing = false;
    if (w <= el){
      if (dec >= CFG.MIN_DRINK) this.recordDrink(dec, w, now);
      this.baseline = w;
      this.setState('ALERT_REFILL', w, now); return;
    }
    if (inc >= CFG.REFILL){
      this.registerRefill(this.baseline, w, now);
      this.setState('TIMING', w, now); return;
    }
    if (dec >= CFG.MIN_DRINK){
      this.recordDrink(dec, w, now);
      this.baseline = w; this.startCycle(now);
      this.setState('TIMING', w, now); return;
    }
    this.cheatCount++; this.setState('ALERT_CHEAT', w, now);
  }
}

// Config menang atas telemetry karena telemetry adalah echo tertunda dari perangkat.
function mutedFrom(cfg, tlm){
  if (cfg && typeof cfg.muted === 'boolean') return cfg.muted;
  if (tlm && typeof tlm.muted === 'boolean') return tlm.muted;
  return null;
}

if (typeof module !== 'undefined' && module.exports){
  module.exports = { CFG, computeAdaptiveIntervalMs, CoasterFSM, mutedFrom };
}
