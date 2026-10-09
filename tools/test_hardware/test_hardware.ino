#include <Arduino.h>
#include <DHT.h>

#define PIN_BUZZER 18
#define PIN_MOTOR  17
#define PIN_DHT    19

#define BUZZER_ACTIVE_LOW 1
#define MOTOR_ACTIVE_LOW  0

#define DHTTYPE DHT11

DHT dht(PIN_DHT, DHTTYPE);

inline void writeActuator(uint8_t pin, bool on, bool activeLow) {
  digitalWrite(pin, (on != activeLow) ? HIGH : LOW);
}

void testBuzzer() {
  Serial.println("[TEST] Menguji Buzzer (sesuai BUZZER_ACTIVE_LOW)...");
  writeActuator(PIN_BUZZER, true, BUZZER_ACTIVE_LOW);
  delay(300);
  writeActuator(PIN_BUZZER, false, BUZZER_ACTIVE_LOW);
  Serial.println("[TEST] Buzzer selesai.");
}

void testMotor() {
  Serial.println("[TEST] Menguji Motor Getar (sesuai MOTOR_ACTIVE_LOW)...");
  writeActuator(PIN_MOTOR, true, MOTOR_ACTIVE_LOW);
  delay(400);
  writeActuator(PIN_MOTOR, false, MOTOR_ACTIVE_LOW);
  Serial.println("[TEST] Motor getar selesai.");
}

void testPolarity() {
  Serial.println("[POLARITAS] GPIO18 (Buzzer) = HIGH selama 2 detik...");
  digitalWrite(PIN_BUZZER, HIGH);
  delay(2000);
  Serial.println("[POLARITAS] GPIO18 (Buzzer) = LOW selama 2 detik...");
  digitalWrite(PIN_BUZZER, LOW);
  delay(2000);
  writeActuator(PIN_BUZZER, false, BUZZER_ACTIVE_LOW);

  Serial.println("[POLARITAS] GPIO17 (Motor) = HIGH selama 2 detik...");
  digitalWrite(PIN_MOTOR, HIGH);
  delay(2000);
  Serial.println("[POLARITAS] GPIO17 (Motor) = LOW selama 2 detik...");
  digitalWrite(PIN_MOTOR, LOW);
  delay(2000);
  writeActuator(PIN_MOTOR, false, MOTOR_ACTIVE_LOW);
  Serial.println("[POLARITAS] Selesai. Catat level mana yang berbunyi/bergetar.");
}

void testDHT() {
  Serial.println("[TEST] Membaca sensor DHT...");
  float humidity = dht.readHumidity();
  float temperature = dht.readTemperature();

  if (isnan(humidity) || isnan(temperature)) {
    Serial.println("[ERROR] Gagal membaca data dari sensor DHT. Periksa kabel data di GPIO 19.");
    return;
  }

  Serial.print("Suhu: ");
  Serial.print(temperature, 1);
  Serial.print(" C | Kelembaban: ");
  Serial.print(humidity, 1);
  Serial.println(" %");
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  pinMode(PIN_BUZZER, OUTPUT);
  pinMode(PIN_MOTOR, OUTPUT);
  writeActuator(PIN_BUZZER, false, BUZZER_ACTIVE_LOW);
  writeActuator(PIN_MOTOR, false, MOTOR_ACTIVE_LOW);

  dht.begin();

  Serial.println("Menu Pengujian Perangkat Keras:");
  Serial.println("Ketik '1' : Uji Buzzer");
  Serial.println("Ketik '2' : Uji Motor Getar");
  Serial.println("Ketik '3' : Baca Suhu dan Kelembaban DHT");
  Serial.println("Ketik '4' : Jalankan Semua Uji Berurutan");
  Serial.println("Ketik '5' : Uji Polaritas Mentah HIGH vs LOW (2 detik)");
}

void loop() {
  if (Serial.available()) {
    char cmd = Serial.read();

    if (cmd == '1') {
      testBuzzer();
    } else if (cmd == '2') {
      testMotor();
    } else if (cmd == '3') {
      testDHT();
    } else if (cmd == '4') {
      testBuzzer();
      delay(500);
      testMotor();
      delay(500);
      testDHT();
    } else if (cmd == '5') {
      testPolarity();
    }
  }
}
