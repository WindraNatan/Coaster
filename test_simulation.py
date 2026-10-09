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


def compute_adaptive_interval_ms(base_interval_ms: int, temp_c: float, humidity_pct: float) -> int:
    if temp_c != temp_c or humidity_pct != humidity_pct:  # NaN guard, paritas dengan firmware
        return base_interval_ms
    if temp_c < 24.0:
        k_temp = 1.20
    elif temp_c <= 28.0:
        k_temp = 1.00
    elif temp_c <= 32.0:
        k_temp = 0.75
    else:
        k_temp = 0.50
    k_hum = 0.85 if humidity_pct < 40.0 else 1.00
    return max(5000, int(base_interval_ms * k_temp * k_hum))


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

    def record_drink(self, grams):
        self.total_consumed_ml += grams
        self.drink_count += 1

    def evaluate_returned_cup(self, w, now_ms):
        decreased = self.baseline_weight - w
        increased = w - self.baseline_weight

        if w <= self.empty_limit:
            if decreased >= MIN_DRINK_DELTA:
                self.record_drink(decreased)
            self.baseline_weight = w
            self.missing_cup_alert = False
            self.enter_state("ALERT_REFILL", w, now_ms)
            return

        if increased >= REFILL_DELTA:
            self.baseline_weight = w
            self.timer_start_ms = now_ms
            self.refill_count += 1
            self.enter_state("TIMING", w, now_ms)
            return

        if decreased >= MIN_DRINK_DELTA:
            self.record_drink(decreased)
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
                if self.is_stable(w, now_ms):
                    self.baseline_weight = w
                    self.timer_start_ms = now_ms
                    self.refill_count += 1
            elif self.baseline_weight - w >= MIN_DRINK_DELTA:
                # Fix C4: gerbang stabilitas. Tanpa ini, penurunan saat mengangkat
                # gelas (~46 g/sampel) tercatat sebagai deretan minum palsu.
                if self.is_stable(w, now_ms):
                    self.record_drink(self.baseline_weight - w)
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
                    self.baseline_weight = w
                    self.timer_start_ms = now_ms
                    self.refill_count += 1
                    self.enter_state("TIMING", w, now_ms)
            elif self.baseline_weight - w >= MIN_DRINK_DELTA:
                # Fix C4: gerbang stabilitas sebelum mencatat minum
                if self.is_stable(w, now_ms):
                    self.record_drink(self.baseline_weight - w)
                    self.baseline_weight = w
                    if w <= el:
                        self.missing_cup_alert = False
                        self.enter_state("ALERT_REFILL", w, now_ms)
                    else:
                        self.timer_start_ms = now_ms
                        self.enter_state("TIMING", w, now_ms)

        elif self.state == "ALERT_REFILL":
            if w < CUP_OFF_THRESHOLD:
                if not self.missing_cup_alert:
                    # gelas kosong diangkat untuk diisi
                    self.lift_start_ms = now_ms
                    self.enter_state("LIFTED", w, now_ms)
                # kasus MISSING_CUP: alarm tetap sampai gelas kembali
            elif w > el:
                # Fix M4: satu pintu pemulihan untuk EMPTY dan MISSING
                if self.is_stable(w, now_ms):
                    decreased = self.baseline_weight - w
                    if decreased >= MIN_DRINK_DELTA:
                        self.record_drink(decreased)
                    else:
                        self.refill_count += 1
                    self.baseline_weight = w
                    self.timer_start_ms = now_ms
                    self.missing_cup_alert = False
                    self.enter_state("TIMING", w, now_ms)
            else:
                # gelas kosong ditaruh saat MISSING: alarm tetap, alasan ganti EMPTY
                self.missing_cup_alert = False


def settle(f, w, t0):
    """Kandidat stabil 1,5 s penuh: sampel t0 lalu 16 x 100 ms (paritas dgn harness C++)."""
    f.update(w, t0)
    for i in range(1, 17):
        f.update(w, t0 + i * 100)


def test_all_scenarios():
    # 1. Formula adaptif DHT11
    base_ms = 30 * 60 * 1000
    hot = compute_adaptive_interval_ms(base_ms, temp_c=33.0, humidity_pct=45.0)
    cool = compute_adaptive_interval_ms(base_ms, temp_c=22.0, humidity_pct=75.0)
    dry = compute_adaptive_interval_ms(base_ms, temp_c=27.0, humidity_pct=35.0)
    assert hot == int(base_ms * 0.50), hot
    assert cool == int(base_ms * 1.20), cool
    assert dry == int(base_ms * 0.85), dry
    print(f"[PASS] 1. Adaptif DHT11: 33C/45% -> {hot/60000:.1f} mnt | 22C/75% -> {cool/60000:.1f} mnt | 27C/35% -> {dry/60000:.1f} mnt")

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

    print("\nSEMUA SKENARIO LULUS")


if __name__ == "__main__":
    test_all_scenarios()
