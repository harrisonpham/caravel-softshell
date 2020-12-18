// Softshell testbench firmware.
//
// SPDX-FileCopyrightText: (c) 2020 Harrison Pham <harrison@harrisonpham.com>
// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#include "hw.h"

#include "../third_party/rocc-software/xcustom.h"

#define FIO_SHIFT_CFG_INSTRUCTION(cfg, clk_div) \
  ROCC_INSTRUCTION_0_R_R(1, cfg, clk_div, 0b0000001)

#define FIO_SHIFT_WRITE_INSTRUCTION(word) \
  ROCC_INSTRUCTION_0_R_R(1, word, word, 0b0000010)

#define ARRAY_SIZE(x) (sizeof(x) / sizeof(x[0]))

#define PIN_OFFSET 6

uint32_t mem_test[200];

void main() {
  // UART testbench loopback.
  REG_PINMUX_OUT_GPIOX_SEL(30 - PIN_OFFSET) = REG_PINMUX_OUT_SEL_UART0_TX;
  REG_PINMUX_IN_UART_RX_SEL = 31 - PIN_OFFSET + 1;

  REG_PINMUX_OUT_GPIOX_SEL(PIN_OFFSET + 8 + 0) = REG_PINMUX_OUT_SEL_CPU0_FLEXIO_0;
  REG_PINMUX_OUT_GPIOX_SEL(PIN_OFFSET + 8 + 1) = REG_PINMUX_OUT_SEL_CPU0_FLEXIO_1;
  REG_PINMUX_OUT_GPIOX_SEL(PIN_OFFSET + 8 + 2) = REG_PINMUX_OUT_SEL_CPU0_FLEXIO_2;
  REG_PINMUX_OUT_GPIOX_SEL(PIN_OFFSET + 8 + 3) = REG_PINMUX_OUT_SEL_CPU0_FLEXIO_3;
  REG_PINMUX_OUT_GPIOX_SEL(PIN_OFFSET + 8 + 4) = REG_PINMUX_OUT_SEL_CPU0_FLEXIO_4;
  REG_PINMUX_OUT_GPIOX_SEL(PIN_OFFSET + 8 + 5) = REG_PINMUX_OUT_SEL_CPU0_FLEXIO_5;
  REG_PINMUX_OUT_GPIOX_SEL(PIN_OFFSET + 8 + 6) = REG_PINMUX_OUT_SEL_CPU0_FLEXIO_6;
  REG_PINMUX_OUT_GPIOX_SEL(PIN_OFFSET + 8 + 7) = REG_PINMUX_OUT_SEL_CPU0_FLEXIO_7;
  REG_PINMUX_OUT_GPIOX_SEL(PIN_OFFSET + 8 + 8) = REG_PINMUX_OUT_SEL_CPU0_FLEXIO_8;

  // Configure flexio.
  uint32_t cfg, clk_div;
  cfg = (0xf << 24) | (8 << 16);
  clk_div = 64;
  FIO_SHIFT_CFG_INSTRUCTION(cfg, clk_div);

  // Test pattern.
  cfg = 0x5234567a;
  FIO_SHIFT_WRITE_INSTRUCTION(cfg);
  FIO_SHIFT_WRITE_INSTRUCTION(cfg);
  FIO_SHIFT_WRITE_INSTRUCTION(cfg);
  FIO_SHIFT_WRITE_INSTRUCTION(cfg);
  FIO_SHIFT_WRITE_INSTRUCTION(cfg);
  FIO_SHIFT_WRITE_INSTRUCTION(cfg);
  FIO_SHIFT_WRITE_INSTRUCTION(cfg);
  FIO_SHIFT_WRITE_INSTRUCTION(cfg);
  FIO_SHIFT_WRITE_INSTRUCTION(cfg);
  FIO_SHIFT_WRITE_INSTRUCTION(cfg);
  FIO_SHIFT_WRITE_INSTRUCTION(cfg);
  FIO_SHIFT_WRITE_INSTRUCTION(cfg);
  FIO_SHIFT_WRITE_INSTRUCTION(cfg);
  FIO_SHIFT_WRITE_INSTRUCTION(cfg);
  FIO_SHIFT_WRITE_INSTRUCTION(cfg);
  FIO_SHIFT_WRITE_INSTRUCTION(cfg);
  FIO_SHIFT_WRITE_INSTRUCTION(cfg);
  FIO_SHIFT_WRITE_INSTRUCTION(cfg);

  REG_UART0_CLK_DIV = 32;
  REG_UART0_CONFIG = 1;

  if (REG_UART0_DATA != 0xffffffff) {
    asm volatile("ebreak");
  }

  REG_UART0_DATA = 0x55;
  REG_UART0_DATA = 0xaa;
  REG_UART0_DATA = 0x00;

  if (REG_UART0_DATA != 0xaa) {
    asm volatile("ebreak");
  }

  REG_GPIO_ENA = 0x80000000;

  for (size_t i = 0; i < ARRAY_SIZE(mem_test); ++i) {
    mem_test[i] = (~i << 16) + i;
  }

  for (size_t i = 0; i < ARRAY_SIZE(mem_test); ++i) {
    if (mem_test[i] != (~i << 16) + i) {
      asm volatile("ebreak");
    }
  }

  uint32_t i = 0;
  while (true) {
    ++i;
    if (i == 10) {
      REG_GPIO_DATA = 0x80000000;
    }
  }

}
