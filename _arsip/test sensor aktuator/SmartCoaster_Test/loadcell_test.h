#pragma once
#include <HX711.h>

#define LOADCELL_DOUT_PIN 16
#define LOADCELL_SCK_PIN  4

inline HX711 coaster_scale;
inline float coaster_cal_factor = -420.0f;

inline void loadcell_begin() {
  coaster_scale.begin(LOADCELL_DOUT_PIN, LOADCELL_SCK_PIN);
  if (coaster_scale.wait_ready_timeout(1000)) {
    coaster_scale.set_scale(coaster_cal_factor);
    coaster_scale.tare(10);
  }
}

inline void loadcell_test() {
  Serial.println("[LOADCELL] Membaca data load cell 5 kg...");
  if (!coaster_scale.wait_ready_timeout(1000)) {
    Serial.println("[LOADCELL] Gagal membaca HX711. Cek kabel DOUT->GPIO16 dan SCK->GPIO4.");
    return;
  }
  long raw = coaster_scale.read();
  float weight = coaster_scale.get_units(5);
  Serial.print("[LOADCELL] Raw ADC: ");
  Serial.print(raw);
  Serial.print(" | Massa Terbaca: ");
  Serial.print(weight, 1);
  Serial.println(" g");
}
