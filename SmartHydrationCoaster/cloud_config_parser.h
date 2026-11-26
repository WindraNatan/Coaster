#ifndef CLOUD_CONFIG_PARSER_H
#define CLOUD_CONFIG_PARSER_H

#include <Arduino.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include "config.h"

struct CloudConfigState {
    bool demoMode;
    bool autoDhtTimerMode;
    bool buzzerMuted;
    uint32_t customBaseIntervalMs;
    float emptyCupWeightG;
    uint64_t tareAt;
};

struct PendingCloudUpdate {
    bool hasConfig;
    CloudConfigState cfg;
    bool hasNewSessionOwner;
    char newSessionOwner[40];
};

inline const char* skipCloudJsonWs(const char* p) {
    while (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r') p++;
    return p;
}

inline const char* findCloudJsonValue(const char* s, const char* key) {
    if (!s || !key) return nullptr;
    const char* p = strstr(s, key);
    if (!p) return nullptr;
    p += strlen(key);
    p = skipCloudJsonWs(p);
    if (*p != ':') return nullptr;
    return skipCloudJsonWs(p + 1);
}

inline bool parseCloudJsonBool(const char* s, const char* key, bool* outVal) {
    const char* v = findCloudJsonValue(s, key);
    if (!v || !outVal) return false;
    if (strncmp(v, "true", 4) == 0) {
        *outVal = true;
        return true;
    }
    if (strncmp(v, "false", 5) == 0) {
        *outVal = false;
        return true;
    }
    return false;
}

inline float parseCloudJsonFloat(const char* s, const char* key, float fallback, bool* foundOut = nullptr) {
    if (foundOut) *foundOut = false;
    const char* v = findCloudJsonValue(s, key);
    if (!v) return fallback;
    char* endPtr = nullptr;
    float val = strtof(v, &endPtr);
    if (endPtr == v) return fallback;
    if (foundOut) *foundOut = true;
    return val;
}

inline uint64_t parseCloudJsonUint64(const char* s, const char* key, uint64_t fallback, bool* foundOut = nullptr) {
    if (foundOut) *foundOut = false;
    const char* v = findCloudJsonValue(s, key);
    if (!v || *v < '0' || *v > '9') return fallback;
    char* endPtr = nullptr;
    uint64_t val = strtoull(v, &endPtr, 10);
    if (endPtr == v) return fallback;
    if (foundOut) *foundOut = true;
    return val;
}

inline bool parseCloudJsonStringEq(const char* s, const char* key, const char* expected) {
    const char* v = findCloudJsonValue(s, key);
    if (!v || *v != '"' || !expected) return false;
    v++;
    size_t len = strlen(expected);
    return strncmp(v, expected, len) == 0 && v[len] == '"';
}

// Kembalikan true hanya jika ada field valid yang mengubah state.
inline bool parseCloudConfigJson(const char* json, CloudConfigState& st) {
    if (!json || !*json) return false;
    bool changed = false;

    bool hasDemo = parseCloudJsonStringEq(json, "\"timer_mode\"", "DEMO");
    bool hasAuto = parseCloudJsonStringEq(json, "\"timer_mode\"", "AUTO_DHT");
    bool hasManual = parseCloudJsonStringEq(json, "\"timer_mode\"", "MANUAL");
    if (hasDemo || hasAuto || hasManual) {
        if (hasDemo != st.demoMode) {
            st.demoMode = hasDemo;
            changed = true;
        }
        // Pertahankan pilihan AUTO_DHT/MANUAL saat DEMO aktif.
        if (!hasDemo) {
            bool wantAuto = hasAuto;
            if (wantAuto != st.autoDhtTimerMode) {
                st.autoDhtTimerMode = wantAuto;
                changed = true;
            }
        }
    }

    bool wantMuted = st.buzzerMuted;
    if (parseCloudJsonBool(json, "\"muted\"", &wantMuted)) {
        if (wantMuted != st.buzzerMuted) {
            st.buzzerMuted = wantMuted;
            changed = true;
        }
    }

    bool foundMins = false;
    float mins = parseCloudJsonFloat(json, "\"manual_interval_min\"", 0.0f, &foundMins);
    if (foundMins && mins >= (float)MIN_CUSTOM_INTERVAL_MIN && mins <= (float)MAX_CUSTOM_INTERVAL_MIN) {
        uint32_t newBase = (uint32_t)(mins * 60000.0f + 0.5f);
        if (newBase != st.customBaseIntervalMs) {
            st.customBaseIntervalMs = newBase;
            changed = true;
        }
    }

    bool foundEmpty = false;
    float emptyG = parseCloudJsonFloat(json, "\"empty_cup_weight_g\"", 0.0f, &foundEmpty);
    if (foundEmpty && emptyG >= CUP_ON_THRESHOLD && emptyG <= MAX_EMPTY_CUP_G &&
        fabsf(emptyG - st.emptyCupWeightG) > 0.5f) {
        st.emptyCupWeightG = emptyG;
        changed = true;
    }

    bool foundTare = false;
    uint64_t tareAt = parseCloudJsonUint64(json, "\"tare_at\"", 0ULL, &foundTare);
    if (foundTare && tareAt > 0ULL && tareAt != st.tareAt) {
        st.tareAt = tareAt;
        changed = true;
    }

    return changed;
}

#endif
