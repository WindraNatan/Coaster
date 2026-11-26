#include "config.h"
#include "filter.h"
#include "fsm.h"
#include "adaptive_controller.h"
#include "cloud_sync.h"
#include <HX711.h>
#include <DHT.h>
#if defined(ESP32)
#include <Preferences.h>
#include <WiFiManager.h>
Preferences prefs;
#endif

HX711 scale;
DHT dht(PIN_DHT, DHT_TYPE);
MovingAverageFilter weightFilter;
CoasterFSM fsm;

uint32_t lastSampleTime = 0;
uint32_t lastDhtTime = 0;
uint32_t lastTelemetryTime = 0;
uint32_t lastCloudSnapTime = 0;
uint32_t lastActuatorToggle = 0;
uint32_t lastBadWeightWarn = 0;
bool alertModeActive = false;

float roomTempC = 27.0f;
float roomHumidity = 60.0f;
bool actuatorOutputState = false;
bool demoMode = true;
bool autoDhtTimerMode = true;
bool buzzerMuted = false;
// Core 0 mengunggah config saat flag ini aktif; PATCH di Core 1 memblokir sampling 10 Hz.
volatile bool configDirty = false;
bool standbyActive = false;
uint32_t customBaseIntervalMs = BASE_INTERVAL_MS;
uint64_t lastHandledTareAt = 0ULL;

uint16_t prevDrinkCnt = 0;
uint16_t prevRefillCnt = 0;
uint16_t prevCheatCnt = 0;

inline void writeActuator(uint8_t pin, bool on, bool activeLow) {
    digitalWrite(pin, (on != activeLow) ? HIGH : LOW);
}

void saveConfigToNvs() {
    configDirty = true;
#if defined(ESP32)
    prefs.begin("shc", false);
    prefs.putFloat("emptyCup", fsm.getEmptyCupWeight());
    prefs.putULong("baseMs", customBaseIntervalMs);
    prefs.putBool("demo", demoMode);
    prefs.putBool("autoDht", autoDhtTimerMode);
    prefs.putBool("muted", buzzerMuted);
    prefs.end();
#endif
}

void saveStatsToNvs() {
#if defined(ESP32)
    prefs.begin("shc", false);
    prefs.putFloat("totalMl", fsm.getTotalDrank());
    prefs.putUShort("drinkCnt", fsm.getDrinkCount());
    prefs.putUShort("refillCnt", fsm.getRefillCount());
    prefs.putUShort("cheatCnt", fsm.getCheatCount());
    prefs.end();
#endif
    prevDrinkCnt = fsm.getDrinkCount();
    prevRefillCnt = fsm.getRefillCount();
    prevCheatCnt = fsm.getCheatCount();
}

void loadFromNvs(String& outSsid, String& outPass, String& outUrl) {
#if defined(ESP32)
    prefs.begin("shc", true);
    float emptyCup = prefs.getFloat("emptyCup", DEFAULT_EMPTY_CUP_G);
    customBaseIntervalMs = prefs.getULong("baseMs", BASE_INTERVAL_MS);
    // Default mode normal (30 menit), bukan demo 15 detik.
    demoMode = prefs.getBool("demo", false);
    autoDhtTimerMode = prefs.getBool("autoDht", true);
    buzzerMuted = prefs.getBool("muted", false);
    lastHandledTareAt = prefs.getULong64("lastTareAt", 0ULL);

    float totalMl = prefs.getFloat("totalMl", 0.0f);
    uint16_t dCnt = prefs.getUShort("drinkCnt", 0);
    uint16_t rCnt = prefs.getUShort("refillCnt", 0);
    uint16_t cCnt = prefs.getUShort("cheatCnt", 0);

    outSsid = prefs.getString("wifiSsid", WIFI_SSID);
    outPass = prefs.getString("wifiPass", WIFI_PASSWORD);
    outUrl = prefs.getString("fbUrl", FIREBASE_DB_URL);
    prefs.end();

    fsm.setEmptyCupWeight(emptyCup);
    fsm.restoreDailyStats(totalMl, dCnt, rCnt, cCnt);
    prevDrinkCnt = dCnt;
    prevRefillCnt = rCnt;
    prevCheatCnt = cCnt;
#endif
}

void handleActuators(CoasterState state, uint32_t nowMs) {
    bool alertActive = fsm.isAlertActive();
    if (alertActive != alertModeActive) {
        alertModeActive = alertActive;
        actuatorOutputState = alertActive;
        lastActuatorToggle = nowMs;
    }

    if (!alertActive) {
        writeActuator(PIN_BUZZER, false, BUZZER_ACTIVE_LOW);
        writeActuator(PIN_MOTOR, false, MOTOR_ACTIVE_LOW);
        writeActuator(PIN_LED_ALERT, false, false);
        return;
    }

    uint32_t togglePeriodMs = 500UL;
    if (state == STATE_ALERT_CHEAT) {
        togglePeriodMs = 150UL;
    } else if (state == STATE_ALERT_REFILL) {
        togglePeriodMs = 750UL;
    }

    if (nowMs - lastActuatorToggle >= togglePeriodMs) {
        lastActuatorToggle = nowMs;
        actuatorOutputState = !actuatorOutputState;
    }
    writeActuator(PIN_BUZZER, buzzerMuted ? false : actuatorOutputState, BUZZER_ACTIVE_LOW);
    writeActuator(PIN_MOTOR, actuatorOutputState, MOTOR_ACTIVE_LOW);
    writeActuator(PIN_LED_ALERT, actuatorOutputState, false);
}

void updateAdaptiveInterval() {
    uint32_t baseMs = demoMode ? DEMO_INTERVAL_MS : customBaseIntervalMs;
    // Mode demo tidak dikompensasi DHT11 agar 15 detik tidak menyusut akibat panas board.
    if (autoDhtTimerMode && !demoMode) {
        fsm.setInterval(computeAdaptiveIntervalMs(baseMs, roomTempC, roomHumidity));
    } else {
        fsm.setInterval(baseMs);
    }
    fsm.setMaxLiftDuration(demoMode ? DEMO_MAX_LIFT_MS : MAX_LIFT_DURATION_MS);
}

void printTelemetry(float filteredWeight, uint32_t nowMs) {
    Serial.print(F("State: "));
    Serial.print(fsm.getStateString());
    Serial.print(F(" | Berat: "));
    Serial.print(filteredWeight, 1);
    Serial.print(F("g | Air: "));
    Serial.print(fsm.getWaterVolumeMl(filteredWeight), 1);
    Serial.print(F("ml | Suhu: "));
    Serial.print(roomTempC, 1);
    Serial.print(F("C | RH: "));
    Serial.print(roomHumidity, 0);
    Serial.print(F("% | SisaWaktu: "));
    Serial.print(fsm.getRemainingTimeMs(nowMs) / 1000);
    Serial.print(F("s | Diminum: "));
    Serial.print(fsm.getTotalDrank(), 1);
    Serial.print(F("ml | Minum: "));
    Serial.print(fsm.getDrinkCount());
    Serial.print(F("x | Cheat: "));
    Serial.print(fsm.getCheatCount());
    Serial.print(F(" | Refill: "));
    Serial.print(fsm.getRefillCount());
    Serial.print(F("x | Target: "));
    Serial.print(fsm.getTargetIntervalMs() / 1000);
    Serial.print(F("s | Mode: "));
    Serial.print(demoMode ? F("DEMO-") : F("NORM-"));
    Serial.print(autoDhtTimerMode ? F("AUTO") : F("MANUAL"));
    Serial.print(F(" | Buzzer: "));
    Serial.print(buzzerMuted ? F("MUTE") : F("ON"));
    Serial.print(F(" | Sesi: "));
    Serial.println(standbyActive ? F("TIDUR") : F("AKTIF"));
}

void handleSerialCommands(float currentFilteredWeight) {
    if (!Serial.available()) return;
    char cmd = Serial.read();

    if (cmd == 't' || cmd == 'T') {
        Serial.println(F("[AKSI] Tare titik nol tatakan..."));
        scale.tare(20);
        weightFilter.reset();
    } else if (cmd == 'c' || cmd == 'C') {
        if (currentFilteredWeight > MAX_EMPTY_CUP_G || currentFilteredWeight < CUP_ON_THRESHOLD) {
            Serial.print(F("[DITOLAK] Berat "));
            Serial.print(currentFilteredWeight, 1);
            Serial.println(F("g di luar rentang gelas kosong (35-300g)."));
        } else {
            fsm.setEmptyCupWeight(currentFilteredWeight);
            saveConfigToNvs();
            Serial.print(F("[KONFIG] Berat gelas kosong disimpan: "));
            Serial.print(fsm.getEmptyCupWeight(), 1);
            Serial.println(F(" gram."));
        }
    } else if (cmd == 'e' || cmd == 'E') {
        float g = Serial.parseFloat();
        if (fsm.setEmptyCupWeight(g)) {
            saveConfigToNvs();
            Serial.print(F("[KONFIG] Berat gelas kosong disimpan: "));
            Serial.print(fsm.getEmptyCupWeight(), 1);
            Serial.println(F(" gram."));
        } else {
            Serial.println(F("[DITOLAK] Nilai gelas kosong wajib 35-300g."));
        }
    } else if (cmd == 'i' || cmd == 'I') {
        long m = Serial.parseInt();
        if (m >= (long)MIN_CUSTOM_INTERVAL_MIN && m <= (long)MAX_CUSTOM_INTERVAL_MIN) {
            customBaseIntervalMs = (uint32_t)m * 60000UL;
            demoMode = false;
            updateAdaptiveInterval();
            saveConfigToNvs();
            Serial.print(F("[KONFIG] Interval dasar diatur ke: "));
            Serial.print(m);
            Serial.println(F(" menit (Mode Normal)."));
        } else {
            Serial.println(F("[DITOLAK] Interval wajib 1-180 menit (contoh: i25)."));
        }
    } else if (cmd == 'd' || cmd == 'D') {
        demoMode = !demoMode;
        updateAdaptiveInterval();
        saveConfigToNvs();
        Serial.print(F("[KONFIG] Mode Demo: "));
        if (demoMode) {
            Serial.println(F("AKTIF (15 detik)"));
        } else {
            Serial.print(F("NONAKTIF ("));
            Serial.print(customBaseIntervalMs / 60000UL);
            Serial.println(F(" menit)"));
        }
    } else if (cmd == 'm' || cmd == 'M') {
        autoDhtTimerMode = !autoDhtTimerMode;
        updateAdaptiveInterval();
        saveConfigToNvs();
        Serial.print(F("[KONFIG] Mode Timer: "));
        Serial.println(autoDhtTimerMode ? F("OTOMATIS (Adaptif DHT11)") : F("MANUAL"));
    } else if (cmd == 'q' || cmd == 'Q') {
        buzzerMuted = !buzzerMuted;
        saveConfigToNvs();
        Serial.print(F("[KONFIG] Mode Suara Buzzer: "));
        Serial.println(buzzerMuted ? F("HENING (Getar Saja)") : F("AKTIF (Suara + Getar)"));
    } else if (cmd == 'r' || cmd == 'R') {
        fsm.resetDailyStats();
        saveStatsToNvs();
        Serial.println(F("[AKSI] Statistik harian di-reset ke nol."));
    } else if (cmd == 'w' || cmd == 'W') {
        String line = Serial.readStringUntil('\n');
        line.trim();
        int sep = line.indexOf('|');
        if (sep > 0) {
            String ssid = line.substring(0, sep);
            String pass = line.substring(sep + 1);
#if defined(ESP32)
            prefs.begin("shc", false);
            prefs.putString("wifiSsid", ssid);
            prefs.putString("wifiPass", pass);
            prefs.end();
#endif
            setCloudWifi(ssid, pass);
            Serial.print(F("[KONFIG] Wi-Fi disimpan & menghubungkan ke SSID: "));
            Serial.println(ssid);
        }
    } else if (cmd == 'f' || cmd == 'F') {
        String url = Serial.readStringUntil('\n');
        url.trim();
        while (url.endsWith("/")) url.remove(url.length() - 1);
        if (url.startsWith("https://")) {
#if defined(ESP32)
            prefs.begin("shc", false);
            prefs.putString("fbUrl", url);
            prefs.end();
#endif
            setCloudFirebaseUrl(url);
            Serial.print(F("[KONFIG] URL Firebase RTDB disimpan: "));
            Serial.println(url);
        } else {
        Serial.println(F("[DITOLAK] URL Firebase wajib diawali https://"));
        }
    } else if (cmd == 'z' || cmd == 'Z') {
        // Pintasan USB untuk mode istirahat tanpa cloud.
        setLocalStandby(true);
        Serial.println(F("[SESI] Diminta tidur dari serial."));
    } else if (cmd == 'x' || cmd == 'X') {
        setLocalStandby(false);
        Serial.println(F("[SESI] Diminta bangun dari serial."));
    }
}

void setup() {
    Serial.begin(115200);
    Serial.setTimeout(30);

    pinMode(PIN_BUZZER, OUTPUT);
    pinMode(PIN_MOTOR, OUTPUT);
    pinMode(PIN_LED_ALERT, OUTPUT);
    writeActuator(PIN_BUZZER, false, BUZZER_ACTIVE_LOW);
    writeActuator(PIN_MOTOR, false, MOTOR_ACTIVE_LOW);

    dht.begin();
    scale.begin(PIN_HX711_DOUT, PIN_HX711_SCK);
    scale.set_scale(DEFAULT_CALIBRATION_FACTOR);
    scale.tare(20);

    String nvsSsid, nvsPass, nvsUrl;
    loadFromNvs(nvsSsid, nvsPass, nvsUrl);
    updateAdaptiveInterval();
    initCloudSync(nvsSsid, nvsPass, nvsUrl);

    Serial.println(F("Smart Hydration Coaster - ESP32 Siap."));
    Serial.println(F("Perintah: 't'=Tare, 'c'=Kalibrasi Gelas, 'e<g>'=Set Gelas, 'i<mnt>'=Interval, 'd'=Demo, 'm'=Auto/Manual, 'q'=Hening, 'r'=Reset, 'z'=Tidur, 'x'=Bangun"));
}

void loop() {
    uint32_t nowMs = millis();
    float filteredWeight = weightFilter.getAverage();

    handleWifiPortal();
    checkWifiStale();

    handleSerialCommands(filteredWeight);

    PendingCloudUpdate cloudUpd;
    if (consumePendingCloudUpdate(cloudUpd)) {
        if (cloudUpd.hasConfig && !configDirty) {
            demoMode = cloudUpd.cfg.demoMode;
            autoDhtTimerMode = cloudUpd.cfg.autoDhtTimerMode;
            buzzerMuted = cloudUpd.cfg.buzzerMuted;
            customBaseIntervalMs = cloudUpd.cfg.customBaseIntervalMs;
            if (fabsf(cloudUpd.cfg.emptyCupWeightG - fsm.getEmptyCupWeight()) > 0.5f) {
                fsm.setEmptyCupWeight(cloudUpd.cfg.emptyCupWeightG);
            }
            updateAdaptiveInterval();
            saveConfigToNvs();
            configDirty = false;
            if (cloudUpd.cfg.tareAt > 0ULL && cloudUpd.cfg.tareAt != lastHandledTareAt) {
                lastHandledTareAt = cloudUpd.cfg.tareAt;
#if defined(ESP32)
                prefs.begin("shc", false);
                prefs.putULong64("lastTareAt", lastHandledTareAt);
                prefs.end();
#endif
                scale.tare(20);
                weightFilter.reset();
                fsm.toIdle(nowMs);
                Serial.println(F("[CLOUD] Perintah tare dijalankan, timbangan dinolkan."));
                lastCloudSnapTime = nowMs;
                updateCloudSnapshot(0.0f, nowMs, roomTempC, roomHumidity, buzzerMuted);
            }
        }
        if (cloudUpd.hasNewSessionOwner) {
#if defined(ESP32)
            prefs.begin("shc", false);
            prefs.putString("sessionOwner", cloudUpd.newSessionOwner);
            prefs.end();
#endif
            fsm.resetDailyStats();
            saveStatsToNvs();
            Serial.printf("[CLOUD] Sesi baru untuk %.8s..., statistik di-reset.\n", cloudUpd.newSessionOwner);
        }
    }

    if (nowMs - lastSampleTime >= SAMPLE_INTERVAL_MS) {
        lastSampleTime = nowMs;
        if (scale.is_ready()) {
            weightFilter.add(scale.get_units(1));
        }
    }

    if (nowMs - lastDhtTime >= DHT_INTERVAL_MS) {
        lastDhtTime = nowMs;
        float t = dht.readTemperature();
        float h = dht.readHumidity();
        if (!isnan(t)) roomTempC = t;
        if (!isnan(h)) roomHumidity = h;
        updateAdaptiveInterval();
    }

    filteredWeight = weightFilter.getAverage();

    bool standbyNow = standbyActiveNow();
    if (standbyNow != standbyActive) {
        standbyActive = standbyNow;
        // Reset ke IDLE agar tidak menyisakan alert/timer basi; handleActuators() mematikan aktuator.
        fsm.toIdle(nowMs);
        handleActuators(fsm.getState(), nowMs);
        if (standbyActive) {
            Serial.println(F("[SESI] Sesi berakhir; alat tidur, alarm dan timer berhenti."));
        } else {
            Serial.println(F("[SESI] Sesi dimulai; alat aktif kembali dari IDLE."));
        }
        lastCloudSnapTime = nowMs;
        updateCloudSnapshot(filteredWeight, nowMs, roomTempC, roomHumidity, buzzerMuted);
    }

    bool weightValid = filteredWeight == filteredWeight &&
                       filteredWeight >= WEIGHT_MIN_G && filteredWeight <= WEIGHT_MAX_G;
    if (standbyActive) {
        // Saat istirahat, lewati penilaian FSM agar tidak memicu siklus atau alarm.
        writeActuator(PIN_BUZZER, false, BUZZER_ACTIVE_LOW);
        writeActuator(PIN_MOTOR, false, MOTOR_ACTIVE_LOW);
        writeActuator(PIN_LED_ALERT, false, false);
    } else if (!weightValid) {
        if (nowMs - lastBadWeightWarn >= 5000) {
            lastBadWeightWarn = nowMs;
            Serial.println(F("[PERINGATAN] Bacaan berat tidak valid (NaN/di luar rentang). Periksa kabel HX711."));
        }
    } else {
        fsm.update(filteredWeight, nowMs);
        if (fsm.getDrinkCount() != prevDrinkCnt ||
            fsm.getRefillCount() != prevRefillCnt ||
            fsm.getCheatCount() != prevCheatCnt) {
            saveStatsToNvs();
        }
    }

    if (!standbyActive) handleActuators(fsm.getState(), nowMs);

    if (nowMs - lastTelemetryTime >= 500) {
        lastTelemetryTime = nowMs;
        printTelemetry(filteredWeight, nowMs);
    }

    if (nowMs - lastCloudSnapTime >= SAMPLE_INTERVAL_MS) {
        lastCloudSnapTime = nowMs;
        updateCloudSnapshot(filteredWeight, nowMs, roomTempC, roomHumidity, buzzerMuted);
    }
}
