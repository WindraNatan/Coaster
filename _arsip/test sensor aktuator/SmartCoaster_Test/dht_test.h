#pragma once
#include "DHT.h"
#define DHTPIN 19
#define DHTTYPE DHT11 // ganti ke DHT22 jika pakai DHT22

inline DHT dht(DHTPIN, DHTTYPE);

inline void dht_begin() { dht.begin(); }

inline void dht_test() {
  float h = dht.readHumidity();
  float t = dht.readTemperature();
  if (isnan(h) || isnan(t)) {
    Serial.println("[DHT] gagal baca - cek DATA->GPIO19");
    return;
  }
  Serial.print("[DHT] "); Serial.print(t); Serial.print("C ");
  Serial.print(h); Serial.println("%");
  // ponytail: ambang deterministik saja, fuzzy nyusul di kode utama
  if (t > 30) Serial.println(" -> PANAS interval 60m");
  else if (t >= 26) Serial.println(" -> HANGAT interval 90m");
  else Serial.println(" -> NORMAL interval 120m");
}
