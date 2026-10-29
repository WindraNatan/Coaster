#ifndef CONFIG_H
#define CONFIG_H

#include <Arduino.h>

// Pemetaan Pin ESP32 DevKit V1
// Motor sengaja TIDAK di GPIO2 (strapping pin + LED onboard) -> GPIO17.
#define PIN_HX711_DOUT 16
#define PIN_HX711_SCK  4
#define PIN_BUZZER     18
#define PIN_MOTOR      17
#define PIN_DHT        19
#define PIN_LED_ALERT  2     // LED onboard. Tidak dipakai di kit ini; pin tetap ditoggle
                             // supaya board yang punya LED tetap punya indikator.
#define DHT_TYPE       11

// Polaritas aktuator (terverifikasi modul 2026-10-05)
#define BUZZER_ACTIVE_LOW 1   // modul PNP S8550: LOW = bunyi (VCC wajib 3V3)
#define MOTOR_ACTIVE_LOW  0   // modul NPN S8050: HIGH = getar (VCC 5V)

// Ambang Batas Massa (satuan: gram)
#define CUP_ON_THRESHOLD      35.0f  // Hysteresis atas: berat minimal agar gelas terdeteksi hadir
#define CUP_OFF_THRESHOLD     25.0f  // Hysteresis bawah: di bawah ini gelas dianggap diangkat
#define DEFAULT_EMPTY_CUP_G   130.0f // Berat rata-rata gelas kosong standar
#define MAX_EMPTY_CUP_G       300.0f // Batas wajar input berat gelas kosong (proteksi perintah 'c')
#define EMPTY_CUP_TOLERANCE   15.0f  // Gelas kosong: berat <= gelas_kosong + 15g
#define MIN_DRINK_DELTA       20.0f  // Turun minimal agar sah dianggap minum (anti-cheat)
#define REFILL_DELTA          30.0f  // Naik minimal agar dianggap isi ulang

// Stabilitas berbasis waktu (identik di test_simulation.py dan web)
#define STABILITY_TIME_MS     1500UL   // Berat harus bertahan selama 1,5 detik
#define STABILITY_BAND_G      3.0f     // Band +-3 g dari kandidat stabil

// K1: isi ulang langsung di tatakan baru sah setelah berat baru bertahan sekian
// lama. Bila berat kembali ke baseline pra-isi-ulang dalam batas ini, itu pola
// tekan-lepas gelas (load cell tak bisa membedakannya dari tuangan, tapi
// tuangan tidak pernah kembali ke berat lama).
#define REFILL_CONFIRM_MS     5000UL

// Parameter Pewaktuan (satuan: milidetik)
#define SAMPLE_INTERVAL_MS    100UL      // Periode baca Load Cell (10 Hz)
#define DHT_INTERVAL_MS       2000UL     // Periode baca DHT11 (0.5 Hz)
#define FILTER_WINDOW_SIZE    10         // Sampel Moving Average Filter
#define BASE_INTERVAL_MS      1800000UL  // Interval dasar mode normal: 30 menit (dikunci; PRD 4.3)
#define DEMO_INTERVAL_MS      15000UL    // Mode demo kelas: 15 detik
#define MAX_LIFT_DURATION_MS  180000UL   // Batas gelas diangkat: 3 menit
#define DEMO_MAX_LIFT_MS      10000UL    // Batas saat mode demo: 10 detik

// Validasi berat (guard sensor: NaN / kabel lepas / beban tak masuk akal)
#define WEIGHT_MIN_G          -500.0f
#define WEIGHT_MAX_G          5000.0f

// Kalibrasi load cell: terverifikasi fisik dengan beban acuan 500 g -> 450.7f
#define DEFAULT_CALIBRATION_FACTOR 450.7f

#define MIN_CUSTOM_INTERVAL_MIN 1UL
#define MAX_CUSTOM_INTERVAL_MIN 180UL

// Titik jangkar interpolasi kontinu DHT11 (identik di test_simulation.py dan web/index.html)
#define TEMP_COLD_C   18.0f
#define TEMP_NORM_C   26.0f
#define TEMP_HOT_C    34.0f
#define K_TEMP_COLD   1.20f  // T <= 18 C
#define K_TEMP_NORMAL 1.00f  // T == 26 C
#define K_TEMP_HOT    0.50f  // T >= 34 C (pada 30 C bernilai 0.75f)

#define HUM_DRY_PCT   30.0f
#define HUM_NORM_PCT  50.0f
#define K_HUM_DRY     0.85f  // RH <= 30 %
#define K_HUM_NORMAL  1.00f  // RH >= 50 %
#define ADAPT_FLOOR_MS 5000UL

// Kredensial perangkat berasal dari SmartHydrationCoaster/secrets.h, yang TIDAK
// di-commit karena repo ini publik. Salin secrets.h.example lalu isi. Tanpa file itu
// build tetap jalan dan cloud dimatikan, jadi mode USB dan simulator tidak terganggu.
#if __has_include("secrets.h")
#include "secrets.h"
#endif
#ifndef WIFI_SSID
#define WIFI_SSID              ""
#endif
#ifndef WIFI_PASSWORD
#define WIFI_PASSWORD          ""
#endif
#ifndef FIREBASE_DB_URL
#define FIREBASE_DB_URL        ""
#endif
#ifndef FIREBASE_API_KEY
#define FIREBASE_API_KEY       ""
#endif
#ifndef FIREBASE_USER_EMAIL
#define FIREBASE_USER_EMAIL    ""
#endif
#ifndef FIREBASE_USER_PASSWORD
#define FIREBASE_USER_PASSWORD ""
#endif

#endif
