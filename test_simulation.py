"""Port Python 1:1 dari SmartHydrationCoaster/fsm.h beserta uji 24 skenario FSM."""

CUP_ON_THRESHOLD = 35.0
CUP_OFF_THRESHOLD = 25.0
DEFAULT_EMPTY_CUP_G = 130.0
MAX_EMPTY_CUP_G = 300.0
EMPTY_CUP_TOLERANCE = 15.0
MIN_DRINK_DELTA = 20.0
REFILL_DELTA = 30.0
STABILITY_BAND_G = 3.0
STABILITY_TIME_MS = 1500
# Jendela konfirmasi isi ulang di tatakan untuk menolak pola tekan-lepas.
REFILL_CONFIRM_MS = 5000


TEMP_COLD_C = 18.0
TEMP_NORM_C = 26.0
TEMP_HOT_C = 34.0
K_TEMP_COLD = 1.20
K_TEMP_NORMAL = 1.00
K_TEMP_HOT = 0.50
HUM_DRY_PCT = 30.0
HUM_NORM_PCT = 50.0
K_HUM_DRY = 0.85
K_HUM_NORMAL = 1.00
ADAPT_FLOOR_MS = 5000


def compute_adaptive_interval_ms(base_interval_ms: int, temp_c: float, humidity_pct: float) -> int:
    if temp_c != temp_c or humidity_pct != humidity_pct:
        return base_interval_ms
    if temp_c <= TEMP_COLD_C:
        k_temp = K_TEMP_COLD
    elif temp_c <= TEMP_NORM_C:
        k_temp = K_TEMP_COLD - (K_TEMP_COLD - K_TEMP_NORMAL) * ((temp_c - TEMP_COLD_C) / (TEMP_NORM_C - TEMP_COLD_C))
    elif temp_c < TEMP_HOT_C:
        k_temp = K_TEMP_NORMAL - (K_TEMP_NORMAL - K_TEMP_HOT) * ((temp_c - TEMP_NORM_C) / (TEMP_HOT_C - TEMP_NORM_C))
    else:
        k_temp = K_TEMP_HOT

    if humidity_pct <= HUM_DRY_PCT:
        k_hum = K_HUM_DRY
    elif humidity_pct < HUM_NORM_PCT:
        k_hum = K_HUM_DRY + (K_HUM_NORMAL - K_HUM_DRY) * ((humidity_pct - HUM_DRY_PCT) / (HUM_NORM_PCT - HUM_DRY_PCT))
    else:
        k_hum = K_HUM_NORMAL

    adapted = base_interval_ms * k_temp * k_hum
    if adapted < ADAPT_FLOOR_MS:
        adapted = float(ADAPT_FLOOR_MS)
    return int(adapted + 0.5)


class CoasterFSM:
    def __init__(self, empty_cup_weight=DEFAULT_EMPTY_CUP_G, target_interval_ms=15000):
        self.state = "IDLE"
        self.baseline_weight = 0.0
        self.empty_cup_weight = empty_cup_weight
        self.timer_start_ms = 0
        self.lift_start_ms = 0
        self.target_interval_ms = target_interval_ms
        self.cycle_target_ms = target_interval_ms
        self.max_lift_duration_ms = 10000
        self.stable_candidate_weight = 0.0
        self.stable_start_ms = 0
        self.total_consumed_ml = 0.0
        self.drink_count = 0
        self.cheat_count = 0
        self.refill_count = 0
        self.missing_cup_alert = False
        self.refill_pending = False
        self.pre_refill_baseline = 0.0
        self.last_refill_ms = 0
        self.calibration_align = False
        self.pre_refill_state = "IDLE"
        self.pre_refill_timer_start = 0
        self.pre_refill_cycle_target = target_interval_ms

    @property
    def state_string(self):
        if self.state == "ALERT_REFILL":
            return "ALERT_MISSING_CUP" if self.missing_cup_alert else "ALERT_EMPTY_CUP"
        return self.state

    @property
    def empty_limit(self):
        return self.empty_cup_weight + EMPTY_CUP_TOLERANCE

    def enter_state(self, next_state, w, now_ms):
        self.state = next_state
        self.stable_candidate_weight = w
        self.stable_start_ms = now_ms

    def set_interval(self, ms):
        self.target_interval_ms = ms

    def start_cycle(self, now_ms):
        # Kunci target per siklus agar perubahan suhu tidak memicu alarm mendadak.
        self.timer_start_ms = now_ms
        self.cycle_target_ms = self.target_interval_ms

    def to_idle(self, now_ms):
        # Reset siklus untuk mode istirahat tanpa menghapus statistik harian.
        self.state = "IDLE"
        self.missing_cup_alert = False
        self.refill_pending = False
        self.calibration_align = False
        self.stable_candidate_weight = 0.0
        self.stable_start_ms = now_ms
        self.timer_start_ms = now_ms
        self.lift_start_ms = now_ms
        self.cycle_target_ms = self.target_interval_ms

    def is_stable(self, w, now_ms):
        if (w - self.stable_candidate_weight > STABILITY_BAND_G or
                self.stable_candidate_weight - w > STABILITY_BAND_G):
            self.stable_candidate_weight = w
            self.stable_start_ms = now_ms
            return False
        return (now_ms - self.stable_start_ms) >= STABILITY_TIME_MS

    def set_empty_cup_weight(self, weight_g):
        if CUP_ON_THRESHOLD <= weight_g <= MAX_EMPTY_CUP_G:
            self.empty_cup_weight = weight_g
            self.baseline_weight = weight_g
            if self.state != "IDLE":
                self.missing_cup_alert = False
                # Tandai agar update() menyelaraskan baseline tanpa menghitung refill.
                self.calibration_align = True
                self.state = "ALERT_REFILL"
            return True
        return False

    def refill_reversed(self, w, now_ms):
        # Batalkan refill langsung jika berat kembali ke baseline lama dalam REFILL_CONFIRM_MS.
        # Heuristik tekan-lepas; penekanan lebih lama tetap lolos.
        if not self.refill_pending or now_ms - self.last_refill_ms > REFILL_CONFIRM_MS:
            return False
        d = w - self.pre_refill_baseline
        return -STABILITY_BAND_G <= d <= STABILITY_BAND_G

    def register_refill(self, old_baseline, w, now_ms):
        self.pre_refill_state = self.state
        self.pre_refill_timer_start = self.timer_start_ms
        self.pre_refill_cycle_target = self.cycle_target_ms
        self.baseline_weight = w
        self.start_cycle(now_ms)
        self.refill_count += 1
        self.refill_pending = True
        self.pre_refill_baseline = old_baseline
        self.last_refill_ms = now_ms

    def cancel_pending_refill(self, now_ms):
        self.refill_count -= 1
        self.refill_pending = False
        self.baseline_weight = self.pre_refill_baseline
        # Pulihkan state dan timer pra-tekanan agar tekan-lepas tidak menunda alarm.
        # LIFTED dan ALERT_REFILL dilewati agar tidak memicu evaluasi cheat atau kosong palsu.
        if self.pre_refill_state in ("TIMING", "ALERT_DRINK", "ALERT_CHEAT"):
            self.state = self.pre_refill_state
            self.timer_start_ms = self.pre_refill_timer_start
            self.cycle_target_ms = self.pre_refill_cycle_target
        else:
            self.start_cycle(now_ms)

    def record_drink(self, grams, w, now_ms):
        # Kembalikan False jika minum dibatalkan oleh pola tekan-lepas.
        if self.refill_reversed(w, now_ms):
            self.cancel_pending_refill(now_ms)
            return False
        self.refill_pending = False
        self.total_consumed_ml += grams
        self.drink_count += 1
        return True

    def restore_daily_stats(self, total_ml, drinks, refills, cheats):
        self.total_consumed_ml = total_ml if total_ml >= 0.0 else 0.0
        self.drink_count = drinks
        self.refill_count = refills
        self.cheat_count = cheats

    def evaluate_returned_cup(self, w, now_ms):
        decreased = self.baseline_weight - w
        increased = w - self.baseline_weight
        self.missing_cup_alert = False

        if w <= self.empty_limit:
            if decreased >= MIN_DRINK_DELTA:
                self.record_drink(decreased, w, now_ms)
            self.baseline_weight = w
            self.enter_state("ALERT_REFILL", w, now_ms)
            return

        if increased >= REFILL_DELTA:
            self.register_refill(self.baseline_weight, w, now_ms)
            self.enter_state("TIMING", w, now_ms)
            return

        if decreased >= MIN_DRINK_DELTA:
            self.record_drink(decreased, w, now_ms)
            self.baseline_weight = w
            self.start_cycle(now_ms)
            self.enter_state("TIMING", w, now_ms)
            return

        self.cheat_count += 1
        self.enter_state("ALERT_CHEAT", w, now_ms)

    def update(self, w, now_ms):
        el = self.empty_limit

        if self.state == "IDLE":
            self.missing_cup_alert = False
            if w >= CUP_ON_THRESHOLD:
                self.enter_state("STABLE", w, now_ms)

        elif self.state == "STABLE":
            if w < CUP_OFF_THRESHOLD:
                self.enter_state("IDLE", w, now_ms)
            elif self.is_stable(w, now_ms):
                self.baseline_weight = w
                if w <= el:
                    self.missing_cup_alert = False
                    self.enter_state("ALERT_REFILL", w, now_ms)
                else:
                    self.start_cycle(now_ms)
                    self.enter_state("TIMING", w, now_ms)

        elif self.state == "TIMING":
            if w < CUP_OFF_THRESHOLD:
                self.lift_start_ms = now_ms
                self.enter_state("LIFTED", w, now_ms)
            elif w - self.baseline_weight >= REFILL_DELTA:
                if self.is_stable(w, now_ms):
                    self.register_refill(self.baseline_weight, w, now_ms)
            elif self.baseline_weight - w >= MIN_DRINK_DELTA:
                # Wajib tunggu stabil agar penurunan saat gelas diangkat tidak tercatat sebagai minum.
                if self.is_stable(w, now_ms):
                    if self.record_drink(self.baseline_weight - w, w, now_ms):
                        self.baseline_weight = w
                        if w <= el:
                            self.missing_cup_alert = False
                            self.enter_state("ALERT_REFILL", w, now_ms)
                        else:
                            self.start_cycle(now_ms)
            elif (now_ms - self.timer_start_ms) >= self.cycle_target_ms:
                self.enter_state("ALERT_DRINK", w, now_ms)

        elif self.state == "LIFTED":
            if w >= CUP_ON_THRESHOLD:
                if self.is_stable(w, now_ms):
                    self.evaluate_returned_cup(w, now_ms)
            else:
                if (now_ms - self.lift_start_ms) >= self.max_lift_duration_ms:
                    self.missing_cup_alert = True
                    self.enter_state("ALERT_REFILL", w, now_ms)

        elif self.state in ("ALERT_DRINK", "ALERT_CHEAT"):
            if w < CUP_OFF_THRESHOLD:
                self.lift_start_ms = now_ms
                self.enter_state("LIFTED", w, now_ms)
            elif w - self.baseline_weight >= REFILL_DELTA:
                if self.is_stable(w, now_ms):
                    self.register_refill(self.baseline_weight, w, now_ms)
                    self.enter_state("TIMING", w, now_ms)
            elif self.baseline_weight - w >= MIN_DRINK_DELTA:
                if self.is_stable(w, now_ms):
                    if self.record_drink(self.baseline_weight - w, w, now_ms):
                        self.baseline_weight = w
                        if w <= el:
                            self.missing_cup_alert = False
                            self.enter_state("ALERT_REFILL", w, now_ms)
                        else:
                            self.start_cycle(now_ms)
                            self.enter_state("TIMING", w, now_ms)

        elif self.state == "ALERT_REFILL":
            if self.missing_cup_alert:
                if w >= CUP_ON_THRESHOLD and self.is_stable(w, now_ms):
                    self.evaluate_returned_cup(w, now_ms)
            elif w < CUP_OFF_THRESHOLD:
                self.lift_start_ms = now_ms
                self.enter_state("LIFTED", w, now_ms)
            elif w <= el:
                # Hapus flag kalibrasi begitu gelas benar-benar kosong teramati.
                self.calibration_align = False
            elif self.calibration_align:
                # Selaraskan baseline ke isi gelas yang sudah ada sebelum kalibrasi.
                if self.is_stable(w, now_ms):
                    self.calibration_align = False
                    if w > el:
                        self.baseline_weight = w
                        self.start_cycle(now_ms)
                        self.enter_state("TIMING", w, now_ms)
            elif w > el and self.is_stable(w, now_ms):
                self.register_refill(self.baseline_weight, w, now_ms)
                self.enter_state("TIMING", w, now_ms)


def settle(f, w, t0):
    f.update(w, t0)
    for i in range(1, 17):
        f.update(w, t0 + i * 100)


def test_all_scenarios():
    base_ms = 30 * 60 * 1000
    hot = compute_adaptive_interval_ms(base_ms, temp_c=34.0, humidity_pct=55.0)
    warm_mid = compute_adaptive_interval_ms(base_ms, temp_c=30.0, humidity_pct=55.0)
    cool_mid = compute_adaptive_interval_ms(base_ms, temp_c=22.0, humidity_pct=75.0)
    cold = compute_adaptive_interval_ms(base_ms, temp_c=18.0, humidity_pct=75.0)
    dry = compute_adaptive_interval_ms(base_ms, temp_c=26.0, humidity_pct=30.0)
    dry_mid = compute_adaptive_interval_ms(base_ms, temp_c=26.0, humidity_pct=40.0)
    custom_20m = compute_adaptive_interval_ms(20 * 60 * 1000, temp_c=30.0, humidity_pct=55.0)
    assert hot == 900000, hot
    assert warm_mid == 1350000, warm_mid
    assert cool_mid == 1980000, cool_mid
    assert cold == 2160000, cold
    assert dry == 1530000, dry
    assert dry_mid == 1665000, dry_mid
    assert custom_20m == 900000, custom_20m
    print(f"[PASS] 1. Adaptif kontinu DHT11: 34C->{hot/60000:.1f}m | 30C->{warm_mid/60000:.1f}m | 22C->{cool_mid/60000:.1f}m | 18C->{cold/60000:.1f}m | 26C/30%->{dry/60000:.1f}m | custom 20m@30C->{custom_20m/60000:.1f}m")

    f = CoasterFSM(empty_cup_weight=130.0, target_interval_ms=15000)

    f.update(30.0, 100)
    assert f.state == "IDLE", f.state
    f.update(38.0, 200)
    assert f.state == "STABLE", f.state
    f.update(20.0, 300)
    assert f.state == "IDLE", f.state
    print("[PASS] 2. Histeresis 25/35 g: 30g tetap IDLE, 38g -> STABLE, 20g -> IDLE")

    f.update(380.0, 1000)
    assert f.state == "STABLE", f.state
    settle(f, 380.0, 1000)
    assert f.state == "TIMING" and f.baseline_weight == 380.0
    print("[PASS] 3. Gelas 380g stabil 1,5 s -> TIMING (baseline 380g)")

    f.update(380.0, 17499)
    assert f.state == "TIMING", f.state
    f.update(380.0, 17500)
    assert f.state == "ALERT_DRINK", f.state
    print("[PASS] 4. Timer 15 s habis -> ALERT_DRINK")

    f.update(0.0, 18000)
    assert f.state == "LIFTED", f.state
    f.update(372.0, 18100)
    assert f.state == "LIFTED", f.state
    for i in range(1, 17):
        f.update(372.0, 18100 + i * 100)
    assert f.state == "ALERT_CHEAT" and f.cheat_count == 1
    print("[PASS] 5. Sentuh < 20g setelah stabil 1,5 s -> ALERT_CHEAT")

    f.update(0.0, 19800)
    assert f.state == "LIFTED", f.state
    f.update(260.0, 19900)
    for i in range(1, 17):
        f.update(260.0, 19900 + i * 100)
    assert f.state == "TIMING" and f.drink_count == 1
    assert abs(f.total_consumed_ml - 120.0) < 0.1
    print("[PASS] 6. Minum sah 120 ml -> TIMING, total=120, drink_count=1")

    f.update(0.0, 21600)
    assert f.state == "LIFTED", f.state
    f.update(135.0, 21700)
    for i in range(1, 17):
        f.update(135.0, 21700 + i * 100)
    assert f.state == "ALERT_REFILL" and f.state_string == "ALERT_EMPTY_CUP"
    assert abs(f.total_consumed_ml - 245.0) < 0.1 and f.drink_count == 2
    print("[PASS] 7. Gelas kosong 135g -> ALERT_EMPTY_CUP (total 245 ml, 2x minum)")

    f.update(350.0, 23400)
    for i in range(1, 17):
        f.update(350.0, 23400 + i * 100)
    assert f.state == "TIMING" and f.refill_count == 1, (f.state, f.refill_count)
    print("[PASS] 8. Isi ulang 350g -> TIMING, refill=1")

    f.update(0.0, 25200)
    assert f.state == "LIFTED", f.state
    f.update(0.0, 35300)
    assert f.state == "ALERT_REFILL" and f.state_string == "ALERT_MISSING_CUP"
    f.update(0.0, 35400)
    assert f.state_string == "ALERT_MISSING_CUP"
    print("[PASS] 9. Diangkat > 10 s -> ALERT_MISSING_CUP, alarm bertahan")

    f.update(200.0, 35450)
    for i in range(1, 17):
        f.update(200.0, 35450 + i * 100)
    assert f.state == "TIMING", f.state
    assert abs(f.total_consumed_ml - 395.0) < 0.1 and f.drink_count == 3
    print("[PASS] 10. Gelas kembali berisi: minum 150g di luar tatakan tercatat -> TIMING")

    settle(f, 170.0, 37100)
    assert f.state == "TIMING" and f.drink_count == 4
    assert abs(f.total_consumed_ml - 425.0) < 0.1
    print("[PASS] 11. Sedotan -30g di TIMING (setelah stabil) tercatat, total=425 ml, drink_count=4")

    settle(f, 410.0, 38800)
    assert f.state == "TIMING" and f.refill_count == 2, (f.state, f.refill_count)
    print("[PASS] 12. Refill langsung di tatakan +240g (setelah stabil) -> refill=2")

    assert compute_adaptive_interval_ms(60000, float("nan"), 50.0) == 60000
    print("[PASS] 13. NaN pada DHT11 -> interval dasar (paritas firmware)")

    g = CoasterFSM(empty_cup_weight=130.0, target_interval_ms=15000)
    settle(g, 380.0, 1000)
    assert g.state == "TIMING" and g.baseline_weight == 380.0
    t = 3000
    for w in (334.0, 288.0, 242.0, 196.0, 150.0, 104.0, 58.0, 12.0):
        g.update(w, t)
        t += 100
    assert g.drink_count == 0 and g.total_consumed_ml == 0.0, (g.drink_count, g.total_consumed_ml)
    assert g.state == "LIFTED" and g.baseline_weight == 380.0, (g.state, g.baseline_weight)
    print("[PASS] 14. Angkat gelas bertahap -46 g/sampel: 0 minum palsu, baseline utuh, -> LIFTED")

    settle(g, 372.0, t)
    assert g.state == "ALERT_CHEAT" and g.cheat_count == 1, (g.state, g.cheat_count)
    print("[PASS] 15. Setelah angkat bertahap, sentuh 372g (-8g) -> ALERT_CHEAT")

    g.update(0.0, 6000)
    g.update(0.0, 16100)
    assert g.state_string == "ALERT_MISSING_CUP"
    settle(g, 362.0, 16200)
    assert g.state == "ALERT_CHEAT" and g.cheat_count == 2 and g.refill_count == 0
    assert g.baseline_weight == 380.0
    print("[PASS] 16. Kembali dari ALERT_MISSING_CUP dengan -18g -> ALERT_CHEAT (refill=0, baseline utuh)")

    g.set_empty_cup_weight(76.8)
    assert g.state_string == "ALERT_EMPTY_CUP" and g.baseline_weight == 76.8
    g.update(0.0, 20000)
    settle(g, 77.0, 20200)
    assert g.drink_count == 0 and g.total_consumed_ml == 0.0
    print("[PASS] 17. Kalibrasi gelas kosong 76.8g menyelaraskan baseline -> 0 minum palsu")

    k = CoasterFSM(empty_cup_weight=130.0, target_interval_ms=15000)
    settle(k, 380.0, 1000)
    assert k.state == "TIMING" and k.baseline_weight == 380.0
    k.update(380.0, 30000)
    assert k.state == "ALERT_DRINK"
    settle(k, 415.0, 30000)
    assert k.refill_count == 1 and k.refill_pending is True
    settle(k, 380.0, 33000)
    assert k.refill_count == 0 and k.drink_count == 0 and k.total_consumed_ml == 0.0
    assert k.baseline_weight == 380.0
    assert k.state == "ALERT_DRINK"
    print("[PASS] 18. Tekan-lepas 35g: refill pending dibatalkan, 0 minum palsu, baseline utuh, alarm pulih")

    k.set_empty_cup_weight(130.0)
    assert k.state_string == "ALERT_EMPTY_CUP"
    settle(k, 380.0, 36000)
    assert k.refill_count == 0 and k.drink_count == 0 and k.total_consumed_ml == 0.0
    assert k.state == "TIMING" and k.baseline_weight == 380.0
    print("[PASS] 19. Kalibrasi dengan gelas berisi 380g: 0 refill palsu, baseline = berat aktual")

    k = CoasterFSM(empty_cup_weight=130.0, target_interval_ms=15000)
    settle(k, 380.0, 1000)
    assert k.state == "TIMING" and k.baseline_weight == 380.0
    settle(k, 415.0, 12000)
    assert k.refill_count == 1 and k.refill_pending is True
    settle(k, 380.0, 14000)
    assert k.refill_count == 0 and k.drink_count == 0 and k.total_consumed_ml == 0.0
    assert k.baseline_weight == 380.0 and k.state == "TIMING"
    k.update(380.0, 17700)
    assert k.state == "ALERT_DRINK"
    print("[PASS] 20. Tekan-lepas di TIMING: timer dipulihkan, alarm tidak tertunda")

    k = CoasterFSM(empty_cup_weight=130.0, target_interval_ms=15000)
    settle(k, 380.0, 1000)
    k.set_empty_cup_weight(130.0)
    assert k.state_string == "ALERT_EMPTY_CUP"
    k.update(0.0, 3000)
    assert k.state == "LIFTED"
    settle(k, 100.0, 4000)
    assert k.state_string == "ALERT_EMPTY_CUP" and k.drink_count == 1
    settle(k, 400.0, 5700)
    # drink_count == 1 di atas adalah quirk baseline kalibrasi; align tidak boleh menyerap refill berikutnya.
    assert k.refill_count == 1 and k.state == "TIMING" and k.baseline_weight == 400.0
    print("[PASS] 21. Flag kalibrasi tidak basi: isi ulang cepat setelah lift tetap terhitung")

    o = CoasterFSM(empty_cup_weight=130.0, target_interval_ms=15000)
    settle(o, 380.0, 1000)
    assert o.state == "TIMING"
    o.update(380.0, 5000)
    o.set_interval(5000)
    o.update(380.0, 5200)
    assert o.state == "TIMING", o.state
    o.update(380.0, 17400)
    assert o.state == "TIMING"
    o.update(380.0, 17600)
    assert o.state == "ALERT_DRINK", o.state
    print("[PASS] 22. Target menyusut di tengah siklus tidak memicu alarm lebih awal")

    q = CoasterFSM(empty_cup_weight=130.0, target_interval_ms=15000)
    q.set_interval(5000)
    settle(q, 380.0, 1000)
    assert q.cycle_target_ms == 5000
    print("[PASS] 23. Siklus yang dimulai setelah set_interval memakai target baru")

    r = CoasterFSM(empty_cup_weight=130.0, target_interval_ms=15000)
    r.set_interval(5000)
    settle(r, 380.0, 1000)
    assert r.state == "TIMING", r.state
    r.update(0.0, 3000)
    settle(r, 340.0, 3100)
    assert r.drink_count == 1, r.drink_count
    r.to_idle(4000)
    assert r.state == "IDLE", r.state
    assert r.drink_count == 1, "statistik harus utuh"
    r.update(340.0, 5000)
    assert r.state == "STABLE", r.state
    print("[PASS] 24. Standby: to_idle mematikan alarm, statistik utuh, siklus lama tidak dilanjutkan")

    print("\nSEMUA SKENARIO LULUS")


if __name__ == "__main__":
    test_all_scenarios()
