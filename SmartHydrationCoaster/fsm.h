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
          missingCupAlert(false) {}

    void setInterval(uint32_t intervalMs) { monitorIntervalMs = intervalMs; }

    void setMaxLiftDuration(uint32_t maxLiftMs) { maxLiftDurationMs = maxLiftMs; }

    void setEmptyCupWeight(float weightG) {
        if (weightG >= CUP_ON_THRESHOLD && weightG <= MAX_EMPTY_CUP_G) {
            emptyCupWeight = weightG;
        }
    }

    float getEmptyCupWeight() const { return emptyCupWeight; }

    void resetDailyStats() {
        totalDrankGrams = 0.0f;
        drinkCount = 0;
        cheatCount = 0;
        refillCount = 0;
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
                    if (isStable(currentWeight, nowMs)) {
                        baselineWeight = currentWeight;
                        timerStartMs = nowMs;
                        refillCount++;
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
                        recordDrink(baselineWeight - currentWeight);
                        baselineWeight = currentWeight;
                        if (currentWeight <= emptyLimit) {
                            missingCupAlert = false;
                            enterState(STATE_ALERT_REFILL, currentWeight, nowMs);
                        } else {
                            timerStartMs = nowMs;
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
                        baselineWeight = currentWeight;
                        timerStartMs = nowMs;
                        refillCount++;
                        enterState(STATE_TIMING, currentWeight, nowMs);
                    }
                    break;
                }
                if (baselineWeight - currentWeight >= MIN_DRINK_DELTA) {
                    // Fix C4: gerbang stabilitas sebelum mencatat minum
                    if (isStable(currentWeight, nowMs)) {
                        recordDrink(baselineWeight - currentWeight);
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
                }
                break;

            case STATE_ALERT_REFILL:
                if (currentWeight < CUP_OFF_THRESHOLD) {
                    if (!missingCupAlert) {
                        // gelas kosong diangkat untuk diisi: alarm ikut ke LIFTED,
                        // dan jika melebihi batas waktu menjadi MISSING_CUP.
                        liftStartMs = nowMs;
                        enterState(STATE_LIFTED, currentWeight, nowMs);
                    }
                    // Kasus MISSING_CUP: gelas memang tidak ada; alarm tetap sampai gelas kembali.
                    break;
                }
                if (currentWeight > emptyLimit) {
                    // Fix M4: jalur pemulihan untuk MISSING_CUP. Gelas kembali berisi air
                    // menyelesaikan baik EMPTY_CUP maupun MISSING_CUP lewat satu pintu ini.
                    if (isStable(currentWeight, nowMs)) {
                        float decreased = baselineWeight - currentWeight;
                        if (decreased >= MIN_DRINK_DELTA) {
                            recordDrink(decreased);
                        } else {
                            refillCount++;
                        }
                        baselineWeight = currentWeight;
                        timerStartMs = nowMs;
                        missingCupAlert = false;
                        enterState(STATE_TIMING, currentWeight, nowMs);
                    }
                } else {
                    // Gelas kosong ditaruh saat alarm MISSING: alarm tetap aktif,
                    // hanya berganti alasan menjadi gelas kosong.
                    missingCupAlert = false;
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

    void recordDrink(float grams) {
        totalDrankGrams += grams;
        drinkCount++;
    }

    void evaluateReturnedCup(float currentWeight, float emptyLimit, uint32_t nowMs) {
        float decreased = baselineWeight - currentWeight;
        float increased = currentWeight - baselineWeight;

        if (currentWeight <= emptyLimit) {
            if (decreased >= MIN_DRINK_DELTA) {
                recordDrink(decreased);
            }
            baselineWeight = currentWeight;
            missingCupAlert = false;
            enterState(STATE_ALERT_REFILL, currentWeight, nowMs);
            return;
        }

        if (increased >= REFILL_DELTA) {
            baselineWeight = currentWeight;
            timerStartMs = nowMs;
            refillCount++;
            enterState(STATE_TIMING, currentWeight, nowMs);
            return;
        }

        if (decreased >= MIN_DRINK_DELTA) {
            recordDrink(decreased);
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
};

#endif
