#ifndef CLOUD_SYNC_H
#define CLOUD_SYNC_H

#include <Arduino.h>
#include "config.h"
#include "fsm.h"

#if defined(ESP32)
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <Preferences.h>

struct CloudSnapshot {
    float weightG;
    float waterMl;
    float tempC;
    float humPct;
    char stateStr[20];
    uint32_t remSec;
    float targetMin;
    float totalMl;
    uint16_t drinkCnt;
    uint16_t refillCnt;
    uint16_t cheatCnt;
    bool muted;
};

static volatile bool cloudTaskRunning = false;
static CloudSnapshot snap = {};
static portMUX_TYPE snapMux = portMUX_INITIALIZER_UNLOCKED;
static String activeWifiSsid = WIFI_SSID;
static String activeWifiPass = WIFI_PASSWORD;
static String activeFirebaseUrl = FIREBASE_DB_URL;

extern bool demoMode;
extern bool autoDhtTimerMode;
extern bool buzzerMuted;
extern uint32_t customBaseIntervalMs;
extern CoasterFSM fsm;
extern void updateAdaptiveInterval();
extern void saveConfigToNvs();

static float extractJsonFloat(const String& s, const char* key, float fallback) {
    int idx = s.indexOf(key);
    if (idx < 0) return fallback;
    int colon = s.indexOf(':', idx);
    if (colon < 0) return fallback;
    return s.substring(colon + 1).toFloat();
}

static void cloudTask(void*) {
    char lastState[20] = "";
    uint32_t lastPushMs = 0;
    uint32_t lastPollMs = 0;

    for (;;) {
        if (activeFirebaseUrl.length() == 0 || WiFi.status() != WL_CONNECTED) {
            vTaskDelay(pdMS_TO_TICKS(2000));
            continue;
        }

        uint32_t now = millis();
        CloudSnapshot local;
        portENTER_CRITICAL(&snapMux);
        local = snap;
        portEXIT_CRITICAL(&snapMux);

        bool stateChanged = strncmp(local.stateStr, lastState, sizeof(lastState)) != 0;
        if (stateChanged || (now - lastPushMs >= 5000UL)) {
            strncpy(lastState, local.stateStr, sizeof(lastState) - 1);
            lastPushMs = now;

            WiFiClientSecure client;
            client.setInsecure();
            HTTPClient http;
            String url = activeFirebaseUrl + "/smart_coaster/telemetry.json";
            if (http.begin(client, url)) {
                http.addHeader("Content-Type", "application/json");
                char body[360];
                snprintf(body, sizeof(body),
                    "{\"weight_g\":%.1f,\"water_ml\":%.1f,\"temp_c\":%.1f,\"humidity_pct\":%.0f,"
                    "\"fsm_state\":\"%s\",\"remaining_sec\":%lu,\"target_interval_min\":%.2f,"
                    "\"total_ml\":%.1f,\"drink_count\":%u,\"refill_count\":%u,\"cheat_count\":%u,\"muted\":%s}",
                    local.weightG, local.waterMl, local.tempC, local.humPct,
                    local.stateStr, (unsigned long)local.remSec, local.targetMin,
                    local.totalMl, local.drinkCnt, local.refillCnt, local.cheatCnt,
                    local.muted ? "true" : "false");
                http.PATCH((uint8_t*)body, strlen(body));
                http.end();
            }
        }

        if (now - lastPollMs >= 15000UL) {
            lastPollMs = now;
            WiFiClientSecure client;
            client.setInsecure();
            HTTPClient http;
            String url = activeFirebaseUrl + "/smart_coaster/config.json";
            if (http.begin(client, url) && http.GET() == 200) {
                String cfg = http.getString();
                bool changed = false;
                if (cfg.indexOf("\"MANUAL\"") >= 0 && autoDhtTimerMode) { autoDhtTimerMode = false; changed = true; }
                else if (cfg.indexOf("\"AUTO_DHT\"") >= 0 && !autoDhtTimerMode) { autoDhtTimerMode = true; changed = true; }

                if (cfg.indexOf("\"muted\":true") >= 0 && !buzzerMuted) { buzzerMuted = true; changed = true; }
                else if (cfg.indexOf("\"muted\":false") >= 0 && buzzerMuted) { buzzerMuted = false; changed = true; }

                float mins = extractJsonFloat(cfg, "\"manual_interval_min\"", 0.0f);
                if (mins >= MIN_CUSTOM_INTERVAL_MIN && mins <= MAX_CUSTOM_INTERVAL_MIN) {
                    uint32_t newBase = (uint32_t)(mins * 60000.0f);
                    if (newBase != customBaseIntervalMs) {
                        customBaseIntervalMs = newBase;
                        changed = true;
                    }
                }
                float emptyG = extractJsonFloat(cfg, "\"empty_cup_weight_g\"", 0.0f);
                if (emptyG >= CUP_ON_THRESHOLD && emptyG <= MAX_EMPTY_CUP_G &&
                    fabs(emptyG - fsm.getEmptyCupWeight()) > 0.5f) {
                    fsm.setEmptyCupWeight(emptyG);
                    changed = true;
                }
                if (changed) {
                    updateAdaptiveInterval();
                    saveConfigToNvs();
                }
            }
            http.end();
        }

        vTaskDelay(pdMS_TO_TICKS(250));
    }
}

inline void startCloudIfNeeded() {
    if (activeWifiSsid.length() == 0) return;
    WiFi.mode(WIFI_STA);
    WiFi.begin(activeWifiSsid.c_str(), activeWifiPass.c_str());
    if (!cloudTaskRunning && activeFirebaseUrl.length() > 0) {
        cloudTaskRunning = true;
        xTaskCreatePinnedToCore(cloudTask, "cloudSync", 8192, nullptr, 1, nullptr, 0);
    }
}

inline void initCloudSync(const String& nvsSsid, const String& nvsPass, const String& nvsUrl) {
    if (nvsSsid.length() > 0) {
        activeWifiSsid = nvsSsid;
        activeWifiPass = nvsPass;
    }
    if (nvsUrl.length() > 0) {
        activeFirebaseUrl = nvsUrl;
    }
    startCloudIfNeeded();
}

inline void setCloudWifi(const String& ssid, const String& pass) {
    activeWifiSsid = ssid;
    activeWifiPass = pass;
    WiFi.disconnect();
    startCloudIfNeeded();
}

inline void setCloudFirebaseUrl(const String& url) {
    activeFirebaseUrl = url;
    startCloudIfNeeded();
}

inline void updateCloudSnapshot(float w, uint32_t nowMs, float tC, float hum, bool muted) {
    if (!cloudTaskRunning) return;
    portENTER_CRITICAL(&snapMux);
    snap.weightG = w;
    snap.waterMl = fsm.getWaterVolumeMl(w);
    snap.tempC = tC;
    snap.humPct = hum;
    strncpy(snap.stateStr, fsm.getStateString(), sizeof(snap.stateStr) - 1);
    snap.remSec = fsm.getRemainingTimeMs(nowMs) / 1000;
    snap.targetMin = fsm.getTargetIntervalMs() / 60000.0f;
    snap.totalMl = fsm.getTotalDrank();
    snap.drinkCnt = fsm.getDrinkCount();
    snap.refillCnt = fsm.getRefillCount();
    snap.cheatCnt = fsm.getCheatCount();
    snap.muted = muted;
    portEXIT_CRITICAL(&snapMux);
}
#else
inline void initCloudSync(const String&, const String&, const String&) {}
inline void setCloudWifi(const String&, const String&) {}
inline void setCloudFirebaseUrl(const String&) {}
inline void updateCloudSnapshot(float, uint32_t, float, float, bool) {}
#endif

#endif
