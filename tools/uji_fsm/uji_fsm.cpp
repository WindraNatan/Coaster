// Uji paritas fsm.h di PC (tanpa ESP32).
// Jalankan dari folder ini:
//   g++ -std=c++17 -Wall -Wextra -I. -I../../SmartHydrationCoaster -o uji_fsm uji_fsm.cpp && ./uji_fsm
// Skenario harus identik dengan test_simulation.py (Python) dan web/index.html (JS).

#include <cstdio>
#include <cmath>
#include "fsm.h"
#include "adaptive_controller.h"

static int fails = 0;
#define CHECK(cond, msg) do { if (cond) printf("[PASS] %s\n", msg); else { printf("[FAIL] %s\n", msg); fails++; } } while (0)

static void settle(CoasterFSM& f, float w, uint32_t t0){
    f.update(w, t0);
    for (int i = 1; i <= 16; i++) f.update(w, t0 + i * 100);
}

int main(){
    // 1. Formula adaptif kontinu DHT11 -- nilai harapan sama dengan test_simulation.py dan web.
    const uint32_t baseMs = BASE_INTERVAL_MS;
    CHECK(computeAdaptiveIntervalMs(baseMs, 34.0f, 55.0f) == 900000u,  "1. 34C/55% -> 15,0 mnt");
    CHECK(computeAdaptiveIntervalMs(baseMs, 30.0f, 55.0f) == 1350000u, "1b. 30C/55% (interpolasi) -> 22,5 mnt");
    CHECK(computeAdaptiveIntervalMs(baseMs, 22.0f, 75.0f) == 1980000u, "1c. 22C/75% (interpolasi) -> 33,0 mnt");
    CHECK(computeAdaptiveIntervalMs(baseMs, 18.0f, 75.0f) == 2160000u, "1d. 18C/75% -> 36,0 mnt");
    CHECK(computeAdaptiveIntervalMs(baseMs, 26.0f, 30.0f) == 1530000u, "1e. 26C/30% -> 25,5 mnt");
    CHECK(computeAdaptiveIntervalMs(baseMs, 26.0f, 40.0f) == 1665000u, "1f. 26C/40% (interpolasi RH) -> 27,75 mnt");
    CHECK(computeAdaptiveIntervalMs(1200000u, 30.0f, 55.0f) == 900000u, "1g. custom 20 mnt @ 30C/55% -> 15,0 mnt");
    CHECK(computeAdaptiveIntervalMs(60000u, NAN, 50.0f) == 60000u,     "1h. NaN -> interval dasar");
    CHECK(computeAdaptiveIntervalMs(1000u, 40.0f, 10.0f) == ADAPT_FLOOR_MS, "1i. lantai 5 s berlaku");

    CoasterFSM f;
    f.setEmptyCupWeight(130.0f);
    f.setInterval(15000);
    f.setMaxLiftDuration(10000);   // mode demo, seperti updateAdaptiveInterval() di .ino

    f.update(30, 100);   CHECK(f.getState() == STATE_IDLE, "2. 30g tetap IDLE");
    f.update(38, 200);   CHECK(f.getState() == STATE_STABLE, "2b. 38g -> STABLE");
    f.update(20, 300);   CHECK(f.getState() == STATE_IDLE, "2c. 20g -> IDLE");

    f.update(380, 1000); settle(f, 380, 1000);
    CHECK(f.getState() == STATE_TIMING && f.getBaselineWeight() == 380.0f, "3. 380g stabil -> TIMING baseline 380");

    f.update(380, 17499); CHECK(f.getState() == STATE_TIMING, "4. 17499ms masih TIMING");
    f.update(380, 17500); CHECK(f.getState() == STATE_ALERT_DRINK, "4b. 17500ms -> ALERT_DRINK");

    f.update(0, 18000);   CHECK(f.getState() == STATE_LIFTED, "5. diangkat -> LIFTED");
    f.update(372, 18100); CHECK(f.getState() == STATE_LIFTED, "5b. sentuh sekilas belum dievaluasi");
    settle(f, 372, 18100);
    CHECK(f.getState() == STATE_ALERT_CHEAT && f.getCheatCount() == 1, "5c. sentuh -8g -> ALERT_CHEAT");

    f.update(0, 19800); settle(f, 260, 19900);
    CHECK(f.getState() == STATE_TIMING && f.getDrinkCount() == 1 && fabs(f.getTotalDrank() - 120.0f) < 0.1f,
          "6. minum 120g -> TIMING, total 120");

    f.update(0, 21600); settle(f, 135, 21700);
    CHECK(f.getState() == STATE_ALERT_REFILL && fabs(f.getTotalDrank() - 245.0f) < 0.1f && f.getDrinkCount() == 2,
          "7. gelas kosong 135g -> ALERT_REFILL, total 245");

    settle(f, 350, 23400);
    CHECK(f.getState() == STATE_TIMING && f.getRefillCount() == 1, "8. refill 350g -> TIMING refill=1");

    f.update(0, 25200); f.update(0, 35300);
    CHECK(f.getState() == STATE_ALERT_REFILL && f.isMissingCup(), "9. diangkat >10s -> ALERT_MISSING_CUP");
    f.update(0, 35400); CHECK(f.isMissingCup(), "9b. alarm bertahan");

    settle(f, 200, 35450);
    CHECK(f.getState() == STATE_TIMING && f.getDrinkCount() == 3 && fabs(f.getTotalDrank() - 395.0f) < 0.1f,
          "10. pulih, minum di luar tercatat");

    settle(f, 170, 37100);
    CHECK(f.getState() == STATE_TIMING && f.getDrinkCount() == 4 && fabs(f.getTotalDrank() - 425.0f) < 0.1f,
          "11. sedotan -30g tercatat setelah stabil");

    settle(f, 410, 38800);
    CHECK(f.getState() == STATE_TIMING && f.getRefillCount() == 2, "12. refill +240g -> refill=2");

    // 14/15. REGRESI: angkat gelas bertahap (~46 g/sampel)
    CoasterFSM g;
    g.setEmptyCupWeight(130.0f);
    g.setInterval(15000);
    g.setMaxLiftDuration(10000);
    settle(g, 380, 1000);
    CHECK(g.getState() == STATE_TIMING && g.getBaselineWeight() == 380.0f, "14. siap: TIMING baseline 380");
    uint32_t t = 3000;
    const float ramp[] = {334, 288, 242, 196, 150, 104, 58, 12};
    for (float w : ramp) { g.update(w, t); t += 100; }
    CHECK(g.getDrinkCount() == 0 && g.getTotalDrank() == 0.0f, "14b. angkat bertahap: 0 minum palsu");
    CHECK(g.getState() == STATE_LIFTED && g.getBaselineWeight() == 380.0f, "14c. -> LIFTED, baseline utuh 380");
    settle(g, 372, t);
    CHECK(g.getState() == STATE_ALERT_CHEAT && g.getCheatCount() == 1, "15. sentuh 372g setelah angkat bertahap -> ALERT_CHEAT");

    g.update(0, 6000); g.update(0, 16100);
    CHECK(g.getState() == STATE_ALERT_REFILL && g.isMissingCup(), "16a. diangkat >10s dari CHEAT -> ALERT_MISSING_CUP");
    settle(g, 362, 16200);
    CHECK(g.getState() == STATE_ALERT_CHEAT && g.getCheatCount() == 2 && g.getRefillCount() == 0 && g.getBaselineWeight() == 380.0f,
          "16b. kembali dari MISSING_CUP -18g -> ALERT_CHEAT (refill=0, baseline utuh)");

    CHECK(g.setEmptyCupWeight(76.8f) && !g.setEmptyCupWeight(350.0f),
          "17a. setEmptyCupWeight mengembalikan true (76.8g) dan false (350g di luar rentang)");
    CHECK(g.getState() == STATE_ALERT_REFILL && !g.isMissingCup() && fabs(g.getBaselineWeight() - 76.8f) < 0.01f,
          "17a-state. setEmptyCupWeight(76.8) -> ALERT_EMPTY_CUP, baseline=76.8");
    g.update(0, 20000); settle(g, 77.0f, 20200);
    CHECK(g.getDrinkCount() == 0 && g.getTotalDrank() == 0.0f, "17b. angkat-taruh gelas kosong 77g -> 0 minum palsu");
    g.restoreDailyStats(650.0f, 4, 2, 1);
    CHECK(fabs(g.getTotalDrank() - 650.0f) < 0.01f && g.getDrinkCount() == 4 && g.getRefillCount() == 2 && g.getCheatCount() == 1 && g.getTargetIntervalMs() == 15000u,
          "17c. restoreDailyStats & getTargetIntervalMs memulihkan nilai NVS dengan akurat");

    // 18. K1: tekan-lepas gelas di TIMING tidak boleh menghasilkan isi ulang/minum palsu.
    //     Eksploit audit: 5x tekan-lepas 35g -> 175 ml minum + 5x isi ulang palsu.
    CoasterFSM k;
    k.setEmptyCupWeight(130.0f);
    k.setInterval(15000);
    k.setMaxLiftDuration(10000);
    settle(k, 380, 1000);
    CHECK(k.getState() == STATE_TIMING && k.getBaselineWeight() == 380.0f, "18a. siap: TIMING baseline 380");
    k.update(380, 30000);
    CHECK(k.getState() == STATE_ALERT_DRINK, "18b. timer habis -> ALERT_DRINK");
    settle(k, 415, 30000);
    CHECK(k.getRefillCount() == 1, "18c. tekan +35g stabil -> refill pending tercatat");
    settle(k, 380, 33000);
    CHECK(k.getRefillCount() == 0 && k.getDrinkCount() == 0 && k.getTotalDrank() == 0.0f && fabs(k.getBaselineWeight() - 380.0f) < 0.01f,
          "18d. lepas tekan -> refill dibatalkan, 0 minum palsu, baseline utuh");
    CHECK(k.getState() == STATE_ALERT_DRINK, "18e. alarm dipulihkan, tidak dibunuh tekan-lepas");

    // 19. K3: kalibrasi (Simpan Gelas) saat gelas BERISI di tatakan tidak boleh
    //     memicu isi ulang palsu 250 g.
    k.setEmptyCupWeight(130.0f);
    CHECK(k.getState() == STATE_ALERT_REFILL && !k.isMissingCup(), "19a. kalibrasi dengan gelas berisi -> ALERT_EMPTY_CUP");
    settle(k, 380, 36000);
    CHECK(k.getRefillCount() == 0 && k.getDrinkCount() == 0 && k.getTotalDrank() == 0.0f && k.getState() == STATE_TIMING && fabs(k.getBaselineWeight() - 380.0f) < 0.01f,
          "19b. gelas berisi 380g saat kalibrasi -> 0 refill palsu, baseline 380, TIMING");

    // 20. K1: tekan-lepas di TIMING tidak boleh menunda timer. Alarm yang ditunda
    //     sekali bisa ditunda berulang kali (pengingat tak pernah bunyi).
    CoasterFSM m;
    m.setEmptyCupWeight(130.0f);
    m.setInterval(15000);
    m.setMaxLiftDuration(10000);
    settle(m, 380, 1000);
    CHECK(m.getState() == STATE_TIMING && fabs(m.getBaselineWeight() - 380.0f) < 0.01f, "20a. siap: TIMING baseline 380");
    settle(m, 415, 12000);
    CHECK(m.getRefillCount() == 1, "20b. tekan +35g stabil -> refill pending tercatat");
    settle(m, 380, 14000);
    CHECK(m.getRefillCount() == 0 && m.getDrinkCount() == 0 && fabs(m.getBaselineWeight() - 380.0f) < 0.01f && m.getState() == STATE_TIMING,
          "20c. lepas tekan -> dibatalkan, timer dipulihkan, tetap TIMING");
    m.update(380, 17700);
    CHECK(m.getState() == STATE_ALERT_DRINK, "20d. 17700-2600 >= 15000 -> alarm tidak tertunda");

    // 21. K3: flag kalibrasi tidak boleh basi — kalibrasi dengan gelas berisi,
    //     gelas diangkat lalu kembali kosong, isi ulang cepat tetap terhitung.
    CoasterFSM n;
    n.setEmptyCupWeight(130.0f);
    n.setInterval(15000);
    n.setMaxLiftDuration(10000);
    settle(n, 380, 1000);
    CHECK(n.getState() == STATE_TIMING && fabs(n.getBaselineWeight() - 380.0f) < 0.01f, "21a. siap: TIMING baseline 380");
    n.setEmptyCupWeight(130.0f);
    CHECK(n.getState() == STATE_ALERT_REFILL && !n.isMissingCup(), "21b. kalibrasi gelas berisi -> ALERT_EMPTY_CUP");
    n.update(0, 3000);
    CHECK(n.getState() == STATE_LIFTED, "21c. diangkat sebelum align selesai -> LIFTED (flag basi)");
    settle(n, 100, 4000);
    CHECK(n.getState() == STATE_ALERT_REFILL && n.getDrinkCount() == 1, "21d. kembali kosong -> ALERT_EMPTY_CUP (minum 30g dari baseline kalibrasi)");
    settle(n, 400, 5700);
    // refill == 1: isi ulang sah. Tanpa re-arm: 0 (align menyerap isi ulang).
    CHECK(n.getRefillCount() == 1 && n.getState() == STATE_TIMING && fabs(n.getBaselineWeight() - 400.0f) < 0.01f,
          "21e. isi ulang cepat setelah lift tetap terhitung");

    printf("\n%s (%d gagal)\n", fails ? "ADA YANG GAGAL" : "SEMUA LULUS", fails);
    return fails ? 1 : 0;
}
