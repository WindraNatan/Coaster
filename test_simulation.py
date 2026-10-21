"""
Simulasi dan Verifikasi Unit 7-State FSM + Adaptive Timer DHT11
Smart Hydration Coaster (RSK-352 Sistem Kendali & RSK-354 IoT)

Port 1:1 dari fsm.h (C++). Setiap cabang, urutan cabang, dan ambang
berasal dari fsm.h + config.h. Jika dua berkas ini berbeda, itu bug.
"""

CUP_ON_THRESHOLD = 35.0
CUP_OFF_THRESHOLD = 25.0
DEFAULT_EMPTY_CUP_G = 130.0
MAX_EMPTY_CUP_G = 300.0
EMPTY_CUP_TOLERANCE = 15.0
MIN_DRINK_DELTA = 20.0
REFILL_DELTA = 30.0
STABILITY_BAND_G = 3.0
STABILITY_TIME_MS = 1500
# K1: isi ulang di tempat baru sah setelah bertahan sekian lama; kembali ke
# baseline pra-isi-ulang dalam batas ini = pola tekan-lepas gelas.
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
    if temp_c != temp_c or humidity_pct != humidity_pct:  # NaN guard, paritas dengan firmware
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
    """Mirror 1:1 dari fsm.h. Jangan ubah salah satu tanpa yang lain."""

    def __init__(self, empty_cup_weight=DEFAULT_EMPTY_CUP_G, target_interval_ms=15000):
        self.state = "IDLE"
        self.baseline_weight = 0.0
        self.empty_cup_weight = empty_cup_weight
        self.timer_start_ms = 0
        self.lift_start_ms = 0
        self.target_interval_ms = target_interval_ms
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

    @property
    def state_string(self):
        if self.state == "ALERT_REFILL":
            return "ALERT_MISSING_CUP" if self.missing_cup_alert else "ALERT_EMPTY_CUP"
        return self.state

    @property
    def empty_limit(self):
        return self.empty_cup_weight + EMPTY_CUP_TOLERANCE

    def enter_state(self, next_state, w, now_ms):
        # Fix C2: stabilitas selalu mulai segar di state baru
        self.state = next_state
        self.stable_candidate_weight = w
        self.stable_start_ms = now_ms

    def is_stable(self, w, now_ms):
        # Fix C1: berbasis waktu, bukan hitungan pemanggilan
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
                # K3: update() menyelaraskan baseline ke berat aktual dulu,
                # tidak menghitung isi ulang untuk air yang sudah ada di gelas.
                self.calibration_align = True
                self.state = "ALERT_REFILL"
            return True
        return False

    def refill_reversed(self, w, now_ms):
        # K1: heuristik pembalik. Tekan lebih lama dari REFILL_CONFIRM_MS tetap lolos.
        if not self.refill_pending or now_ms - self.last_refill_ms > REFILL_CONFIRM_MS:
            return False
        d = w - self.pre_refill_baseline
        return -STABILITY_BAND_G <= d <= STABILITY_BAND_G

    def register_refill(self, old_baseline, w, now_ms):
        # K1: simpan state & timer pra-isi-ulang supaya pembatalan (tekan-lepas)
        # bisa memulihkannya — lihat cancel_pending_refill.
        self.pre_refill_state = self.state
        self.pre_refill_timer_start = self.timer_start_ms
        self.baseline_weight = w
        self.timer_start_ms = now_ms
        self.refill_count += 1
        self.refill_pending = True
        self.pre_refill_baseline = old_baseline
        self.last_refill_ms = now_ms

    def cancel_pending_refill(self, now_ms):
        self.refill_count -= 1
        self.refill_pending = False
        self.baseline_weight = self.pre_refill_baseline
        # K1: pulihkan state & timer pra-tekanan. Tanpa ini, tekan-lepas
        # membunuh alarm minum sampai interval penuh berikutnya dan menekan
        # berulang menunda pengingat tanpa batas. LIFTED/ALERT_REFILL sengaja
        # tidak dipulihkan: gelas sudah kembali di tatakan, memulihkan LIFTED
        # mengevaluasi ulang kembalinya gelas (cheat palsu) dan memulihkan
        # ALERT_REFILL bisa menyangkutkan gelas penuh di alarm kosong.
        if self.pre_refill_state in ("TIMING", "ALERT_DRINK", "ALERT_CHEAT"):
            self.state = self.pre_refill_state
            self.timer_start_ms = self.pre_refill_timer_start
        else:
            self.timer_start_ms = now_ms

    def record_drink(self, grams, w, now_ms):
        # False = minum dibatalkan karena pola tekan-lepas
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
                # K1: false = tekan-lepas, isi ulang pending sudah dibatalkan
                self.record_drink(decreased, w, now_ms)
            self.baseline_weight = w
            self.enter_state("ALERT_REFILL", w, now_ms)
            return

        if increased >= REFILL_DELTA:
            self.register_refill(self.baseline_weight, w, now_ms)
            self.enter_state("TIMING", w, now_ms)
            return

        if decreased >= MIN_DRINK_DELTA:
            # K1: false = tekan-lepas, isi ulang pending sudah dibatalkan
            self.record_drink(decreased, w, now_ms)
            self.baseline_weight = w
            self.timer_start_ms = now_ms
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
                    self.timer_start_ms = now_ms
                    self.enter_state("TIMING", w, now_ms)

        elif self.state == "TIMING":
            if w < CUP_OFF_THRESHOLD:
                self.lift_start_ms = now_ms
                self.enter_state("LIFTED", w, now_ms)
            elif w - self.baseline_weight >= REFILL_DELTA:
                # Isi ulang langsung di atas tatakan (PRD skenario 8).
                # Fix C4: tunggu berat baru stabil sebelum mencatat.
                # K1: pending sampai terbukti bertahan (register_refill).
                if self.is_stable(w, now_ms):
                    self.register_refill(self.baseline_weight, w, now_ms)
            elif self.baseline_weight - w >= MIN_DRINK_DELTA:
                # Fix C4: gerbang stabilitas. Tanpa ini, penurunan saat mengangkat
                # gelas (~46 g/sampel) tercatat sebagai deretan minum palsu.
                if self.is_stable(w, now_ms):
                    # K1: false = tekan-lepas, isi ulang pending dibatalkan
                    if self.record_drink(self.baseline_weight - w, w, now_ms):
                        self.baseline_weight = w
                        if w <= el:
                            self.missing_cup_alert = False
                            self.enter_state("ALERT_REFILL", w, now_ms)
                        else:
                            self.timer_start_ms = now_ms
            elif (now_ms - self.timer_start_ms) >= self.target_interval_ms:
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
                # Fix C4: tunggu berat baru stabil sebelum mencatat
                if self.is_stable(w, now_ms):
                    self.register_refill(self.baseline_weight, w, now_ms)
                    self.enter_state("TIMING", w, now_ms)
            elif self.baseline_weight - w >= MIN_DRINK_DELTA:
                # Fix C4: gerbang stabilitas sebelum mencatat minum
                if self.is_stable(w, now_ms):
                    # K1: false = tekan-lepas, minum tidak dicatat
                    if self.record_drink(self.baseline_weight - w, w, now_ms):
                        self.baseline_weight = w
                        if w <= el:
                            self.missing_cup_alert = False
                            self.enter_state("ALERT_REFILL", w, now_ms)
                        else:
                            self.timer_start_ms = now_ms
                            self.enter_state("TIMING", w, now_ms)

        elif self.state == "ALERT_REFILL":
            if self.missing_cup_alert:
                if w >= CUP_ON_THRESHOLD and self.is_stable(w, now_ms):
                    self.evaluate_returned_cup(w, now_ms)
            elif w < CUP_OFF_THRESHOLD:
                self.lift_start_ms = now_ms
                self.enter_state("LIFTED", w, now_ms)
            elif w <= el:
                # K3: gelas kosong teramati di state ini. Kalibrasi dapat
                # memaksa state ini dengan gelas berisi (calibration_align);
                # bila gelas lalu diangkat, flag itu basi dan menekan
                # refill_count yang sah. Berat kosong = aman menghitung isi
                # ulang lagi.
                self.calibration_align = False
            elif self.calibration_align:
                # K3: jangan hitung isi ulang untuk air yang sudah ada saat
                # kalibrasi; selaraskan baseline ke berat aktual.
                if self.is_stable(w, now_ms):
                    self.calibration_align = False
                    if w > el:
                        self.baseline_weight = w
                        self.timer_start_ms = now_ms
                        self.enter_state("TIMING", w, now_ms)
            elif w > el and self.is_stable(w, now_ms):
                self.register_refill(self.baseline_weight, w, now_ms)
                self.enter_state("TIMING", w, now_ms)


def settle(f, w, t0):
    """Kandidat stabil 1,5 s penuh: sampel t0 lalu 16 x 100 ms (paritas dgn harness C++)."""
    f.update(w, t0)
    for i in range(1, 17):
        f.update(w, t0 + i * 100)


def test_all_scenarios():
    # 1. Formula adaptif kontinu DHT11 + kustomisasi interval dasar
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

    # 2. Histeresis IDLE: di bawah 35 g tidak masuk STABLE; masuk lalu turun -> IDLE
    f.update(30.0, 100)
    assert f.state == "IDLE", f.state
    f.update(38.0, 200)
    assert f.state == "STABLE", f.state
    f.update(20.0, 300)
    assert f.state == "IDLE", f.state
    print("[PASS] 2. Histeresis 25/35 g: 30g tetap IDLE, 38g -> STABLE, 20g -> IDLE")

    # 3. Taruh gelas 380 g -> stabil 1,5 s -> TIMING
    f.update(380.0, 1000)
    assert f.state == "STABLE", f.state
    settle(f, 380.0, 1000)
    assert f.state == "TIMING" and f.baseline_weight == 380.0
    print("[PASS] 3. Gelas 380g stabil 1,5 s -> TIMING (baseline 380g)")

    # 4. Timer 15 s habis -> ALERT_DRINK
    f.update(380.0, 17499)
    assert f.state == "TIMING", f.state
    f.update(380.0, 17500)
    assert f.state == "ALERT_DRINK", f.state
    print("[PASS] 4. Timer 15 s habis -> ALERT_DRINK")

    # 5. Anti-cheat: sentuh 372 g (turun 8g < 20g); butuh stabil penuh 1,5 s
    f.update(0.0, 18000)
    assert f.state == "LIFTED", f.state
    f.update(372.0, 18100)   # sentuh sekilas: kandidat baru, TIDAK evaluasi instan
    assert f.state == "LIFTED", f.state
    for i in range(1, 17):
        f.update(372.0, 18100 + i * 100)
    assert f.state == "ALERT_CHEAT" and f.cheat_count == 1
    print("[PASS] 5. Sentuh < 20g setelah stabil 1,5 s -> ALERT_CHEAT")

    # 6. Minum sah 120 g -> TIMING
    f.update(0.0, 19800)
    assert f.state == "LIFTED", f.state
    f.update(260.0, 19900)
    for i in range(1, 17):
        f.update(260.0, 19900 + i * 100)
    assert f.state == "TIMING" and f.drink_count == 1
    assert abs(f.total_consumed_ml - 120.0) < 0.1
    print("[PASS] 6. Minum sah 120 ml -> TIMING, total=120, drink_count=1")

    # 7. Habiskan air: gelas kosong 135 g -> ALERT_EMPTY_CUP
    f.update(0.0, 21600)
    assert f.state == "LIFTED", f.state
    f.update(135.0, 21700)
    for i in range(1, 17):
        f.update(135.0, 21700 + i * 100)
    assert f.state == "ALERT_REFILL" and f.state_string == "ALERT_EMPTY_CUP"
    assert abs(f.total_consumed_ml - 245.0) < 0.1 and f.drink_count == 2
    print("[PASS] 7. Gelas kosong 135g -> ALERT_EMPTY_CUP (total 245 ml, 2x minum)")

    # 8. Isi ulang sampai 350 g (stabil) -> TIMING, refill=1
    f.update(350.0, 23400)
    for i in range(1, 17):
        f.update(350.0, 23400 + i * 100)
    assert f.state == "TIMING" and f.refill_count == 1, (f.state, f.refill_count)
    print("[PASS] 8. Isi ulang 350g -> TIMING, refill=1")

    # 9. Gelas diangkat > 10 s -> ALERT_MISSING_CUP, alarm bertahan
    f.update(0.0, 25200)
    assert f.state == "LIFTED", f.state
    f.update(0.0, 35300)
    assert f.state == "ALERT_REFILL" and f.state_string == "ALERT_MISSING_CUP"
    f.update(0.0, 35400)
    assert f.state_string == "ALERT_MISSING_CUP"
    print("[PASS] 9. Diangkat > 10 s -> ALERT_MISSING_CUP, alarm bertahan")

    # 10. MISSING pulih: gelas kembali berisi 200 g; minum 180 g di luar tercatat
    f.update(200.0, 35450)
    for i in range(1, 17):
        f.update(200.0, 35450 + i * 100)
    assert f.state == "TIMING", f.state
    assert abs(f.total_consumed_ml - 395.0) < 0.1 and f.drink_count == 3
    print("[PASS] 10. Gelas kembali berisi: minum 150g di luar tatakan tercatat -> TIMING")

    # 11. Sedotan -30 g di TIMING: tercatat SETELAH berat baru stabil (Fix C4),
    #     bukan seketika saat turun
    settle(f, 170.0, 37100)
    assert f.state == "TIMING" and f.drink_count == 4
    assert abs(f.total_consumed_ml - 425.0) < 0.1
    print("[PASS] 11. Sedotan -30g di TIMING (setelah stabil) tercatat, total=425 ml, drink_count=4")

    # 12. Isi ulang langsung di tatakan +240 g di TIMING -> refill=2 setelah stabil
    settle(f, 410.0, 38800)
    assert f.state == "TIMING" and f.refill_count == 2, (f.state, f.refill_count)
    print("[PASS] 12. Refill langsung di tatakan +240g (setelah stabil) -> refill=2")

    # 13. NaN guard DHT11 paritas firmware
    assert compute_adaptive_interval_ms(60000, float("nan"), 50.0) == 60000
    print("[PASS] 13. NaN pada DHT11 -> interval dasar (paritas firmware)")

    # 14. REGRESI BUG HARDWARE 2026-10-08: mengangkat gelas itu bertahap
    #     (~46 g per sampel 100 ms), bukan satu langkah. Tanpa gerbang stabilitas
    #     di cabang minum TIMING, tiap sampel turun dicatat sebagai satu kali minum.
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

    # 15. Lanjutan 14: gelas dikembalikan tersentuh 372 g (-8 g dari baseline) -> CHEAT.
    #     Inilah cabang yang mustahil dicapai sebelum Fix C4.
    settle(g, 372.0, t)
    assert g.state == "ALERT_CHEAT" and g.cheat_count == 1, (g.state, g.cheat_count)
    print("[PASS] 15. Setelah angkat bertahap, sentuh 372g (-8g) -> ALERT_CHEAT")

    # 16. Celah 1: kembali dari ALERT_MISSING_CUP tanpa minum cukup (-18.1g) -> ALERT_CHEAT, bukan REFILL
    g.update(0.0, 6000)
    g.update(0.0, 16100)
    assert g.state_string == "ALERT_MISSING_CUP"
    settle(g, 362.0, 16200)
    assert g.state == "ALERT_CHEAT" and g.cheat_count == 2 and g.refill_count == 0
    assert g.baseline_weight == 380.0
    print("[PASS] 16. Kembali dari ALERT_MISSING_CUP dengan -18g -> ALERT_CHEAT (refill=0, baseline utuh)")

    # 17. Celah 2: set_empty_cup_weight menyelaraskan baseline agar tidak memicu minum palsu
    g.set_empty_cup_weight(76.8)
    assert g.state_string == "ALERT_EMPTY_CUP" and g.baseline_weight == 76.8
    g.update(0.0, 20000)
    settle(g, 77.0, 20200)
    assert g.drink_count == 0 and g.total_consumed_ml == 0.0
    print("[PASS] 17. Kalibrasi gelas kosong 76.8g menyelaraskan baseline -> 0 minum palsu")

    # 18. K1: tekan-lepas gelas di TIMING tidak boleh menghasilkan isi ulang/minum palsu.
    #     Eksploit audit: 5x tekan-lepas 35g -> 175 ml minum + 5x isi ulang palsu.
    k = CoasterFSM(empty_cup_weight=130.0, target_interval_ms=15000)
    settle(k, 380.0, 1000)
    assert k.state == "TIMING" and k.baseline_weight == 380.0
    k.update(380.0, 30000)          # timer habis -> alarm
    assert k.state == "ALERT_DRINK"
    settle(k, 415.0, 30000)         # tekan +35 g, stabil 1,5 s -> isi ulang pending
    assert k.refill_count == 1 and k.refill_pending is True
    settle(k, 380.0, 33000)         # lepas; kembali ke baseline pra-tekanan dalam 5 s
    assert k.refill_count == 0 and k.drink_count == 0 and k.total_consumed_ml == 0.0
    assert k.baseline_weight == 380.0
    # K1: alarm dipulihkan — tekan-lepas tidak boleh membunuh alarm minum.
    assert k.state == "ALERT_DRINK"
    print("[PASS] 18. Tekan-lepas 35g: refill pending dibatalkan, 0 minum palsu, baseline utuh, alarm pulih")

    # 19. K3: kalibrasi (Simpan Gelas) saat gelas BERISI di tatakan tidak boleh
    #     memicu isi ulang palsu 250 g.
    k.set_empty_cup_weight(130.0)
    assert k.state_string == "ALERT_EMPTY_CUP"
    settle(k, 380.0, 36000)
    assert k.refill_count == 0 and k.drink_count == 0 and k.total_consumed_ml == 0.0
    assert k.state == "TIMING" and k.baseline_weight == 380.0
    print("[PASS] 19. Kalibrasi dengan gelas berisi 380g: 0 refill palsu, baseline = berat aktual")

    # 20. K1: tekan-lepas di TIMING tidak boleh menunda timer. Alarm yang sudah
    #     ditunda sekali bisa ditunda berulang kali (pengingat tak pernah bunyi).
    k = CoasterFSM(empty_cup_weight=130.0, target_interval_ms=15000)
    settle(k, 380.0, 1000)               # TIMING, timer mulai 2600 ms
    assert k.state == "TIMING" and k.baseline_weight == 380.0
    settle(k, 415.0, 12000)              # tekan +35 g stabil -> isi ulang pending
    assert k.refill_count == 1 and k.refill_pending is True
    settle(k, 380.0, 14000)              # lepas dalam 5 s -> dibatalkan, timer dipulihkan
    assert k.refill_count == 0 and k.drink_count == 0 and k.total_consumed_ml == 0.0
    assert k.baseline_weight == 380.0 and k.state == "TIMING"
    k.update(380.0, 17700)               # 17700 - 2600 = 15100 >= 15000: alarm TIDAK tertunda
    assert k.state == "ALERT_DRINK"
    print("[PASS] 20. Tekan-lepas di TIMING: timer dipulihkan, alarm tidak tertunda")

    # 21. K3: flag kalibrasi tidak boleh basi. Kalibrasi dengan gelas berisi lalu
    #     gelas diangkat melewati jalur selaras; gelas kembali kosong dan diisi
    #     ulang cepat -> isi ulang sah harus tetap terhitung.
    k = CoasterFSM(empty_cup_weight=130.0, target_interval_ms=15000)
    settle(k, 380.0, 1000)               # TIMING baseline 380
    k.set_empty_cup_weight(130.0)        # ALERT_REFILL + calibration_align, baseline 130
    assert k.state_string == "ALERT_EMPTY_CUP"
    k.update(0.0, 3000)                  # diangkat sebelum align selesai -> LIFTED (flag basi)
    assert k.state == "LIFTED"
    settle(k, 100.0, 4000)               # kembali kosong: baseline kalibrasi 130 -> -30 g tercatat minum
    assert k.state_string == "ALERT_EMPTY_CUP" and k.drink_count == 1
    settle(k, 400.0, 5700)               # isi ulang cepat (<1,5 s di 100 g): align tak sempat firing
    # refill_count == 1: isi ulang sah. Tanpa re-arm: 0 (align menyerap isi ulang).
    # drink_count == 1 di atas adalah quirk baseline kalibrasi (sudah ada sebelum fix).
    assert k.refill_count == 1 and k.state == "TIMING" and k.baseline_weight == 400.0
    print("[PASS] 21. Flag kalibrasi tidak basi: isi ulang cepat setelah lift tetap terhitung")

    print("\nSEMUA SKENARIO LULUS")


if __name__ == "__main__":
    test_all_scenarios()
