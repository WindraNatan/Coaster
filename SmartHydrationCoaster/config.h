#ifndef CONFIG_H
#define CONFIG_H

#include <Arduino.h>

// Motor di GPIO17 untuk menghindari strapping pin GPIO2.
#define PIN_HX711_DOUT 16
#define PIN_HX711_SCK  4
#define PIN_BUZZER     18
#define PIN_MOTOR      17
#define PIN_DHT        19
#define PIN_LED_ALERT  2     // LED onboard cadangan
#define DHT_TYPE       11

// Kredensial AP portal WiFi (bisa ditimpa lewat secrets.h).
#ifndef PORTAL_AP_NAME
#define PORTAL_AP_NAME "Coaster-Setup"
#endif
#ifndef PORTAL_AP_PASS
#define PORTAL_AP_PASS "coaster123"
#endif

#define BUZZER_ACTIVE_LOW 1   // PNP S8550: LOW aktif, VCC 3V3
#define MOTOR_ACTIVE_LOW  0   // NPN S8050: HIGH aktif, VCC 5V

// Ambang massa (gram), selaras dengan test_simulation.py dan web/fsm.js.
#define CUP_ON_THRESHOLD      35.0f  // hysteresis atas
#define CUP_OFF_THRESHOLD     25.0f  // hysteresis bawah
#define DEFAULT_EMPTY_CUP_G   130.0f
#define MAX_EMPTY_CUP_G       300.0f
#define EMPTY_CUP_TOLERANCE   15.0f
#define MIN_DRINK_DELTA       20.0f
#define REFILL_DELTA          30.0f

#define STABILITY_TIME_MS     1500UL
#define STABILITY_BAND_G      3.0f

// Jendela konfirmasi isi ulang di tatakan untuk menolak pola tekan-lepas.
#define REFILL_CONFIRM_MS     5000UL

#define SAMPLE_INTERVAL_MS    100UL      // 10 Hz
#define DHT_INTERVAL_MS       2000UL     // 0.5 Hz
#define FILTER_WINDOW_SIZE    10
#define BASE_INTERVAL_MS      1800000UL  // 30 menit
#define DEMO_INTERVAL_MS      15000UL
#define MAX_LIFT_DURATION_MS  180000UL
#define DEMO_MAX_LIFT_MS      10000UL

#define WEIGHT_MIN_G          -500.0f
#define WEIGHT_MAX_G          5000.0f

// Terkalibrasi beban acuan 500 g.
#define DEFAULT_CALIBRATION_FACTOR 450.7f

#define MIN_CUSTOM_INTERVAL_MIN 1UL
#define MAX_CUSTOM_INTERVAL_MIN 180UL

// Titik jangkar interpolasi DHT11 (selaras dengan test_simulation.py dan web/fsm.js).
#define TEMP_COLD_C   18.0f
#define TEMP_NORM_C   26.0f
#define TEMP_HOT_C    34.0f
#define K_TEMP_COLD   1.20f
#define K_TEMP_NORMAL 1.00f
#define K_TEMP_HOT    0.50f

#define HUM_DRY_PCT   30.0f
#define HUM_NORM_PCT  50.0f
#define K_HUM_DRY     0.85f
#define K_HUM_NORMAL  1.00f
#define ADAPT_FLOOR_MS 5000UL

// Kredensial opsional dari secrets.h (tidak di-commit); tanpa file ini cloud nonaktif.
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
