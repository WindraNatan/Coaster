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

// ponytail: satu transport cloud saja (HTTPS REST ke Firebase RTDB). MQTT sengaja
// dilewat: RTDB sudah push realtime + last-known state, dan konsumen tambahan
// (app mobile nanti) cukup pakai node yang sama lewat skema JSON di bawah.
// Upgrade: publish PubSubClient paralel (~30 baris, additive) hanya jika perlu
// mode LAN/demo tanpa internet.
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
static String activeApiKey = FIREBASE_API_KEY;
static String activeUserEmail = FIREBASE_USER_EMAIL;
static String activeUserPassword = FIREBASE_USER_PASSWORD;
static String idToken = "";
static String activeUid = "";
static String refreshToken = "";
static String claimCode = "";
static bool claimPublished = false;
static char sessionOwner[40] = "";
static uint32_t tokenExpiryMs = 0;

// Toko token di NVS supaya boot ulang tidak perlu login lagi. Token Firebase berlaku
// 1 jam; kalau sisa waktunya di bawah 5 menit, ambil yang baru.
static const uint32_t TOKEN_MARGIN_MS = 300000UL;
static const uint32_t TOKEN_TTL_MS = 3600000UL;

static bool firebaseLogin() {
    if (activeApiKey.length() == 0 || activeUserEmail.length() == 0) return false;
    WiFiClientSecure client;
    client.setInsecure();
    HTTPClient http;
    String url = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=" + activeApiKey;
    if (!http.begin(client, url)) return false;
    http.addHeader("Content-Type", "application/json");
    String body = "{\"email\":\"" + activeUserEmail + "\",\"password\":\"" + activeUserPassword +
                  "\",\"returnSecureToken\":true}";
    int code = http.POST(body);
    if (code != 200) {
        Serial.printf("[CLOUD] Login gagal (HTTP %d). Cek API key, email, dan password.\n", code);
        http.end();
        return false;
    }
    String res = http.getString();
    http.end();
    // Tidak ada parser JSON penuh di firmware; token selalu field pertama setelah idToken.
    int k = res.indexOf("\"idToken\":\"");
    if (k < 0) return false;
    k += 11;
    int e = res.indexOf('"', k);
    if (e < 0) return false;
    idToken = res.substring(k, e);
    int uk = res.indexOf("\"localId\":\"");
    if (uk < 0) return false;
    uk += 11;
    int ue = res.indexOf('"', uk);
    if (ue < 0) return false;
    activeUid = res.substring(uk, ue);
    tokenExpiryMs = millis() + TOKEN_TTL_MS;
    int rk = res.indexOf("\"refreshToken\":\"");
    if (rk >= 0) {
        rk += 16;
        int re = res.indexOf('"', rk);
        if (re > rk) refreshToken = res.substring(rk, re);
    }
    Preferences prefs;
    prefs.begin("shc", false);
    prefs.putString("idToken", idToken);
    prefs.putString("uid", activeUid);
    prefs.putString("refreshToken", refreshToken);
    prefs.putULong("idTokenExp", TOKEN_TTL_MS - TOKEN_MARGIN_MS);
    prefs.end();
    Serial.printf("[CLOUD] Login OK, token %u karakter.\n", idToken.length());
    return true;
}

// Token Firebase berlaku satu jam. Tukar refreshToken (disimpan saat login) jadi token
// baru, supaya alat yang menyala berhari-hari tidak bergantung pada satu login awal.
static bool firebaseRefresh() {
    if (refreshToken.length() == 0 || activeApiKey.length() == 0) return false;
    WiFiClientSecure client;
    client.setInsecure();
    HTTPClient http;
    String url = "https://securetoken.googleapis.com/v1/token?key=" + activeApiKey;
    if (!http.begin(client, url)) return false;
    http.addHeader("Content-Type", "application/x-www-form-urlencoded");
    String body = "grant_type=refresh_token&refresh_token=" + refreshToken;
    int code = http.POST(body);
    if (code != 200) { http.end(); return false; }
    String res = http.getString();
    http.end();
    int k = res.indexOf("\"id_token\":\"");
    if (k < 0) return false;
    k += 12;
    int e = res.indexOf('"', k);
    if (e < 0) return false;
    idToken = res.substring(k, e);
    tokenExpiryMs = millis() + TOKEN_TTL_MS;
    int rk = res.indexOf("\"refresh_token\":\"");
    if (rk >= 0) {
        rk += 17;
        int re = res.indexOf('"', rk);
        if (re > rk) refreshToken = res.substring(rk, re);
    }
    Preferences prefs;
    prefs.begin("shc", false);
    prefs.putString("idToken", idToken);
    prefs.putString("refreshToken", refreshToken);
    prefs.putULong("idTokenExp", TOKEN_TTL_MS - TOKEN_MARGIN_MS);
    prefs.end();
    return true;
}

static bool ensureToken() {
    if (idToken.length() > 0 && activeUid.length() > 0 &&
        (int32_t)(tokenExpiryMs - millis()) > (int32_t)TOKEN_MARGIN_MS) {
        return true;
    }
    return firebaseRefresh() || firebaseLogin();
}

// Node milik akun ini. Rules menolak akses ke /users/<uid> milik orang lain, jadi UID
// wajib ikut di path, bukan hanya di token.
static String userNode() {
    return activeFirebaseUrl + "/users/" + activeUid + "/smart_coaster";
}

static String authSuffix() {
    return idToken.length() > 0 ? "?auth=" + idToken : String("");
}

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


// Kode klaim: 8 karakter dari alfabet tanpa huruf mirip (0/O, 1/I/L). Dibuat sekali,
// disimpan di NVS, lalu ditulis ke /claims/<kode> supaya pemilik bisa menautkan alat
// ini ke akunnya. Kode TIDAK boleh sama dengan UID: UID bukan rahasia.
static String makeClaimCode() {
    static const char AB[] = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";
    String out;
    out.reserve(8);
    for (int i = 0; i < 8; i++) out += AB[esp_random() % 31];
    return out;
}

// Tulis /claims/<kode> = UID perangkat. Rules hanya mengizinkan penulisan sekali dan
// hanya kalau nilainya UID si penulis, jadi kode tidak bisa dipalsukan orang lain.
static bool publishClaimCode() {
    if (claimCode.length() == 0 || activeUid.length() == 0) return false;
    WiFiClientSecure client;
    client.setInsecure();
    HTTPClient http;
    String url = activeFirebaseUrl + "/claims/" + claimCode + ".json" + authSuffix();
    if (!http.begin(client, url)) return false;
    http.addHeader("Content-Type", "application/json");
    int code = http.PUT("\"" + activeUid + "\"");
    http.end();
    if (code == 200) {
        Serial.printf("[CLOUD] Kode klaim: %s\n", claimCode.c_str());
        Preferences prefs;
        prefs.begin("shc", false);
        prefs.putBool("claimDone", true);
        prefs.end();
        return true;
    }
    Serial.printf("[CLOUD] Gagal publikasi kode klaim (HTTP %d).\n", code);
    return false;
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
        if (!ensureToken()) {
            vTaskDelay(pdMS_TO_TICKS(30000));
            continue;
        }

        uint32_t now = millis();
        CloudSnapshot local;
        portENTER_CRITICAL(&snapMux);
        local = snap;
        portEXIT_CRITICAL(&snapMux);

        if (!claimPublished) {
            claimPublished = publishClaimCode();
        }

        bool stateChanged = strncmp(local.stateStr, lastState, sizeof(lastState)) != 0;
        if (stateChanged || (now - lastPushMs >= 5000UL)) {
            strncpy(lastState, local.stateStr, sizeof(lastState) - 1);
            lastPushMs = now;

            WiFiClientSecure client;
            client.setInsecure();
            HTTPClient http;
            String url = userNode() + "/telemetry.json" + authSuffix();
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
            String url = userNode() + "/config.json" + authSuffix();
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

            // Sesi bergiliran: web menulis session.owner. Begitu nilainya berbeda dari
            // pemilik terakhir, statistik di-reset supaya orang berikutnya tidak mewarisi
            // angka orang sebelumnya.
            WiFiClientSecure sessClient;
            sessClient.setInsecure();
            HTTPClient sessHttp;
            String sessUrl = userNode() + "/session.json" + authSuffix();
            if (sessHttp.begin(sessClient, sessUrl) && sessHttp.GET() == 200) {
                String sess = sessHttp.getString();
                int oi = sess.indexOf("\"owner\":\"");
                if (oi >= 0) {
                    oi += 9;
                    int oe = sess.indexOf('"', oi);
                    if (oe > oi) {
                        String owner = sess.substring(oi, oe);
                        if (owner.length() > 0 && strncmp(owner.c_str(), sessionOwner, sizeof(sessionOwner)) != 0) {
                            strncpy(sessionOwner, owner.c_str(), sizeof(sessionOwner) - 1);
                            sessionOwner[sizeof(sessionOwner) - 1] = '\0';
                            fsm.resetDailyStats();
                            saveStatsToNvs();
                            Serial.printf("[CLOUD] Sesi baru untuk %.8s..., statistik di-reset.\n", owner.c_str());
                        }
                    }
                }
            }
            sessHttp.end();
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
    Preferences prefs;
    prefs.begin("shc", true);
    idToken = prefs.getString("idToken", "");
    activeUid = prefs.getString("uid", "");
    refreshToken = prefs.getString("refreshToken", "");
    claimCode = prefs.getString("claimCode", "");
    claimPublished = false;
    if (claimCode.length() == 0) {
        claimCode = makeClaimCode();
        Preferences w;
        w.begin("shc", false);
        w.putString("claimCode", claimCode);
        w.end();
    }
    // millis() ulang dari nol setiap boot, jadi cap kedaluwarsa dari boot sebelumnya
    // tidak bisa dipercaya. Set 0 supaya ensureToken() memaksa perpanjangan/login awal.
    tokenExpiryMs = 0;
    prefs.end();
    Serial.printf("[CLOUD] Kode klaim alat: %s\n", claimCode.c_str());
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
