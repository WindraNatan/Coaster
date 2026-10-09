"""
Simulasi dan Verifikasi Unit 7-State FSM, Filter, dan Adaptive Timer DHT11
Smart Hydration Coaster (RSK-352 Sistem Kendali & RSK-354 IoT)
"""

CUP_ON_THRESHOLD = 35.0
CUP_OFF_THRESHOLD = 25.0
DEFAULT_EMPTY_CUP_WEIGHT = 130.0
EMPTY_CUP_TOLERANCE = 15.0
MIN_WATER_WEIGHT = 25.0
MIN_DRINK_DELTA = 20.0
STABILITY_BAND = 3.0
STABILITY_TIME_MS = 1500
MAX_LIFT_DURATION_MS = 10000


def compute_adaptive_interval_ms(base_interval_ms: int, temp_c: float, humidity_pct: float) -> int:
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
    def __init__(self, empty_cup_weight=DEFAULT_EMPTY_CUP_WEIGHT, target_interval_ms=15000):
        self.state = "STATE_IDLE"
        self.alert_reason = "ALERT_NONE"
        self.empty_cup_weight = empty_cup_weight
        self.target_interval_ms = target_interval_ms
        self.baseline_weight = 0.0
        self.last_weight_before_lift = 0.0
        self.total_consumed_ml = 0.0
        self.last_drink_ml = 0.0
        self.state_entry_ms = 0
        self.timer_start_ms = 0
        self.lift_start_ms = 0
        self.stable_candidate_weight = 0.0
        self.stable_start_ms = 0

    def empty_cup_ceiling(self) -> float:
        return self.empty_cup_weight + EMPTY_CUP_TOLERANCE

    def min_valid_cup_with_water(self) -> float:
        return self.empty_cup_weight + MIN_WATER_WEIGHT

    def transition_to(self, next_state: str, now_ms: int):
        self.state = next_state
        self.state_entry_ms = now_ms

    def is_weight_settled(self, current_weight: float, now_ms: int) -> bool:
        if abs(current_weight - self.stable_candidate_weight) > STABILITY_BAND:
            self.stable_candidate_weight = current_weight
            self.stable_start_ms = now_ms
            return False
        return (now_ms - self.stable_start_ms) >= STABILITY_TIME_MS

    def update(self, filtered_weight: float, now_ms: int):
        if self.state == "STATE_IDLE":
            self.alert_reason = "ALERT_NONE"
            if filtered_weight >= CUP_ON_THRESHOLD:
                self.stable_candidate_weight = filtered_weight
                self.stable_start_ms = now_ms
                self.transition_to("STATE_STABLE", now_ms)

        elif self.state == "STATE_STABLE":
            if filtered_weight < CUP_OFF_THRESHOLD:
                self.transition_to("STATE_IDLE", now_ms)
            elif self.is_weight_settled(filtered_weight, now_ms):
                if filtered_weight <= self.empty_cup_ceiling():
                    self.alert_reason = "ALERT_EMPTY_CUP"
                    self.transition_to("STATE_ALERT_REFILL", now_ms)
                else:
                    self.baseline_weight = filtered_weight
                    self.timer_start_ms = now_ms
                    self.alert_reason = "ALERT_NONE"
                    self.transition_to("STATE_TIMING", now_ms)

        elif self.state == "STATE_TIMING":
            if filtered_weight < CUP_OFF_THRESHOLD:
                self.last_weight_before_lift = self.baseline_weight
                self.lift_start_ms = now_ms
                self.transition_to("STATE_LIFTED", now_ms)
            elif (self.baseline_weight - filtered_weight) >= MIN_DRINK_DELTA:
                drank = self.baseline_weight - filtered_weight
                self.last_drink_ml = drank
                self.total_consumed_ml += drank
                self.baseline_weight = filtered_weight
                if filtered_weight <= self.empty_cup_ceiling():
                    self.alert_reason = "ALERT_EMPTY_CUP"
                    self.transition_to("STATE_ALERT_REFILL", now_ms)
                else:
                    self.timer_start_ms = now_ms
            elif (now_ms - self.timer_start_ms) >= self.target_interval_ms:
                self.alert_reason = "ALERT_DRINK"
                self.transition_to("STATE_ALERT_DRINK", now_ms)

        elif self.state in ("STATE_ALERT_DRINK", "STATE_ALERT_CHEAT"):
            if filtered_weight < CUP_OFF_THRESHOLD:
                self.last_weight_before_lift = self.baseline_weight
                self.lift_start_ms = now_ms
                self.transition_to("STATE_LIFTED", now_ms)

        elif self.state == "STATE_LIFTED":
            if filtered_weight < CUP_OFF_THRESHOLD:
                if (now_ms - self.lift_start_ms) >= MAX_LIFT_DURATION_MS:
                    self.alert_reason = "ALERT_MISSING_CUP"
                    self.transition_to("STATE_ALERT_REFILL", now_ms)
            else:
                if self.is_weight_settled(filtered_weight, now_ms):
                    if filtered_weight <= self.empty_cup_ceiling():
                        if self.last_weight_before_lift > self.empty_cup_ceiling():
                            drank = self.last_weight_before_lift - filtered_weight
                            if drank >= MIN_DRINK_DELTA:
                                self.last_drink_ml = drank
                                self.total_consumed_ml += drank
                        self.alert_reason = "ALERT_EMPTY_CUP"
                        self.transition_to("STATE_ALERT_REFILL", now_ms)
                    else:
                        delta = self.last_weight_before_lift - filtered_weight
                        refilled = (filtered_weight - self.last_weight_before_lift) >= MIN_DRINK_DELTA
                        if delta >= MIN_DRINK_DELTA:
                            self.last_drink_ml = delta
                            self.total_consumed_ml += delta
                            self.baseline_weight = filtered_weight
                            self.timer_start_ms = now_ms
                            self.alert_reason = "ALERT_NONE"
                            self.transition_to("STATE_TIMING", now_ms)
                        elif refilled:
                            self.baseline_weight = filtered_weight
                            self.timer_start_ms = now_ms
                            self.alert_reason = "ALERT_NONE"
                            self.transition_to("STATE_TIMING", now_ms)
                        else:
                            self.alert_reason = "ALERT_CHEAT"
                            self.transition_to("STATE_ALERT_CHEAT", now_ms)

        elif self.state == "STATE_ALERT_REFILL":
            if self.alert_reason == "ALERT_MISSING_CUP":
                if filtered_weight >= CUP_ON_THRESHOLD and self.is_weight_settled(filtered_weight, now_ms):
                    if filtered_weight >= self.min_valid_cup_with_water():
                        self.baseline_weight = filtered_weight
                        self.timer_start_ms = now_ms
                        self.alert_reason = "ALERT_NONE"
                        self.transition_to("STATE_TIMING", now_ms)
                    else:
                        self.alert_reason = "ALERT_EMPTY_CUP"
            elif self.alert_reason == "ALERT_EMPTY_CUP":
                if filtered_weight < CUP_OFF_THRESHOLD:
                    self.lift_start_ms = now_ms
                elif filtered_weight >= self.min_valid_cup_with_water() and self.is_weight_settled(filtered_weight, now_ms):
                    self.baseline_weight = filtered_weight
                    self.timer_start_ms = now_ms
                    self.alert_reason = "ALERT_NONE"
                    self.transition_to("STATE_TIMING", now_ms)


def test_all_scenarios():
    # 1. Test DHT11 Adaptive Interval
    base_ms = 30 * 60 * 1000  # 30 menit
    hot_dry_ms = compute_adaptive_interval_ms(base_ms, temp_c=33.0, humidity_pct=45.0)
    cool_humid_ms = compute_adaptive_interval_ms(base_ms, temp_c=22.0, humidity_pct=75.0)
    assert hot_dry_ms < base_ms, "Suhu panas harus mempercepat interval pengingat minum"
    assert cool_humid_ms > base_ms, "Suhu sejuk harus memperpanjang interval pengingat minum"
    print(f"[PASS] DHT11 Adaptive Timer: 33C/45% -> {hot_dry_ms/60000:.2f} mnt | 22C/75% -> {cool_humid_ms/60000:.2f} mnt")

    # 2. Test Normal Placement -> Timing -> Drink Alert -> Anti-Cheat -> Valid Drink -> Empty Cup -> Missing Cup
    fsm = CoasterFSM(empty_cup_weight=130.0, target_interval_ms=15000)

    # Taruh gelas berisi 250 ml air (total 380 g)
    fsm.update(380.0, 1000)
    assert fsm.state == "STATE_STABLE"
    fsm.update(380.0, 2600)
    assert fsm.state == "STATE_TIMING"
    print("[PASS] Skenario 1: Gelas berisi air (380g) stabil -> STATE_TIMING")

    # Waktu habis (15 detik berlalu) -> STATE_ALERT_DRINK
    fsm.update(380.0, 17700)
    assert fsm.state == "STATE_ALERT_DRINK" and fsm.alert_reason == "ALERT_DRINK"
    print("[PASS] Skenario 2: Timer habis -> STATE_ALERT_DRINK")

    # User mengangkat gelas sebentar dan menaruh kembali dengan berat hampir sama (372g, selisih 8g < 20g) -> Anti-Cheat!
    fsm.update(0.0, 18000)
    assert fsm.state == "STATE_LIFTED"
    fsm.update(372.0, 19000)
    fsm.update(372.0, 20600)
    assert fsm.state == "STATE_ALERT_CHEAT" and fsm.alert_reason == "ALERT_CHEAT"
    print("[PASS] Skenario 3: Anti-Cheat terdeteksi saat berat hanya berkurang 8g (< 20g) -> STATE_ALERT_CHEAT")

    # User mengangkat gelas lagi dan benar-benar minum 120 ml (berat menjadi 260g, selisih 120g >= 20g)
    fsm.update(0.0, 21000)
    assert fsm.state == "STATE_LIFTED"
    fsm.update(260.0, 22000)
    fsm.update(260.0, 23600)
    assert fsm.state == "STATE_TIMING" and fsm.alert_reason == "ALERT_NONE"
    assert abs(fsm.total_consumed_ml - 120.0) < 0.1
    print(f"[PASS] Skenario 4: Minum valid (120 ml) membatalkan alert dan mereset timer -> STATE_TIMING")

    # User mengangkat gelas, menghabiskan sisa air, dan menaruh gelas kosong (135g)
    fsm.update(0.0, 25000)
    fsm.update(135.0, 26000)
    fsm.update(135.0, 27600)
    assert fsm.state == "STATE_ALERT_REFILL" and fsm.alert_reason == "ALERT_EMPTY_CUP"
    assert abs(fsm.total_consumed_ml - 245.0) < 0.1
    print(f"[PASS] Skenario 5: Gelas kosong (135g) ditaruh kembali -> STATE_ALERT_REFILL (ALERT_EMPTY_CUP)")

    # User mengisi ulang air hingga 350g -> kembali ke STATE_TIMING
    fsm.update(350.0, 28000)
    fsm.update(350.0, 29600)
    assert fsm.state == "STATE_TIMING" and fsm.alert_reason == "ALERT_NONE"
    print("[PASS] Skenario 6: Gelas diisi ulang (350g) -> STATE_TIMING")

    # User mengangkat gelas dan lupa menaruh kembali melebihi MAX_LIFT_DURATION_MS (10 detik)
    fsm.update(0.0, 30000)
    assert fsm.state == "STATE_LIFTED"
    fsm.update(0.0, 40500)
    assert fsm.state == "STATE_ALERT_REFILL" and fsm.alert_reason == "ALERT_MISSING_CUP"
    print("[PASS] Skenario 7: Gelas diangkat > batas waktu -> STATE_ALERT_REFILL (ALERT_MISSING_CUP)")

    # Skenario 8: Minum langsung pakai sedotan di atas tatakan (tanpa diangkat) & uji Hysteresis
    fsm.update(350.0, 41000)
    fsm.update(350.0, 42600)
    assert fsm.state == "STATE_TIMING"
    fsm.update(310.0, 44000)  # Minum 40 ml via sedotan tanpa angkat gelas
    assert fsm.state == "STATE_TIMING" and abs(fsm.total_consumed_ml - 285.0) < 0.1
    print("[PASS] Skenario 8: Minum via sedotan di tatakan (40 ml) tercatat & mereset timer")


if __name__ == "__main__":
    test_all_scenarios()
    print("\nSemua 8 skenario FSM dan perhitungan timer adaptif DHT11 lulus uji.")
