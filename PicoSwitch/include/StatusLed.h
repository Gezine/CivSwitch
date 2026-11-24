#ifndef STATUS_LED_H
#define STATUS_LED_H

#include "pico/stdlib.h"

#ifdef CYW43_WL_GPIO_LED_PIN
#include "pico/cyw43_arch.h"
#endif

inline void statusLedSet(bool on) {
#ifdef CYW43_WL_GPIO_LED_PIN
  cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, on);
#else
  gpio_put(PICO_DEFAULT_LED_PIN, on);
#endif
}

inline void statusLedInit() {
#ifdef CYW43_WL_GPIO_LED_PIN
  if (cyw43_arch_init()) {
    panic("Failed to initialize CYW43");
  }
#else
  gpio_init(PICO_DEFAULT_LED_PIN);
  gpio_set_dir(PICO_DEFAULT_LED_PIN, GPIO_OUT);
#endif
  statusLedSet(false);
}

#endif
