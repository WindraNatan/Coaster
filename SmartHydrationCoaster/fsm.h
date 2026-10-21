#ifndef FSM_H
#define FSM_H

#include <stdint.h>
#include "config.h"

enum CoasterState {
    STATE_IDLE,
    STATE_STABLE,
    STATE_TIMING,
    STATE_LIFTED,
    STATE_ALERT_DRINK,
    STATE_ALERT_CHEAT,
    STATE_ALERT_REFILL
};

// Fix C1: stabilitas dihitung per WAKTU (STABILITY_TIME_MS), bukan per pemanggilan
// update(). Fix C2: timer stabilitas di-reset di setiap transisi state.
// Fix C4: semua keputusan berbasis delta berat (minum / isi ulang) menunggu berat
// baru stabil dulu. Tanpa gerbang ini, penurunan saat mengangkat gelas terbaca
// sebagai deretan minum palsu.
class CoasterFSM {
public:
    CoasterFSM()
        : currentState(STATE_IDLE),
          baselineWeight(0.0f),
          emptyCupWeight(DEFAULT_EMPTY_CUP_G),
          timerStartMs(0),
          liftStartMs(0),
          monitorIntervalMs(BASE_INTERVAL_MS),
          maxLiftDurationMs(MAX_LIFT_DURATION_MS),
          stableCandidateWeight(0.0f),
          stableStartMs(0),
          totalDrankGrams(0.0f),
          drinkCount(0),
          cheatCount(0),
          refillCount(0),
          missingCupAlert(false),
          refillPending(false),
          preRefillBaseline(0.0f),
          lastRefillMs(0),
          calibrationAlign(false),
          preRefillState(STATE_IDLE),
          preRefillTimerStartMs(0) {}

    void setInterval(uint32_t intervalMs) { monitorIntervalMs = intervalMs; }

    void setMaxLiftDuration(uint32_t maxLiftMs) { maxLiftDurationMs = maxLiftMs; }

    bool setEmptyCupWeight(float weightG) {
        if (weightG >= CUP_ON_THRESHOLD && weightG <= MAX_EMPTY_CUP_G) {
            emptyCupWeight = weightG;
            baselineWeight = weightG;
            if (currentState != STATE_IDLE) {
                missingCupAlert = false;
                // K3: setter memaksa ALERT_REFILL tanpa tahu isi gelas. Tandai
                // supaya update() menyelaraskan baseline ke berat aktual dulu,
                // tidak menghitung isi ulang untuk air yang sudah ada di gelas.
                calibrationAlign = true;
                currentState = STATE_ALERT_REFILL;
            }
            return true;
        }
        return false;
    }

    float getEmptyCupWeight() const { return emptyCupWeight; }

    void resetDailyStats() {
        totalDrankGrams = 0.0f;
        drinkCount = 0;
        cheatCount = 0;
        refillCount = 0;
    }

    void restoreDailyStats(float totalMl, uint16_t drinks, uint16_t refills, uint16_t cheats) {
        totalDrankGrams = totalMl >= 0.0f ? totalMl : 0.0f;
        drinkCount = drinks;
        refillCount = refills;
        cheatCount = cheats;
    }

    void update(float currentWeight, uint32_t nowMs) {
        float emptyLimit = emptyCupWeight + EMPTY_CUP_TOLERANCE;

        switch (currentState) {
            case STATE_IDLE:
                missingCupAlert = false;
                if (currentWeight >= CUP_ON_THRESHOLD) {
                    enterState(STATE_STABLE, currentWeight, nowMs);
                }
                break;

            case STATE_STABLE:
                if (currentWeight < CUP_OFF_THRESHOLD) {
                    enterState(STATE_IDLE, currentWeight, nowMs);
                    break;
                }
                if (isStable(currentWeight, nowMs)) {
                    baselineWeight = currentWeight;
                    if (currentWeight <= emptyLimit) {
                        missingCupAlert = false;
                        enterState(STATE_ALERT_REFILL, currentWeight, nowMs);
                    } else {
                        timerStartMs = nowMs;
                        enterState(STATE_TIMING, currentWeight, nowMs);
                    }
                }
                break;

            case STATE_TIMING:
                if (currentWeight < CUP_OFF_THRESHOLD) {
                    liftStartMs = nowMs;
                    enterState(STATE_LIFTED, currentWeight, nowMs);
                    break;
                }
                if (currentWeight - baselineWeight >= REFILL_DELTA) {
                    // Isi ulang langsung di atas tatakan (PRD skenario 8).
                    // Fix C4: keputusan baru sah setelah berat BARU stabil. Tanpa ini,
                    // hentakan peletakan dan tekanan jari ikut terbaca sebagai isi ulang.
                    // K1: dicatat sebagai pending sampai terbukti bertahan
                    // (lihat registerRefill/refillReversed).
                    if (isStable(currentWeight, nowMs)) {
                        registerRefill(baselineWeight, currentWeight, nowMs);
                    }
                    break;
                }
                if (baselineWeight - currentWeight >= MIN_DRINK_DELTA) {
                    // Fix C4: gerbang stabilitas WAJIB. Mengangkat gelas menurunkan
                    // berat ~46 g per sampel (10 Hz), dan tanpa gerbang ini setiap
                    // sampel turun dicatat sebagai satu kali minum: 4-5 minum palsu
                    // per pengangkatan, timer terus ter-reset, baseline rusak, dan
                    // cabang ALERT_CHEAT jadi mustahil tercapai.
                    if (isStable(currentWeight, nowMs)) {
                        // K1: bila ini penurunan kembali setelah isi ulang pending
                        // (tekan-lepas), recordDrink membatalkan isi ulangnya dan
                        // minum tidak dicatat.
                        if (recordDrink(baselineWeight - currentWeight, currentWeight, nowMs)) {
                            baselineWeight = currentWeight;
                            if (currentWeight <= emptyLimit) {
                                missingCupAlert = false;
                                enterState(STATE_ALERT_REFILL, currentWeight, nowMs);
                            } else {
                                timerStartMs = nowMs;
                            }
                        }
                    }
                    break;
                }
                if (nowMs - timerStartMs >= monitorIntervalMs) {
                    enterState(STATE_ALERT_DRINK, currentWeight, nowMs);
                }
                break;

            case STATE_LIFTED:
                if (currentWeight >= CUP_ON_THRESHOLD) {
                    if (isStable(currentWeight, nowMs)) {
                        evaluateReturnedCup(currentWeight, emptyLimit, nowMs);
                    }
                } else {
                    if (nowMs - liftStartMs >= maxLiftDurationMs) {
                        missingCupAlert = true;
                        enterState(STATE_ALERT_REFILL, currentWeight, nowMs);
                    }
                }
                break;

            case STATE_ALERT_DRINK:
            case STATE_ALERT_CHEAT:
                if (currentWeight < CUP_OFF_THRESHOLD) {
                    liftStartMs = nowMs;
                    enterState(STATE_LIFTED, currentWeight, nowMs);
                    break;
                }
                if (currentWeight - baselineWeight >= REFILL_DELTA) {
                    // Fix C4: sama seperti TIMING, tunggu berat baru stabil
                    if (isStable(currentWeight, nowMs)) {
                        registerRefill(baselineWeight, currentWeight, nowMs);
                        enterState(STATE_TIMING, currentWeight, nowMs);
                    }
                    break;
                }
                if (baselineWeight - currentWeight >= MIN_DRINK_DELTA) {
                    // Fix C4: gerbang stabilitas sebelum mencatat minum
                    if (isStable(currentWeight, nowMs)) {
                        // K1: false = tekan-lepas terdeteksi, isi ulang pending
                        // dibatalkan dan minum tidak dicatat.
                        if (recordDrink(baselineWeight - currentWeight, currentWeight, nowMs)) {
                            baselineWeight = currentWeight;
                            if (currentWeight <= emptyLimit) {
                                missingCupAlert = false;
                                enterState(STATE_ALERT_REFILL, currentWeight, nowMs);
                            } else {
                                timerStartMs = nowMs;
                                enterState(STATE_TIMING, currentWeight, nowMs);
                            }
                        }
                    }
                    break;
                }
                break;

            case STATE_ALERT_REFILL:
                if (missingCupAlert) {
                    if (currentWeight >= CUP_ON_THRESHOLD && isStable(currentWeight, nowMs)) {
                        evaluateReturnedCup(currentWeight, emptyLimit, nowMs);
                    }
                    break;
                }
                if (currentWeight < CUP_OFF_THRESHOLD) {
                    liftStartMs = nowMs;
                    enterState(STATE_LIFTED, currentWeight, nowMs);
                    break;
                }
                if (currentWeight <= emptyLimit) {
                    // K3: gelas kosong teramati di state ini. Kalibrasi dapat
                    // memaksa state ini dengan gelas berisi (calibrationAlign);
                    // bila gelas lalu diangkat, flag itu basi dan menekan
                    // refillCount yang sah. Berat kosong = aman menghitung isi
                    // ulang lagi.
                    calibrationAlign = false;
                    break;
                }
                if (calibrationAlign) {
                    // K3: setEmptyCupWeight memaksa ALERT_REFILL tanpa tahu isi
                    // gelas. Bila berat aktual jauh di atas batas kosong, air itu
                    // sudah ada sebelum kalibrasi: selaraskan baseline ke berat
                    // aktual, jangan hitung isi ulang.
                    if (isStable(currentWeight, nowMs)) {
                        calibrationAlign = false;
                        if (currentWeight > emptyLimit) {
                            baselineWeight = currentWeight;
                            timerStartMs = nowMs;
                            enterState(STATE_TIMING, currentWeight, nowMs);
                        }
                    }
                    break;
                }
                if (currentWeight > emptyLimit && isStable(currentWeight, nowMs)) {
                    registerRefill(baselineWeight, currentWeight, nowMs);
                    enterState(STATE_TIMING, currentWeight, nowMs);
                }
                break;
        }
    }

    CoasterState getState() const { return currentState; }
    float getBaselineWeight() const { return baselineWeight; }
    float getTotalDrank() const { return totalDrankGrams; }
    uint16_t getDrinkCount() const { return drinkCount; }
    uint16_t getCheatCount() const { return cheatCount; }
    uint16_t getRefillCount() const { return refillCount; }
    uint32_t getTargetIntervalMs() const { return monitorIntervalMs; }
    bool isMissingCup() const { return missingCupAlert; }

    float getWaterVolumeMl(float currentWeight) const {
        if (currentWeight <= emptyCupWeight) return 0.0f;
        return currentWeight - emptyCupWeight;
    }

    bool isAlertActive() const {
        return currentState == STATE_ALERT_DRINK ||
               currentState == STATE_ALERT_CHEAT ||
               currentState == STATE_ALERT_REFILL;
    }

    uint32_t getRemainingTimeMs(uint32_t nowMs) const {
        if (currentState != STATE_TIMING) return 0;
        uint32_t elapsed = nowMs - timerStartMs;
        if (elapsed >= monitorIntervalMs) return 0;
        return monitorIntervalMs - elapsed;
    }

    const char* getStateString() const {
        switch (currentState) {
            case STATE_IDLE:         return "IDLE";
            case STATE_STABLE:       return "STABLE";
            case STATE_TIMING:       return "TIMING";
            case STATE_LIFTED:       return "LIFTED";
            case STATE_ALERT_DRINK:  return "ALERT_DRINK";
            case STATE_ALERT_CHEAT:  return "ALERT_CHEAT";
            case STATE_ALERT_REFILL: return missingCupAlert ? "ALERT_MISSING_CUP" : "ALERT_EMPTY_CUP";
            default:                 return "UNKNOWN";
        }
    }

private:
    // C1: stabil = berat bertahan dalam +-STABILITY_BAND_G selama STABILITY_TIME_MS
    bool isStable(float currentWeight, uint32_t nowMs) {
        if (currentWeight - stableCandidateWeight > STABILITY_BAND_G ||
            stableCandidateWeight - currentWeight > STABILITY_BAND_G) {
            stableCandidateWeight = currentWeight;
            stableStartMs = nowMs;
            return false;
        }
        return (nowMs - stableStartMs) >= STABILITY_TIME_MS;
    }

    // C2: setiap transisi state men-reset timer & kandidat stabilitas
    void enterState(CoasterState next, float currentWeight, uint32_t nowMs) {
        currentState = next;
        stableCandidateWeight = currentWeight;
        stableStartMs = nowMs;
    }

    // K1: isi ulang langsung di tatakan hanya sah jika berat baru bertahan
    // melewati REFILL_CONFIRM_MS. Load cell tidak bisa membedakan tuangan dari
    // jari yang menekan, tapi tuangan tidak pernah kembali ke baseline lama;
    // tekan-lepas ya. Ini heuristik: menekan lebih lama dari REFILL_CONFIRM_MS
    // tetap lolos. Batas absolut butuh mengunci isi ulang ke state LIFTED
    // (menghilangkan PRD skenario 8).
    bool refillReversed(float currentWeight, uint32_t nowMs) {
        if (!refillPending || nowMs - lastRefillMs > REFILL_CONFIRM_MS) return false;
        float diff = currentWeight - preRefillBaseline;
        return diff <= STABILITY_BAND_G && diff >= -STABILITY_BAND_G;
    }

    void registerRefill(float oldBaseline, float newWeight, uint32_t nowMs) {
        // K1: simpan state & timer pra-isi-ulang supaya pembatalan (tekan-lepas)
        // bisa memulihkannya — lihat cancelPendingRefill.
        preRefillState = currentState;
        preRefillTimerStartMs = timerStartMs;
        baselineWeight = newWeight;
        timerStartMs = nowMs;
        refillCount++;
        refillPending = true;
        preRefillBaseline = oldBaseline;
        lastRefillMs = nowMs;
    }

    void cancelPendingRefill(uint32_t nowMs) {
        refillCount--;
        refillPending = false;
        baselineWeight = preRefillBaseline;
        // K1: pulihkan state & timer pra-tekanan. Tanpa ini, tekan-lepas
        // membunuh alarm minum sampai interval penuh berikutnya dan menekan
        // berulang menunda pengingat tanpa batas. LIFTED/ALERT_REFILL sengaja
        // tidak dipulihkan: gelas sudah kembali di tatakan, memulihkan LIFTED
        // mengevaluasi ulang kembalinya gelas (cheat palsu) dan memulihkan
        // ALERT_REFILL bisa menyangkutkan gelas penuh di alarm kosong.
        if (preRefillState == STATE_TIMING ||
            preRefillState == STATE_ALERT_DRINK ||
            preRefillState == STATE_ALERT_CHEAT) {
            currentState = preRefillState;
            timerStartMs = preRefillTimerStartMs;
        } else {
            timerStartMs = nowMs;
        }
    }

    // Mengembalikan false bila minum dibatalkan karena pola tekan-lepas.
    bool recordDrink(float grams, float currentWeight, uint32_t nowMs) {
        if (refillReversed(currentWeight, nowMs)) {
            cancelPendingRefill(nowMs);
            return false;
        }
        refillPending = false;
        totalDrankGrams += grams;
        drinkCount++;
        return true;
    }

    void evaluateReturnedCup(float currentWeight, float emptyLimit, uint32_t nowMs) {
        float decreased = baselineWeight - currentWeight;
        float increased = currentWeight - baselineWeight;
        missingCupAlert = false;

        if (currentWeight <= emptyLimit) {
            if (decreased >= MIN_DRINK_DELTA) {
                // K1: false = tekan-lepas, isi ulang pending sudah dibatalkan
                recordDrink(decreased, currentWeight, nowMs);
            }
            baselineWeight = currentWeight;
            enterState(STATE_ALERT_REFILL, currentWeight, nowMs);
            return;
        }

        if (increased >= REFILL_DELTA) {
            registerRefill(baselineWeight, currentWeight, nowMs);
            enterState(STATE_TIMING, currentWeight, nowMs);
            return;
        }

        if (decreased >= MIN_DRINK_DELTA) {
            // K1: bila false, ini tekan-lepas: isi ulang pending sudah
            // dibatalkan di dalam recordDrink, baseline pulih ke berat
            // pra-tekanan, minum tidak dicatat.
            recordDrink(decreased, currentWeight, nowMs);
            baselineWeight = currentWeight;
            timerStartMs = nowMs;
            enterState(STATE_TIMING, currentWeight, nowMs);
            return;
        }

        cheatCount++;
        enterState(STATE_ALERT_CHEAT, currentWeight, nowMs);
    }

    CoasterState currentState;
    float baselineWeight;
    float emptyCupWeight;
    uint32_t timerStartMs;
    uint32_t liftStartMs;
    uint32_t monitorIntervalMs;
    uint32_t maxLiftDurationMs;
    float stableCandidateWeight;
    uint32_t stableStartMs;
    float totalDrankGrams;
    uint16_t drinkCount;
    uint16_t cheatCount;
    uint16_t refillCount;
    bool missingCupAlert;
    bool refillPending;
    float preRefillBaseline;
    uint32_t lastRefillMs;
    bool calibrationAlign;
    CoasterState preRefillState;
    uint32_t preRefillTimerStartMs;
};

#endif
