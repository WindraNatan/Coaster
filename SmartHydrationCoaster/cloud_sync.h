#ifndef CLOUD_SYNC_H
#define CLOUD_SYNC_H

#include <Arduino.h>
#include "config.h"
#include "fsm.h"
#include "session_gate.h"
#include "cloud_config_parser.h"

#if defined(ESP32)
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <WiFiManager.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include <ESPmDNS.h>
#include <esp_mac.h>

// ponytail: hanya pakai HTTPS REST Firebase RTDB; tambah MQTT hanya jika perlu mode LAN.
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
    bool standby;
    bool demoMode;
    bool autoDhtTimerMode;
    uint32_t customBaseIntervalMs;
    float emptyCupWeightG;
};

static volatile bool cloudTaskRunning = false;
static TaskHandle_t cloudTaskHandle = nullptr;
static CloudSnapshot snap = {};
static PendingCloudUpdate pendingCloud = {};
static portMUX_TYPE snapMux = portMUX_INITIALIZER_UNLOCKED;

inline bool consumePendingCloudUpdate(PendingCloudUpdate& out) {
    portENTER_CRITICAL(&snapMux);
    bool has = pendingCloud.hasConfig || pendingCloud.hasNewSessionOwner;
    if (has) {
        out = pendingCloud;
        pendingCloud.hasConfig = false;
        pendingCloud.hasNewSessionOwner = false;
    }
    portEXIT_CRITICAL(&snapMux);
    return has;
}

// Diakses Core 0 dan Core 1; selalu lindungi dengan snapMux.
static SessionGate sessionGate;

inline void setLocalStandby(bool sleep) {
    portENTER_CRITICAL(&snapMux);
    sessionGate.local(sleep);
    portEXIT_CRITICAL(&snapMux);
}

inline bool standbyActiveNow() {
    portENTER_CRITICAL(&snapMux);
    bool v = sessionGate.sleep;
    portEXIT_CRITICAL(&snapMux);
    return v;
}
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
static bool claimMirrored = false;
static uint32_t claimRetryAfterMs = 0;
static uint32_t mirrorRetryAfterMs = 0;
// Cek node sekali per boot agar NVS tidak basi bila node dihapus.
static bool claimMirrorChecked = false;
static char sessionOwner[40] = "";
static uint32_t tokenExpiryMs = 0;

// Token Firebase berlaku 1 jam; perbarui 5 menit sebelum kedaluwarsa.
static const uint32_t TOKEN_MARGIN_MS = 300000UL;
static const uint32_t TOKEN_TTL_MS = 3600000UL;

// ponytail: hanya escape 4 karakter JSON; ganti encoder penuh jika ada input selain Serial.
static String jsonEscape(const String& s) {
    String out;
    out.reserve(s.length() + 8);
    for (size_t i = 0; i < s.length(); i++) {
        char c = s[i];
        switch (c) {
            case '"':  out += "\\\""; break;
            case '\\': out += "\\\\"; break;
            case '\n': out += "\\n"; break;
            case '\r': out += "\\r"; break;
            case '\t': out += "\\t"; break;
            default:   out += c;
        }
    }
    return out;
}

// Lewati spasi setelah ':' karena respons Google Auth berformat pretty-print.
static String jsonField(const String& s, const char* key) {
    String pola = "\"" + String(key) + "\"";
    int k = s.indexOf(pola);
    if (k < 0) return String();
    k += pola.length();
    while (k < (int)s.length() && (s[k] == ' ' || s[k] == '\t')) k++;
    if (k >= (int)s.length() || s[k] != ':') return String();
    k++;
    while (k < (int)s.length() && (s[k] == ' ' || s[k] == '\t')) k++;
    if (k >= (int)s.length() || s[k] != '"') return String();
    k++;
    int e = s.indexOf('"', k);
    if (e < 0) return String();
    return s.substring(k, e);
}
static bool firebaseLogin() {
    if (activeApiKey.length() == 0 || activeUserEmail.length() == 0) return false;
    WiFiClientSecure tls;
    tls.setInsecure();
    HTTPClient http;
    String url = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=" + activeApiKey;
    if (!http.begin(tls, url)) return false;
    http.addHeader("Content-Type", "application/json");
    String body = "{\"email\":\"" + jsonEscape(activeUserEmail) + "\",\"password\":\"" +
                  jsonEscape(activeUserPassword) + "\",\"returnSecureToken\":true}";
    int code = http.POST(body);
    if (code != 200) {
        Serial.printf("[CLOUD] Login gagal (HTTP %d). Cek API key, email, dan password.\n", code);
        http.end();
        return false;
    }
    String res = http.getString();
    http.end();
    idToken = jsonField(res, "idToken");
    activeUid = jsonField(res, "localId");
    if (idToken.length() == 0 || activeUid.length() == 0) {
        Serial.println(F("[CLOUD] Respons login tidak memuat idToken/localId. "
                         "Cek bentuk respons di atas."));
        return false;
    }
    tokenExpiryMs = millis() + TOKEN_TTL_MS;
    String rt = jsonField(res, "refreshToken");
    if (rt.length() > 0) refreshToken = rt;
    Preferences prefs;
    prefs.begin("shc", false);
    prefs.putString("idToken", idToken);
    prefs.putString("uid", activeUid);
    prefs.putString("refreshToken", refreshToken);
    prefs.end();
    Serial.printf("[CLOUD] Login OK, token %u karakter.\n", idToken.length());
    return true;
}

static bool firebaseRefresh() {
    if (refreshToken.length() == 0 || activeApiKey.length() == 0) return false;
    WiFiClientSecure tls;
    tls.setInsecure();
    HTTPClient http;
    String url = "https://securetoken.googleapis.com/v1/token?key=" + activeApiKey;
    if (!http.begin(tls, url)) return false;
    http.addHeader("Content-Type", "application/x-www-form-urlencoded");
    String body = "grant_type=refresh_token&refresh_token=" + refreshToken;
    int code = http.POST(body);
    if (code != 200) { http.end(); return false; }
    String res = http.getString();
    http.end();
    idToken = jsonField(res, "id_token");
    if (idToken.length() == 0) {
        Serial.println(F("[CLOUD] Respons refresh tidak memuat id_token."));
        return false;
    }
    tokenExpiryMs = millis() + TOKEN_TTL_MS;
    String rt = jsonField(res, "refresh_token");
    if (rt.length() > 0) refreshToken = rt;
    Preferences prefs;
    prefs.begin("shc", false);
    prefs.putString("idToken", idToken);
    prefs.putString("refreshToken", refreshToken);
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

static String userNode() {
    return activeFirebaseUrl + "/users/" + activeUid + "/smart_coaster";
}

static String authSuffix() {
    return idToken.length() > 0 ? "?auth=" + idToken : String("");
}

static String authSuffixSilent() {
    return idToken.length() > 0 ? "?auth=" + idToken + "&print=silent"
                                : String("?print=silent");
}

extern bool demoMode;
extern bool autoDhtTimerMode;
extern bool buzzerMuted;
extern volatile bool configDirty;
extern uint32_t customBaseIntervalMs;
extern CoasterFSM fsm;


// Kode klaim 8 karakter tanpa karakter mirip (0/O, 1/I/L), terpisah dari UID.
static String makeClaimCode() {
    static const char AB[] = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";
    String out;
    out.reserve(8);
    for (int i = 0; i < 8; i++) out += AB[esp_random() % 31];
    return out;
}

// Rules hanya mengizinkan PUT sekali dengan nilai sama dengan UID perangkat.
static bool publishClaimCode() {
    if (claimCode.length() == 0 || activeUid.length() == 0) return false;
    WiFiClientSecure tls;
    tls.setInsecure();
    HTTPClient http;
    String url = activeFirebaseUrl + "/claims/" + claimCode + ".json" + authSuffix();
    if (!http.begin(tls, url)) return false;
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
    uint32_t lastSessMs = 0;
    // Satu soket TLS dipakai ulang sepanjang loop untuk menghindari handshake ulang.
    // shortcut: tls.setInsecure() karena ESP32 tanpa NTP (validasi X.509 gagal di epoch 1970).
    WiFiClientSecure tls;
    tls.setInsecure();
    tls.setTimeout(8);
    // Hidup sepanjang loop karena destruktor HTTPClient memutus soket.
    HTTPClient rtdb;
    rtdb.setReuse(true);
    rtdb.setTimeout(8000);
    float lastWeightG = -999, lastTempC = -999, lastHumPct = -999, lastTargetMin = -1;
    uint16_t lastDrinkCnt = 0xFFFF, lastRefillCnt = 0xFFFF, lastCheatCnt = 0xFFFF;
    bool lastMuted = false;
    bool lastStandby = false;
    bool noDelayApplied = false;
    auto syncNoDelay = [&]() {
        if (!tls.connected()) {
            noDelayApplied = false;
        } else if (!noDelayApplied) {
            tls.setNoDelay(true);
            noDelayApplied = true;
        }
    };
    uint16_t hbCounter = 0;
    uint8_t cfgPatchFails = 0;

    for (;;) {
        if (activeFirebaseUrl.length() == 0 || WiFi.status() != WL_CONNECTED) {
            static uint32_t lastWifiLogMs = 0;
            if ((uint32_t)(millis() - lastWifiLogMs) > 10000UL) {
                lastWifiLogMs = millis();
                if (activeFirebaseUrl.length() == 0) {
                    Serial.println(F("[CLOUD] URL Firebase kosong: periksa secrets.h "
                                     "(FIREBASE_DB_URL)."));
                } else if (WiFi.status() != WL_CONNECTED) {
                    Serial.printf("[CLOUD] Wi-Fi belum konek (status %d, SSID \"%s\"). "
                                  "Periksa sandi dan pastikan SSID 2.4 GHz; "
                                  "status 6 hanya berarti terputus.\n",
                                  (int)WiFi.status(), activeWifiSsid.c_str());
                }
            }
            vTaskDelay(pdMS_TO_TICKS(2000));
            continue;
        }
        static bool connectedLogged = false;
        if (!connectedLogged) {
            connectedLogged = true;
            Serial.printf("[CLOUD] Wi-Fi tersambung, IP %s\n",
                          WiFi.localIP().toString().c_str());
        }
        if (!ensureToken()) {
            vTaskDelay(pdMS_TO_TICKS(30000));
            continue;
        }
        if (!tls.connected()) noDelayApplied = false;

        uint32_t now = millis();
        CloudSnapshot local;
        portENTER_CRITICAL(&snapMux);
        local = snap;
        portEXIT_CRITICAL(&snapMux);

        // Salinan kode ditaruh di /private agar tamu tertaut tidak ikut membaca.
        if (!claimMirrorChecked && claimMirrored &&
            (int32_t)(now - mirrorRetryAfterMs) >= 0) {
            String cek = activeFirebaseUrl + "/users/" + activeUid +
                         "/private/claimCode.json" + authSuffix();
            bool cekOk = false;
            if (rtdb.begin(tls, cek)) {
                int cekCode = rtdb.GET();
                String isi = (cekCode == 200) ? rtdb.getString() : String();
                rtdb.end();
                if (cekCode == 200) {
                    cekOk = true;
                    claimMirrorChecked = true;
                    if (isi.indexOf(claimCode) < 0) {
                        claimMirrored = false;
                        Preferences mp;
                        mp.begin("shc", false);
                        mp.remove("claimMirrorDone");
                        mp.end();
                        Serial.println(F("[CLOUD] Salinan kode tidak cocok; ditulis ulang."));
                    }
                }
            }
            if (!cekOk) mirrorRetryAfterMs = now + 3600000UL;
        }

        if (!claimMirrored && (int32_t)(now - mirrorRetryAfterMs) >= 0) {
            String mine = activeFirebaseUrl + "/users/" + activeUid +
                          "/private/claimCode.json" + authSuffix();
            if (rtdb.begin(tls, mine)) {
                rtdb.addHeader("Content-Type", "application/json");
                int mirrorCode = rtdb.PUT("\"" + claimCode + "\"");
                rtdb.end();
                if (mirrorCode == 200) {
                    claimMirrored = true;
                    Serial.printf("[CLOUD] Salinan kode klaim tersimpan (HTTP 200).\n");
                    Preferences mp;
                    mp.begin("shc", false);
                    mp.putBool("claimMirrorDone", true);
                    mp.end();
                } else {
                    // 401 berarti rules claimCode belum dipasang; tunda retry 1 jam.
                    mirrorRetryAfterMs = now + 3600000UL;
                    Serial.printf("[CLOUD] Salinan kode klaim gagal (HTTP %d). Pasang aturan claimCode, atau baca kode dari sini.\n", mirrorCode);
                }
            }
        }

        if (!claimPublished && (int32_t)(now - claimRetryAfterMs) >= 0) {
            // Rules menolak PUT kedua; mundur 1 jam bila gagal.
            claimPublished = publishClaimCode();
            if (!claimPublished) claimRetryAfterMs = now + 3600000UL;
        }

        bool stateChanged = strncmp(local.stateStr, lastState, sizeof(lastState)) != 0;
        // Kirim hanya saat nilai berubah (kecuali remaining_sec yang berjalan terus).
        bool dataChanged =
            stateChanged ||
            fabsf(local.weightG - lastWeightG) > 0.5f ||
            local.drinkCnt != lastDrinkCnt ||
            local.refillCnt != lastRefillCnt ||
            local.cheatCnt != lastCheatCnt ||
            local.muted != lastMuted ||
            fabsf(local.targetMin - lastTargetMin) > 0.01f ||
            fabsf(local.tempC - lastTempC) > 0.2f ||
            fabsf(local.humPct - lastHumPct) > 1.0f ||
            local.standby != lastStandby;
        // Heartbeat 10 detik agar klien mendeteksi alat putus dalam <= 25 detik.
        bool heartbeat = (now - lastPushMs >= 10000UL);
        if (dataChanged || heartbeat) {
            strncpy(lastState, local.stateStr, sizeof(lastState) - 1);
            lastState[sizeof(lastState) - 1] = '\0';
            lastWeightG = local.weightG;
            lastDrinkCnt = local.drinkCnt;
            lastRefillCnt = local.refillCnt;
            lastCheatCnt = local.cheatCnt;
            lastMuted = local.muted;
            lastTargetMin = local.targetMin;
            lastTempC = local.tempC;
            lastHumPct = local.humPct;
            lastStandby = local.standby;
            lastPushMs = now;

            String url = userNode() + "/telemetry.json" + authSuffixSilent();
            if (rtdb.begin(tls, url)) {
                rtdb.addHeader("Content-Type", "application/json");
                char body[400];
                if (++hbCounter == 0) hbCounter = 1;
                snprintf(body, sizeof(body),
                    "{\"weight_g\":%.1f,\"water_ml\":%.1f,\"temp_c\":%.1f,\"humidity_pct\":%.0f,"
                    "\"fsm_state\":\"%s\",\"remaining_sec\":%lu,\"target_interval_min\":%.2f,"
                    "\"total_ml\":%.1f,\"drink_count\":%u,\"refill_count\":%u,\"cheat_count\":%u,"
                    "\"muted\":%s,\"standby\":%s,\"hb\":%u}",
                    local.weightG, local.waterMl, local.tempC, local.humPct,
                    local.stateStr, (unsigned long)local.remSec, local.targetMin,
                    local.totalMl, local.drinkCnt, local.refillCnt, local.cheatCnt,
                    local.muted ? "true" : "false", local.standby ? "true" : "false",
                    (unsigned)hbCounter);
                int pushCode = rtdb.PATCH((uint8_t*)body, strlen(body));
                rtdb.end();
                syncNoDelay();
                if (pushCode == 401) tokenExpiryMs = 0;
            }
        }

        // Unggah perubahan lokal sebelum GET agar tidak tertimpa nilai cloud lama.
        if (configDirty) {
            configDirty = false;
            bool patchOk = false;
            String cfgUrl = userNode() + "/config.json" + authSuffixSilent();
            if (rtdb.begin(tls, cfgUrl)) {
                rtdb.addHeader("Content-Type", "application/json");
                char cfgBody[160];
                // Sertakan DEMO agar patch dari Serial tidak menghapus mode demo klien.
                const char* modeStr =
                    local.demoMode ? "DEMO" : (local.autoDhtTimerMode ? "AUTO_DHT" : "MANUAL");
                snprintf(cfgBody, sizeof(cfgBody),
                    "{\"timer_mode\":\"%s\",\"manual_interval_min\":%lu,"
                    "\"muted\":%s,\"empty_cup_weight_g\":%.1f}",
                    modeStr,
                    (unsigned long)(local.customBaseIntervalMs / 60000UL),
                    local.muted ? "true" : "false",
                    local.emptyCupWeightG);
                int code = rtdb.PATCH((uint8_t*)cfgBody, strlen(cfgBody));
                patchOk = (code >= 200 && code < 300);
                rtdb.end();
                syncNoDelay();
                if (code == 401) tokenExpiryMs = 0;
            }
            // Batasi retry saat PATCH gagal agar jaringan mati tidak memicu loop rapat.
            if (!patchOk) {
                if (cfgPatchFails < 3) {
                    cfgPatchFails++;
                    configDirty = true;
                    vTaskDelay(pdMS_TO_TICKS(1500));
                } else {
                    cfgPatchFails = 0;
                }
            } else {
                cfgPatchFails = 0;
            }
        }

        // Poll config tiap 1 detik, dipisah iterasinya dari poll sesi.
        bool polledConfigThisIter = false;
        if (now - lastPollMs >= 1000UL) {
            lastPollMs = now;
            polledConfigThisIter = true;
            String url = userNode() + "/config.json" + authSuffix();
            int cfgCode = 0;
            if (rtdb.begin(tls, url)) {
                cfgCode = rtdb.GET();
                if (cfgCode == 200) {
                    String cfg = rtdb.getString();
                    // Lewati hasil GET jika perintah Serial masuk di tengah request.
                    if (!configDirty) {
                        CloudConfigState st = {
                            local.demoMode,
                            local.autoDhtTimerMode,
                            local.muted,
                            local.customBaseIntervalMs,
                            local.emptyCupWeightG
                        };
                        if (parseCloudConfigJson(cfg.c_str(), st)) {
                            portENTER_CRITICAL(&snapMux);
                            if (!configDirty) {
                                pendingCloud.cfg = st;
                                pendingCloud.hasConfig = true;
                            }
                            portEXIT_CRITICAL(&snapMux);
                        }
                    }
                }
                rtdb.end();
                syncNoDelay();
            }
            if (cfgCode == 401) tokenExpiryMs = 0;
        }

        // Poll sesi bergiliran (2 detik aktif, 1 detik standby/alert).
        bool alertNow = strncmp(local.stateStr, "ALERT_", 6) == 0;
        uint32_t sessPeriodMs = (local.standby || alertNow) ? 1000UL : 2000UL;
        if (!polledConfigThisIter && (now - lastSessMs >= sessPeriodMs)) {
            lastSessMs = now;
            String sessUrl = userNode() + "/session.json" + authSuffix();
            int sessCode = 0;
            if (rtdb.begin(tls, sessUrl)) {
                sessCode = rtdb.GET();
                if (sessCode == 200) {
                    String sess = rtdb.getString();
                    bool wantSleep = sess.indexOf("\"active\":false") >= 0;
                    portENTER_CRITICAL(&snapMux);
                    sessionGate.fromCloud(wantSleep);
                    portEXIT_CRITICAL(&snapMux);
                    int oi = sess.indexOf("\"owner\":\"");
                    if (oi >= 0) {
                        oi += 9;
                        int oe = sess.indexOf('"', oi);
                        if (oe > oi) {
                            String owner = sess.substring(oi, oe);
                            if (owner.length() > 0 && strncmp(owner.c_str(), sessionOwner, sizeof(sessionOwner)) != 0) {
                                strncpy(sessionOwner, owner.c_str(), sizeof(sessionOwner) - 1);
                                sessionOwner[sizeof(sessionOwner) - 1] = '\0';
                                portENTER_CRITICAL(&snapMux);
                                strncpy(pendingCloud.newSessionOwner, sessionOwner, sizeof(pendingCloud.newSessionOwner) - 1);
                                pendingCloud.newSessionOwner[sizeof(pendingCloud.newSessionOwner) - 1] = '\0';
                                pendingCloud.hasNewSessionOwner = true;
                                portEXIT_CRITICAL(&snapMux);
                            }
                        }
                    }
                }
                rtdb.end();
                syncNoDelay();
            }
            if (sessCode == 401) tokenExpiryMs = 0;
        }

        ulTaskNotifyTake(pdTRUE, pdMS_TO_TICKS(100));
    }
}

// Captive portal AP non-blocking; memakai kunci NVS yang sama dengan Serial 'w'.
static String wifiPortalSsid, wifiPortalPass;

// Buka portal otomatis jika koneksi WiFi gagal lebih dari 30 detik.
static uint32_t wifiAttemptMs = 0;
static bool portalConnected = false;

static void wifiOnSaveParams() {
    if (wifiPortalSsid.length() == 0) return;
    activeWifiSsid = wifiPortalSsid;
    activeWifiPass = wifiPortalPass;
    Preferences p;
    p.begin("shc", false);
    p.putString("wifiSsid", wifiPortalSsid);
    p.putString("wifiPass", wifiPortalPass);
    p.end();
    Serial.printf("[WIFI] Portal menyimpan SSID \"%s\"\n", wifiPortalSsid.c_str());
    // Mode non-blocking tidak memanggil WiFi.begin() otomatis setelah simpan.
    portalConnected = true;
    WiFi.mode(WIFI_STA);
    WiFi.begin(activeWifiSsid.c_str(), activeWifiPass.c_str());
    wifiAttemptMs = millis();
}

static WiFiManager wifiMgr;
static bool portalActive = false;
static uint32_t portalStartedMs = 0;

// Iklankan kode klaim lewat mDNS (<Kode>._shc._tcp) untuk penemuan LAN.

inline void startClaimBeacon() {
    if (claimCode.length() == 0) return;
    if (!MDNS.begin(claimCode.c_str())) {
        Serial.println(F("[MDNS] Gagal mulai; klaim lewat portal tetap jalan."));
        return;
    }
    // Baca MAC dari eFuse karena WiFi.macAddress() bernilai nol pada mode AP saja.
    uint8_t macBin[6];
    char macTxt[18];
    esp_efuse_mac_get_default(macBin);
    snprintf(macTxt, sizeof(macTxt), "%02X:%02X:%02X:%02X:%02X:%02X",
             macBin[0], macBin[1], macBin[2], macBin[3], macBin[4], macBin[5]);
    MDNS.addService("shc", "tcp", 80);
    MDNS.addServiceTxt("shc", "tcp", "code", claimCode);
    MDNS.addServiceTxt("shc", "tcp", "mac", String(macTxt));
    Serial.printf("[MDNS] Dapat ditemukan di LAN: %s._shc._tcp, code=%s, mac=%s\n",
                  claimCode.c_str(), claimCode.c_str(), macTxt);
}

inline void stopClaimBeacon() {
    MDNS.end();
}

inline void startWifiPortal(bool force) {
    if (portalActive) return;
    wifiMgr.setConfigPortalBlocking(false);
    wifiMgr.setConnectTimeout(20);
    static WiFiManagerParameter pSsid("ssid", "Nama Wi-Fi (2.4 GHz)", "", 33);
    static WiFiManagerParameter pPass("pass", "Kata sandi", "", 65);
    // Daftarkan parameter sekali karena addParameter() menumpuk jika dipanggil ulang.
    static bool paramsAdded = false;
    if (!paramsAdded) {
        paramsAdded = true;
        wifiMgr.addParameter(&pSsid);
        wifiMgr.addParameter(&pPass);
    }
    wifiMgr.setSaveParamsCallback([&]() {
        wifiPortalSsid = pSsid.getValue();
        wifiPortalPass = pPass.getValue();
        wifiOnSaveParams();
    });
    Serial.printf("[WIFI] Portal dibuka. Sambungkan ponsel ke Wi-Fi \"%s\" "
                  "(sandi: %s), lalu isi nama dan sandi jaringan rumah.\n",
                  PORTAL_AP_NAME, PORTAL_AP_PASS);
    wifiMgr.startConfigPortal(PORTAL_AP_NAME, PORTAL_AP_PASS);
    portalActive = true;
    portalStartedMs = millis();
    startClaimBeacon();
}

inline void checkWifiStale() {
    if (portalActive) return;
    if (portalConnected) {
        if (WiFi.status() == WL_CONNECTED) { portalConnected = false; wifiAttemptMs = 0; return; }
        if (millis() - wifiAttemptMs < 30000UL) return;
        portalConnected = false;
    }
    if (activeWifiSsid.length() == 0) return;
    if (WiFi.status() == WL_CONNECTED) { wifiAttemptMs = 0; return; }
    if (wifiAttemptMs == 0) { wifiAttemptMs = millis(); return; }
    if (millis() - wifiAttemptMs > 30000UL) {
        Serial.println(F("[WIFI] Gagal tersambung 30 dtk: membuka portal."));
        wifiAttemptMs = 0;
        startWifiPortal(true);
    }
}

inline bool handleWifiPortal() {
    if (!portalActive) return false;
    wifiMgr.process();
    if (WiFi.status() == WL_CONNECTED && activeWifiSsid.length() > 0) {
        portalActive = false;
        stopClaimBeacon();
        Serial.printf("[WIFI] Tersambung ke \"%s\"\n", activeWifiSsid.c_str());
        return false;
    }
    if (millis() - portalStartedMs > 180000UL) {
        portalActive = false;
        stopClaimBeacon();
        wifiMgr.stopConfigPortal();
        WiFi.mode(WIFI_STA);
        Serial.println(F("[WIFI] Portal ditutup tanpa kredensial. Kirim 'w<SSID>|<sandi>' "
                         "lewat serial atau nyalakan ulang."));
        return false;
    }
    return true;
}

inline bool wifiPortalIsOpen() { return portalActive; }

inline void startCloudIfNeeded() {
    if (activeWifiSsid.length() == 0) {
        Serial.println(F("[CLOUD] SSID kosong: membuka portal Wi-Fi."));
        startWifiPortal(true);
    } else if (!portalActive) {
        WiFi.mode(WIFI_STA);
        WiFi.begin(activeWifiSsid.c_str(), activeWifiPass.c_str());
        wifiAttemptMs = millis();
        Serial.printf("[CLOUD] Menghubungkan Wi-Fi \"%s\"...\n", activeWifiSsid.c_str());
    }
    if (activeFirebaseUrl.length() == 0) {
        Serial.println(F("[CLOUD] URL Firebase kosong: cloud tidak dijalankan. "
                         "Periksa FIREBASE_DB_URL di secrets.h."));
        return;
    }
    if (!cloudTaskRunning) {
        cloudTaskRunning = true;
        xTaskCreatePinnedToCore(cloudTask, "cloudSync", 8192, nullptr, 1, &cloudTaskHandle, 0);
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
    // Muat sessionOwner dari NVS agar reboot tidak mereset statistik harian.
    String savedOwner = prefs.getString("sessionOwner", "");
    strncpy(sessionOwner, savedOwner.c_str(), sizeof(sessionOwner) - 1);
    sessionOwner[sizeof(sessionOwner) - 1] = '\0';
    claimPublished = prefs.getBool("claimDone", false);
    claimMirrored = prefs.getBool("claimMirrorDone", false);
    Serial.printf("[CLOUD] Salinan kode klaim: %s\n",
                  claimMirrored ? "sudah tercatat, PUT tidak diulang"
                                : "belum tercatat, akan dicoba");
    if (claimCode.length() == 0) {
        claimCode = makeClaimCode();
        Preferences w;
        w.begin("shc", false);
        w.putString("claimCode", claimCode);
        w.end();
    }
    // Reset tokenExpiryMs saat boot karena millis() mulai ulang dari nol.
    tokenExpiryMs = 0;
    prefs.end();
    Serial.printf("[CLOUD] Kode klaim alat: %s\n", claimCode.c_str());
    Serial.printf("[CLOUD] Konfigurasi: ssid=%u url=%u key=%u email=%u\n",
                  (unsigned)activeWifiSsid.length(), (unsigned)activeFirebaseUrl.length(),
                  (unsigned)activeApiKey.length(), (unsigned)activeUserEmail.length());
    snap.demoMode = demoMode;
    snap.autoDhtTimerMode = autoDhtTimerMode;
    snap.customBaseIntervalMs = customBaseIntervalMs;
    snap.emptyCupWeightG = fsm.getEmptyCupWeight();
    snap.muted = buzzerMuted;
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
    const char* nextState = fsm.getStateString();
    uint16_t dCnt = fsm.getDrinkCount();
    uint16_t rCnt = fsm.getRefillCount();
    uint16_t cCnt = fsm.getCheatCount();
    bool wake = false;
    portENTER_CRITICAL(&snapMux);
    wake = (strcmp(snap.stateStr, nextState) != 0) ||
           fabsf(w - snap.weightG) > 0.5f ||
           (snap.standby != sessionGate.sleep) ||
           (snap.muted != muted) ||
           (snap.drinkCnt != dCnt) ||
           (snap.refillCnt != rCnt) ||
           (snap.cheatCnt != cCnt);
    snap.weightG = w;
    snap.waterMl = fsm.getWaterVolumeMl(w);
    snap.tempC = tC;
    snap.humPct = hum;
    strncpy(snap.stateStr, nextState, sizeof(snap.stateStr) - 1);
    snap.stateStr[sizeof(snap.stateStr) - 1] = '\0';
    snap.remSec = fsm.getRemainingTimeMs(nowMs) / 1000;
    snap.targetMin = fsm.getTargetIntervalMs() / 60000.0f;
    snap.totalMl = fsm.getTotalDrank();
    snap.drinkCnt = dCnt;
    snap.refillCnt = rCnt;
    snap.cheatCnt = cCnt;
    snap.muted = muted;
    snap.standby = sessionGate.sleep;
    snap.demoMode = demoMode;
    snap.autoDhtTimerMode = autoDhtTimerMode;
    snap.customBaseIntervalMs = customBaseIntervalMs;
    snap.emptyCupWeightG = fsm.getEmptyCupWeight();
    portEXIT_CRITICAL(&snapMux);
    if (wake && cloudTaskHandle != nullptr) {
        xTaskNotifyGive(cloudTaskHandle);
    }
}
#else
inline void initCloudSync(const String&, const String&, const String&) {}
inline void setCloudWifi(const String&, const String&) {}
inline void setCloudFirebaseUrl(const String&) {}
inline void updateCloudSnapshot(float, uint32_t, float, float, bool) {}
inline void setLocalStandby(bool) {}
inline bool standbyActiveNow() { return false; }
inline bool consumePendingCloudUpdate(PendingCloudUpdate&) { return false; }
#endif

#endif
