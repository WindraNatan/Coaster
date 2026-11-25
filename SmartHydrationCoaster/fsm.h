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

// Mirror 1:1 dengan test_simulation.py dan web/fsm.js; ubah ketiganya bersamaan.
class CoasterFSM {
public:
    CoasterFSM()
        : currentState(STATE_IDLE),
          baselineWeight(0.0f),
          emptyCupWeight(DEFAULT_EMPTY_CUP_G),
          timerStartMs(0),
          liftStartMs(0),
          monitorIntervalMs(BASE_INTERVAL_MS),
          cycleTargetMs(BASE_INTERVAL_MS),
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
          preRefillTimerStartMs(0),
          preRefillCycleTargetMs(0) {}

    void setInterval(uint32_t intervalMs) { monitorIntervalMs = intervalMs; }

    // Kunci target per siklus agar perubahan suhu tidak memicu alarm mendadak.
    void startCycle(uint32_t nowMs) {
        timerStartMs = nowMs;
        cycleTargetMs = monitorIntervalMs;
    }

    // Reset siklus untuk mode istirahat tanpa menghapus statistik harian.
    void toIdle(uint32_t nowMs) {
        currentState = STATE_IDLE;
        missingCupAlert = false;
        refillPending = false;
        calibrationAlign = false;
        stableCandidateWeight = 0.0f;
        stableStartMs = nowMs;
        timerStartMs = nowMs;
        liftStartMs = nowMs;
        cycleTargetMs = monitorIntervalMs;
    }

    void setMaxLiftDuration(uint32_t maxLiftMs) { maxLiftDurationMs = maxLiftMs; }

    bool setEmptyCupWeight(float weightG) {
        if (weightG >= CUP_ON_THRESHOLD && weightG <= MAX_EMPTY_CUP_G) {
            emptyCupWeight = weightG;
            baselineWeight = weightG;
            if (currentState != STATE_IDLE) {
                missingCupAlert = false;
                // Tandai agar update() menyelaraskan baseline tanpa menghitung refill.
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
                        startCycle(nowMs);
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
                    if (isStable(currentWeight, nowMs)) {
                        registerRefill(baselineWeight, currentWeight, nowMs);
                    }
                    break;
                }
                if (baselineWeight - currentWeight >= MIN_DRINK_DELTA) {
                    // Wajib tunggu stabil agar penurunan saat gelas diangkat tidak tercatat sebagai minum.
                    if (isStable(currentWeight, nowMs)) {
                        if (recordDrink(baselineWeight - currentWeight, currentWeight, nowMs)) {
                            baselineWeight = currentWeight;
                            if (currentWeight <= emptyLimit) {
                                missingCupAlert = false;
                                enterState(STATE_ALERT_REFILL, currentWeight, nowMs);
                            } else {
                                startCycle(nowMs);
                            }
                        }
                    }
                    break;
                }
                if (nowMs - timerStartMs >= cycleTargetMs) {
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
                    if (isStable(currentWeight, nowMs)) {
                        registerRefill(baselineWeight, currentWeight, nowMs);
                        enterState(STATE_TIMING, currentWeight, nowMs);
                    }
                    break;
                }
                if (baselineWeight - currentWeight >= MIN_DRINK_DELTA) {
                    if (isStable(currentWeight, nowMs)) {
                        if (recordDrink(baselineWeight - currentWeight, currentWeight, nowMs)) {
                            baselineWeight = currentWeight;
                            if (currentWeight <= emptyLimit) {
                                missingCupAlert = false;
                                enterState(STATE_ALERT_REFILL, currentWeight, nowMs);
                            } else {
                                startCycle(nowMs);
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
                    // Hapus flag kalibrasi begitu gelas benar-benar kosong teramati.
                    calibrationAlign = false;
                    break;
                }
                if (calibrationAlign) {
                    // Selaraskan baseline ke isi gelas yang sudah ada sebelum kalibrasi.
                    if (isStable(currentWeight, nowMs)) {
                        calibrationAlign = false;
                        if (currentWeight > emptyLimit) {
                            baselineWeight = currentWeight;
                            startCycle(nowMs);
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
    uint32_t getTargetIntervalMs() const {
        return currentState == STATE_TIMING ? cycleTargetMs : monitorIntervalMs;
    }
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
        if (elapsed >= cycleTargetMs) return 0;
        return cycleTargetMs - elapsed;
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
    bool isStable(float currentWeight, uint32_t nowMs) {
        if (currentWeight - stableCandidateWeight > STABILITY_BAND_G ||
            stableCandidateWeight - currentWeight > STABILITY_BAND_G) {
            stableCandidateWeight = currentWeight;
            stableStartMs = nowMs;
            return false;
        }
        return (nowMs - stableStartMs) >= STABILITY_TIME_MS;
    }

    void enterState(CoasterState next, float currentWeight, uint32_t nowMs) {
        currentState = next;
        stableCandidateWeight = currentWeight;
        stableStartMs = nowMs;
    }

    // Batalkan refill langsung jika berat kembali ke baseline lama dalam REFILL_CONFIRM_MS.
    // Heuristik tekan-lepas; penekanan lebih lama tetap lolos.
    bool refillReversed(float currentWeight, uint32_t nowMs) {
        if (!refillPending || nowMs - lastRefillMs > REFILL_CONFIRM_MS) return false;
        float diff = currentWeight - preRefillBaseline;
        return diff <= STABILITY_BAND_G && diff >= -STABILITY_BAND_G;
    }

    void registerRefill(float oldBaseline, float newWeight, uint32_t nowMs) {
        preRefillState = currentState;
        preRefillTimerStartMs = timerStartMs;
        preRefillCycleTargetMs = cycleTargetMs;
        baselineWeight = newWeight;
        startCycle(nowMs);
        refillCount++;
        refillPending = true;
        preRefillBaseline = oldBaseline;
        lastRefillMs = nowMs;
    }

    void cancelPendingRefill(uint32_t nowMs) {
        refillCount--;
        refillPending = false;
        baselineWeight = preRefillBaseline;
        // Pulihkan state dan timer pra-tekanan agar tekan-lepas tidak menunda alarm.
        // LIFTED dan ALERT_REFILL dilewati agar tidak memicu evaluasi cheat atau kosong palsu.
        if (preRefillState == STATE_TIMING ||
            preRefillState == STATE_ALERT_DRINK ||
            preRefillState == STATE_ALERT_CHEAT) {
            currentState = preRefillState;
            timerStartMs = preRefillTimerStartMs;
            cycleTargetMs = preRefillCycleTargetMs;
        } else {
            startCycle(nowMs);
        }
    }

    // Kembalikan false jika minum dibatalkan oleh pola tekan-lepas.
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
            recordDrink(decreased, currentWeight, nowMs);
            baselineWeight = currentWeight;
            startCycle(nowMs);
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
    uint32_t cycleTargetMs;
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
    uint32_t preRefillCycleTargetMs;
};

#endif
