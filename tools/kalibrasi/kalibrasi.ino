#include <HX711.h>

// Skrip terpisah untuk mencari faktor kalibrasi sensor load cell
// Unggah skrip ini terlebih dahulu sebelum menjalankan program utama

#define PIN_HX711_DOUT 16
#define PIN_HX711_SCK  4

HX711 scale;
float calibration_factor = 450.7f; // Terkalibrasi fisik dengan beban acuan 500 g

void setup() {
    Serial.begin(115200);
    delay(1000);

    Serial.println(F("=== Program Kalibrasi Load Cell + HX711 ==="));
    Serial.println(F("1. Kosongkan tatakan sensor sekarang."));
    Serial.println(F("2. Menyetel titik nol (Tare)..."));

    scale.begin(PIN_HX711_DOUT, PIN_HX711_SCK);
    scale.set_scale();
    scale.tare(30);

    Serial.println(F("Titik nol tersimpan."));
    Serial.println(F("Letakkan benda dengan berat yang sudah diketahui (misal 100 gram)."));
    Serial.println(F("Gunakan tombol Serial berikut untuk menyesuaikan nilai:"));
    Serial.println(F("  '+' atau 'a' : Menaikkan faktor kalibrasi (+10)"));
    Serial.println(F("  '-' atau 'z' : Menurunkan faktor kalibrasi (-10)"));
    Serial.println(F("  'f'          : Selesai dan salin nilai akhir"));
    Serial.println(F("==========================================="));
}

void loop() {
    scale.set_scale(calibration_factor);

    Serial.print(F("Hasil Baca: "));
    Serial.print(scale.get_units(5), 1);
    Serial.print(F(" gram | Faktor Kalibrasi: "));
    Serial.println(calibration_factor);

    if (Serial.available()) {
        char inChar = (char)Serial.read();
        if (inChar == '+' || inChar == 'a') {
            calibration_factor += 10;
        } else if (inChar == '-' || inChar == 'z') {
            calibration_factor -= 10;
        } else if (inChar == 'f') {
            Serial.println(F("\n>>> SALIN NILAI INI KE config.h: <<<"));
            Serial.print(F("#define DEFAULT_CALIBRATION_FACTOR "));
            Serial.println(calibration_factor);
            Serial.println(F("========================================"));
        }
    }
    delay(200);
}
