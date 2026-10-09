#include <Arduino.h>
#include <DHT.h>

#define PIN_BUZZER 18
#define PIN_MOTOR  2
#define PIN_DHT    19

// Ganti DHT11 menjadi DHT22 jika kalian membeli sensor warna putih
#define DHTTYPE DHT11

DHT dht(PIN_DHT, DHTTYPE);

void testBuzzer() {
  Serial.println("[TEST] Menguji Buzzer...");
  digitalWrite(PIN_BUZZER, HIGH);
  delay(300);
  digitalWrite(PIN_BUZZER, LOW);
  Serial.println("[TEST] Buzzer selesai.");
}

void testMotor() {
  Serial.println("[TEST] Menguji Motor Getar...");
  digitalWrite(PIN_MOTOR, HIGH);
  delay(400);
  digitalWrite(PIN_MOTOR, LOW);
  Serial.println("[TEST] Motor getar selesai.");
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
  digitalWrite(PIN_BUZZER, LOW);
  digitalWrite(PIN_MOTOR, LOW);

  dht.begin();

  Serial.println("Menu Pengujian Perangkat Keras:");
  Serial.println("Ketik '1' : Uji Buzzer");
  Serial.println("Ketik '2' : Uji Motor Getar");
  Serial.println("Ketik '3' : Baca Suhu dan Kelembaban DHT");
  Serial.println("Ketik '4' : Jalankan Semua Uji Berurutan");
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
    }
  }
}