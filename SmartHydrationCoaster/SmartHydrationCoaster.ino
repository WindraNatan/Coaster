#include "config.h"
#include "filter.h"
#include "fsm.h"
#include "adaptive_controller.h"
#include <HX711.h>
#include <DHT.h>

HX711 scale;
DHT dht(PIN_DHT, DHT_TYPE);
MovingAverageFilter weightFilter(FILTER_WINDOW_SIZE);
CoasterFSM fsm;

uint32_t lastSampleTime = 0;
uint32_t lastDhtTime = 0;
uint32_t lastTelemetryTime = 0;
uint32_t lastActuatorToggle = 0;
uint32_t lastBadWeightWarn = 0;
bool alertModeActive = false;

float roomTempC = 27.0f;
float roomHumidity = 60.0f;
bool actuatorOutputState = false;
bool demoMode = true;
bool autoDhtTimerMode = true;

// H1b: polaritas kedua modul berlawanan (buzzer active-LOW, motor active-HIGH),
// jadi keduanya digerakkan lewat helper ini, bukan digitalWrite langsung.
inline void writeActuator(uint8_t pin, bool on, bool activeLow) {
    digitalWrite(pin, (on != activeLow) ? HIGH : LOW);
}

// H4: pola pulsing non-blocking; fase toggle di-reset saat masuk/keluar alert
// agar ketukan pertama selalu konsisten.
void handleActuators(CoasterState state, uint32_t nowMs) {
    bool alertActive = fsm.isAlertActive();
    if (alertActive != alertModeActive) {
        alertModeActive = alertActive;
        actuatorOutputState = false;
        lastActuatorToggle = nowMs;
    }

    if (!alertActive) {
        writeActuator(PIN_BUZZER, false, BUZZER_ACTIVE_LOW);
        writeActuator(PIN_MOTOR, false, MOTOR_ACTIVE_LOW);
        writeActuator(PIN_LED_ALERT, false, false);  // LED aktif-HIGH
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
    writeActuator(PIN_BUZZER, actuatorOutputState, BUZZER_ACTIVE_LOW);
    writeActuator(PIN_MOTOR, actuatorOutputState, MOTOR_ACTIVE_LOW);
    writeActuator(PIN_LED_ALERT, actuatorOutputState, false);  // LED aktif-HIGH
}

void updateAdaptiveInterval() {
    uint32_t baseMs = demoMode ? DEMO_INTERVAL_MS : BASE_INTERVAL_MS;
    if (autoDhtTimerMode) {
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
    Serial.println(fsm.getCheatCount());
}

void handleSerialCommands(float currentFilteredWeight) {
    if (!Serial.available()) return;
    char cmd = Serial.read();

    if (cmd == 't' || cmd == 'T') {
        Serial.println(F("[AKSI] Tare titik nol tatakan..."));
        scale.tare(20);
        weightFilter.reset();
    } else if (cmd == 'c' || cmd == 'C') {
        // M5: tolak berat yang tidak masuk akal untuk gelas kosong
        if (currentFilteredWeight > MAX_EMPTY_CUP_G) {
            Serial.print(F("[DITOLAK] Berat "));
            Serial.print(currentFilteredWeight, 1);
            Serial.print(F("g terlalu besar untuk gelas kosong (maks "));
            Serial.print(MAX_EMPTY_CUP_G, 0);
            Serial.println(F("g). Kosongkan gelas dulu, lalu tekan 'c'."));
        } else {
            fsm.setEmptyCupWeight(currentFilteredWeight);
            Serial.print(F("[KONFIG] Berat gelas kosong disimpan: "));
            Serial.print(fsm.getEmptyCupWeight(), 1);
            Serial.println(F(" gram."));
        }
    } else if (cmd == 'd' || cmd == 'D') {
        demoMode = !demoMode;
        updateAdaptiveInterval();
        Serial.print(F("[KONFIG] Mode Demo: "));
        Serial.println(demoMode ? F("AKTIF (15 detik)") : F("NONAKTIF (30 menit)"));
    } else if (cmd == 'm' || cmd == 'M') {
        autoDhtTimerMode = !autoDhtTimerMode;
        updateAdaptiveInterval();
        Serial.print(F("[KONFIG] Mode Timer: "));
        Serial.println(autoDhtTimerMode ? F("OTOMATIS (Adaptif DHT11)") : F("MANUAL"));
    } else if (cmd == 'r' || cmd == 'R') {
        fsm.resetDailyStats();
        Serial.println(F("[AKSI] Statistik harian di-reset ke nol."));
    }
}

void setup() {
    Serial.begin(115200);
    delay(500);

    pinMode(PIN_BUZZER, OUTPUT);
    pinMode(PIN_MOTOR, OUTPUT);
    pinMode(PIN_LED_ALERT, OUTPUT);
    writeActuator(PIN_BUZZER, false, BUZZER_ACTIVE_LOW);
    writeActuator(PIN_MOTOR, false, MOTOR_ACTIVE_LOW);

    dht.begin();
    scale.begin(PIN_HX711_DOUT, PIN_HX711_SCK);
    scale.set_scale(DEFAULT_CALIBRATION_FACTOR);
    scale.tare(20);

    updateAdaptiveInterval();

    Serial.println(F("Smart Hydration Coaster - ESP32 Siap."));
    Serial.println(F("Perintah: 't'=Tare, 'c'=Simpan Gelas Kosong, 'd'=Toggle Demo, 'm'=Auto/Manual, 'r'=Reset Harian"));
}

void loop() {
    uint32_t nowMs = millis();
    float filteredWeight = weightFilter.getAverage();

    handleSerialCommands(filteredWeight);

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

    // H3: guard sensor. Nilai NaN (HX711 belum siap / kabel lepas) atau di luar
    // rentang fisik diabaikan; FSM memakai bacaan valid terakhir.
    bool weightValid = filteredWeight == filteredWeight &&
                       filteredWeight >= WEIGHT_MIN_G && filteredWeight <= WEIGHT_MAX_G;
    if (!weightValid) {
        if (nowMs - lastBadWeightWarn >= 5000) {
            lastBadWeightWarn = nowMs;
            Serial.println(F("[PERINGATAN] Bacaan berat tidak valid (NaN/di luar rentang). Periksa kabel HX711."));
        }
    } else {
        uint16_t d0 = fsm.getDrinkCount();
        uint16_t r0 = fsm.getRefillCount();
        uint16_t c0 = fsm.getCheatCount();
        float baseBefore = fsm.getBaselineWeight();
        fsm.update(filteredWeight, nowMs);

        // [DBG] sementara: vonis yang diambil FSM saat transisi state
        static CoasterState lastDbgState = STATE_IDLE;
        if (fsm.getState() != lastDbgState) {
            lastDbgState = fsm.getState();
            Serial.print(F("[DBG] -> "));
            Serial.print(fsm.getStateString());
            Serial.print(F(" | w="));
            Serial.print(filteredWeight, 1);
            Serial.print(F(" | baseline="));
            Serial.print(baseBefore, 1);
            Serial.print(F(" | delta="));
            Serial.print(filteredWeight - baseBefore, 1);
            Serial.print(F("g | vonis="));
            if (fsm.getDrinkCount() != d0)      Serial.print(F("MINUM"));
            else if (fsm.getRefillCount() != r0) Serial.print(F("REFILL"));
            else if (fsm.getCheatCount() != c0)  Serial.print(F("CHEAT"));
            else                                 Serial.print(F("-"));
            Serial.println();
        }
    }

    handleActuators(fsm.getState(), nowMs);

    if (nowMs - lastTelemetryTime >= 500) {
        lastTelemetryTime = nowMs;
        printTelemetry(filteredWeight, nowMs);
    }
}
