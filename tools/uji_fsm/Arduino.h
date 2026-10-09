#pragma once
// Shim agar fsm.h + config.h + adaptive_controller.h bisa dikompilasi di PC (bukan di ESP32).
// Hanya menyediakan tipe integer dan isnan(); tidak ada API Arduino lain yang dipakai.
#include <stdint.h>
#include <math.h>
