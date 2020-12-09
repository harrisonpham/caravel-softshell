
#include <stdint.h>
#include <stdbool.h>

#include "hw.h"

uint32_t i;

void main() {

  while (true) {
    ++i;

    if (i == 10) {
      REG_GPIO_ENA = 0xff000000;
      REG_GPIO_DATA = 0x12345678;
    }
  }

}
