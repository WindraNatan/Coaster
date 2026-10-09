#pragma once
#define MOTOR_PIN 2

inline void motor_begin() {
  pinMode(MOTOR_PIN, OUTPUT);
  digitalWrite(MOTOR_PIN, LOW);
}

inline void motor_test() {
  Serial.println("[MOTOR] getar 3x GPIO2");
  for (int i = 0; i < 3; i++) {
    digitalWrite(MOTOR_PIN, HIGH); delay(500);
    digitalWrite(MOTOR_PIN, LOW); delay(500);
  }
}
