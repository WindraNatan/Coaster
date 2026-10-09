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
    if (tempC < 24.0f) {
        kTemp = K_TEMP_COLD;
    } else if (tempC <= 28.0f) {
        kTemp = K_TEMP_NORMAL;
    } else if (tempC <= 32.0f) {
        kTemp = K_TEMP_WARM;
    } else {
        kTemp = K_TEMP_HOT;
    }

    float kHum = (humidityPct < 40.0f) ? K_HUM_DRY : K_HUM_NORMAL;

    float adapted = static_cast<float>(baseIntervalMs) * kTemp * kHum;
    float floorMs = static_cast<float>(ADAPT_FLOOR_MS);
    if (adapted < floorMs) adapted = floorMs;
    return static_cast<uint32_t>(adapted);
}

#endif
