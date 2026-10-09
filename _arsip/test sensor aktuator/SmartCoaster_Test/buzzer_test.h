#pragma once
#define BUZZER_PIN 18

inline void buzzer_begin() {
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);
}

inline void buzzer_test() {
  Serial.println("[BUZZER] beep 3x GPIO18");
  for (int i = 0; i < 3; i++) {
    digitalWrite(BUZZER_PIN, HIGH); delay(300);
    digitalWrite(BUZZER_PIN, LOW); delay(300);
  }
}
