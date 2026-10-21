#ifndef ADAPTIVE_CONTROLLER_H
#define ADAPTIVE_CONTROLLER_H

#include <Arduino.h>
#include "config.h"

// Faktor diambil dari config.h, bukan ditulis ulang di sini. Sebelumnya nilainya
// digandakan secara hardcode di file ini sementara config.h mendefinisikan angka
// yang sama dengan komentar "harus identik dengan test_simulation.py dan web" --
// definenya jadi mati dan setiap perubahan hanya menyentuh satu salinan.
inline uint32_t computeAdaptiveIntervalMs(uint32_t baseIntervalMs, float tempC, float humidityPct) {
    if (isnan(tempC) || isnan(humidityPct)) {
        return baseIntervalMs;
    }

    float kTemp;
    if (tempC <= TEMP_COLD_C) {
        kTemp = K_TEMP_COLD;
    } else if (tempC <= TEMP_NORM_C) {
        kTemp = K_TEMP_COLD - (K_TEMP_COLD - K_TEMP_NORMAL) * ((tempC - TEMP_COLD_C) / (TEMP_NORM_C - TEMP_COLD_C));
    } else if (tempC < TEMP_HOT_C) {
        kTemp = K_TEMP_NORMAL - (K_TEMP_NORMAL - K_TEMP_HOT) * ((tempC - TEMP_NORM_C) / (TEMP_HOT_C - TEMP_NORM_C));
    } else {
        kTemp = K_TEMP_HOT;
    }

    float kHum;
    if (humidityPct <= HUM_DRY_PCT) {
        kHum = K_HUM_DRY;
    } else if (humidityPct < HUM_NORM_PCT) {
        kHum = K_HUM_DRY + (K_HUM_NORMAL - K_HUM_DRY) * ((humidityPct - HUM_DRY_PCT) / (HUM_NORM_PCT - HUM_DRY_PCT));
    } else {
        kHum = K_HUM_NORMAL;
    }

    float adapted = static_cast<float>(baseIntervalMs) * kTemp * kHum;
    float floorMs = static_cast<float>(ADAPT_FLOOR_MS);
    if (adapted < floorMs) adapted = floorMs;
    return static_cast<uint32_t>(adapted + 0.5f);
}

#endif
