#include <Arduino.h>
#include <HX711.h>

#if defined(ESP32)
  #define PIN_HX711_DOUT 16
  #define PIN_HX711_SCK  4
#elif defined(ESP8266)
  #define PIN_HX711_DOUT D5
  #define PIN_HX711_SCK  D6
#else
  #define PIN_HX711_DOUT 2
  #define PIN_HX711_SCK  3
#endif

const float MAX_CAPACITY_GRAMS = 5000.0f;

HX711 scale;
float calibration_factor = 450.7f; // Terkalibrasi fisik dengan beban acuan 500 g
long zero_offset = 0;
uint32_t lastReadTime = 0;
const uint32_t READ_INTERVAL_MS = 300;

bool verify_hx711_connection() {
    if (!scale.wait_ready_timeout(1000)) {
        Serial.println(F("[ERROR] HX711 tidak merespon (timeout 1000 ms)."));
        Serial.println(F("Periksa koneksi VCC, GND, DOUT, dan SCK."));
        return false;
    }

    long raw = scale.read();
    if (raw == 0 || raw == 8388607L || raw == -8388608L) {
        Serial.print(F("[PERINGATAN] Nilai ADC mentah tidak wajar: "));
        Serial.println(raw);
        Serial.println(F("Periksa sambungan kabel jembatan regangan (E+, E-, A+, A-)."));
        return false;
    }

    return true;
}

void run_tare() {
    Serial.println(F("[TARE] Mengosongkan tatakan dan mengunci titik nol..."));
    scale.set_scale();
    scale.tare(20);
    zero_offset = scale.get_offset();
    scale.set_scale(calibration_factor);
    Serial.print(F("[TARE] Titik nol tersimpan. Offset ADC: "));
    Serial.println(zero_offset);
}

void invert_polarity() {
    calibration_factor = -calibration_factor;
    scale.set_scale(calibration_factor);
    Serial.print(F("[INVERT] Tanda faktor kalibrasi diubah menjadi: "));
    Serial.println(calibration_factor);
}

void calibrate_with_weight(float known_weight_grams) {
    if (known_weight_grams <= 0.0f) {
        Serial.println(F("[ERROR] Bobot acuan harus berupa angka positif lebih dari 0 gram."));
        return;
    }

    Serial.print(F("[KALIBRASI] Menghitung faktor skala untuk beban acuan: "));
    Serial.print(known_weight_grams, 1);
    Serial.println(F(" gram..."));

    long raw_avg = scale.read_average(20);
    long delta_adc = raw_avg - zero_offset;

    if (abs(delta_adc) < 100) {
        Serial.print(F("[GAGAL] Selisih ADC terlalu kecil (hanya "));
        Serial.print(delta_adc);
        Serial.println(F(" count). Pastikan beban sudah diletakkan di tatakan!"));
        return;
    }

    calibration_factor = (float)delta_adc / known_weight_grams;
    scale.set_scale(calibration_factor);

    Serial.print(F("[SUKSES] Faktor kalibrasi baru: "));
    Serial.println(calibration_factor, 1);
    Serial.println(F("Salin angka ini ke config.h pada DEFAULT_CALIBRATION_FACTOR."));
}

void run_noise_test() {
    Serial.println(F("[NOISE TEST] Mengukur 20 sampel statis..."));
    float min_val = 99999.0f;
    float max_val = -99999.0f;
    float sum = 0.0f;
    const int SAMPLES = 20;

    for (int i = 0; i < SAMPLES; i++) {
        if (!scale.wait_ready_timeout(500)) continue;
        float val = scale.get_units(1);
        if (val < min_val) min_val = val;
        if (val > max_val) max_val = val;
        sum += val;
        delay(50);
    }

    float avg = sum / SAMPLES;
    float p2p = max_val - min_val;

    Serial.println(F("--- Hasil Uji Derau Statis ---"));
    Serial.print(F("Rata-rata: ")); Serial.print(avg, 2); Serial.println(F(" g"));
    Serial.print(F("Minimum  : ")); Serial.print(min_val, 2); Serial.println(F(" g"));
    Serial.print(F("Maksimum : ")); Serial.print(max_val, 2); Serial.println(F(" g"));
    Serial.print(F("Peak-to-Peak Jitter: ")); Serial.print(p2p, 2); Serial.println(F(" g"));

    if (p2p > 5.0f) {
        Serial.println(F("[CATATAN] Derau masih di atas 5g. Periksa kekencangan baut dan isolasi kabel."));
    } else {
        Serial.println(F("[STATUS] Stabilitas sinyal dalam batas wajar."));
    }
}

void print_help_menu() {
    Serial.println(F("=================================================="));
    Serial.println(F("     PROGRAM PENGUJIAN LOAD CELL 5 KG + HX711     "));
    Serial.println(F("=================================================="));
    Serial.println(F("Perintah Serial Monitor:"));
    Serial.println(F("  't'         : Tare (kunci titik nol saat tatakan kosong)"));
    Serial.println(F("  'i'         : Balik tanda faktor (+/-)"));
    Serial.println(F("  'r'         : Tampilkan nilai mentah ADC 24-bit"));
    Serial.println(F("  'n'         : Jalankan uji derau (noise test)"));
    Serial.println(F("  '200'       : Kalibrasi langsung (ketik angka gramnya, misal: 200)"));
    Serial.println(F("  'cal:200'   : Format kalibrasi alternatif"));
    Serial.println(F("  'h'         : Tampilkan menu bantuan ini"));
    Serial.println(F("=================================================="));
}

void handle_serial_input() {
    if (!Serial.available()) return;

    String input = Serial.readStringUntil('\n');
    input.trim();
    if (input.length() == 0) return;

    if (input.equalsIgnoreCase("t")) {
        run_tare();
    } else if (input.equalsIgnoreCase("i")) {
        invert_polarity();
    } else if (input.equalsIgnoreCase("r")) {
        if (scale.wait_ready_timeout(500)) {
            Serial.print(F("[RAW ADC] Mentah: "));
            Serial.print(scale.read());
            Serial.print(F(" | Rata-rata 5x: "));
            Serial.print(scale.read_average(5));
            Serial.print(F(" | Zero Offset: "));
            Serial.println(zero_offset);
        } else {
            Serial.println(F("[ERROR] Sensor tidak siap membaca data raw."));
        }
    } else if (input.equalsIgnoreCase("n")) {
        run_noise_test();
    } else if (input.equalsIgnoreCase("h")) {
        print_help_menu();
    } else {
        // Pembersih input: dukung "cal:200", "cal 200", "cal=200", atau angka langsung "200"
        String numStr = input;
        numStr.toLowerCase();
        if (numStr.startsWith("cal:") || numStr.startsWith("cal=") || numStr.startsWith("cal ")) {
            numStr = numStr.substring(4);
            numStr.trim();
        }

        float weight = numStr.toFloat();
        if (weight > 0.0f) {
            calibrate_with_weight(weight);
        } else {
            Serial.println(F("[INFO] Perintah tidak dikenali. Ketik '200' untuk kalibrasi beban 200g, atau 't' untuk tare."));
        }
    }
}

void setup() {
    Serial.begin(115200);
    while (!Serial && millis() < 2000);

    Serial.println();
    print_help_menu();

    scale.begin(PIN_HX711_DOUT, PIN_HX711_SCK);

    if (verify_hx711_connection()) {
        Serial.println(F("[STATUS] Komunikasi HX711 terdeteksi normal."));
        run_tare();
    } else {
        Serial.println(F("[STATUS] Inisialisasi ditunda karena sensor belum terdeteksi."));
    }
}

void loop() {
    handle_serial_input();

    uint32_t now = millis();
    if (now - lastReadTime >= READ_INTERVAL_MS) {
        lastReadTime = now;

        if (scale.is_ready()) {
            long rawVal = scale.read();
            float weight = scale.get_units(5);

            Serial.print(F("Massa: "));
            if (weight >= 0.0f) Serial.print(F(" "));
            Serial.print(weight, 1);
            Serial.print(F(" g | Raw: "));
            Serial.print(rawVal);
            Serial.print(F(" | Faktor: "));
            Serial.print(calibration_factor, 1);

            if (weight > (MAX_CAPACITY_GRAMS + 200.0f)) {
                Serial.print(F(" | [BAHAYA] Beban > 5 kg!"));
            }

            Serial.println();
        }
    }
}
