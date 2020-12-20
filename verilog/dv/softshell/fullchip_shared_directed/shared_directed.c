/*
 * SPDX-FileCopyrightText: 2020 Efabless Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stdint.h>
#include <stddef.h>

#include "../../caravel/defs.h"
#include "../../caravel/stub.c"
#include "../../../rtl/softshell/dv/hw.h"

// Give bi-directional control to user macro.
#define GPIO_MODE_USER_BIDIR 0x1800
#define GPIO_MODE_MGMT_BIDIR 0x1801

void main() {
  // Indicate test start.
  reg_gpio_data = 1;
  reg_gpio_ena = 0;

  // Hold Softshell in reset.
  reg_la0_data = (0b1111 << 1) | (1 << 0);

  // Configure [4:0] as outputs to control the Softshell resets.
  // Remaining LA signals are inputs to the management SoC.
  reg_la0_ena = 0xffffffe0;    // [31:0]
  reg_la1_ena = 0xffffffff;    // [63:32]
  reg_la2_ena = 0xffffffff;    // [95:64]
  reg_la3_ena = 0xffffffff;    // [127:96]

  // Map all GPIOs to user project.
  reg_mprj_io_37 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_36 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_35 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_34 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_33 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_32 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_31 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_30 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_29 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_28 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_27 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_26 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_25 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_24 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_23 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_22 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_21 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_20 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_19 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_18 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_17 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_16 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_15 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_14 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_13 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_12 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_11 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_10 = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_9  = GPIO_MODE_USER_BIDIR;
  reg_mprj_io_8  = GPIO_MODE_USER_BIDIR;

  // Management dedicated pins.
  // reg_mprj_io_7  = GPIO_MODE_MGMT_BIDIR;
  // Mgmt UART TX.
  reg_mprj_io_6  = GPIO_MODE_MGMT_STD_OUTPUT;
  // reg_mprj_io_5  = GPIO_MODE_MGMT_BIDIR;
  // reg_mprj_io_4  = GPIO_MODE_MGMT_BIDIR;
  // reg_mprj_io_3  = GPIO_MODE_MGMT_BIDIR;
  // reg_mprj_io_2  = GPIO_MODE_MGMT_BIDIR;
  // reg_mprj_io_1  = GPIO_MODE_MGMT_BIDIR;
  // reg_mprj_io_0  = GPIO_MODE_MGMT_BIDIR;

  // Set UART clock to 64 kbaud (enable before I/O configuration).
  reg_uart_clkdiv = 625;
  reg_uart_enable = 1;

  // Apply configuration.
  reg_mprj_xfer = 1;
  while (reg_mprj_xfer == 1);

  // Release Softshell SoC and hold CPUs in reset so we don't propagate X's
  // when it tries to boot from non-existant flash.
  reg_la0_data = (0b1111 << 1) | (0 << 0);

  // Normally we would need to wait a few clocks for Softshell to release from
  // reset, but fortunately the XIP flash is really slow so Softshell has
  // plenty of time to reset before the wishbone transactions.

  // Shared RAM test over management WB.
  uint32_t *mem = (uint32_t *)SHARED_RAM_ADDR;
  for (size_t i = 0; i < SHARED_RAM_SIZE / sizeof(uint32_t); i += 123) {
    mem[i] = ((~i) << 16) | i;
  }

  mem = (uint32_t *)SHARED_RAM_ADDR;
  for (size_t i = 0; i < SHARED_RAM_SIZE / sizeof(uint32_t); i += 123) {
    if (mem[i] != (((~i) << 16) | i)) {
      asm volatile("ebreak");
    }
  }

  // Shared UART test over management WB.
  REG_UART0_CLK_DIV = 32;
  REG_UART0_CONFIG = 1;

  // UART TX Softshell virtual pin 31 (chip pin 37)
  REG_PINMUX_OUT_GPIOX_SEL(31) = REG_PINMUX_OUT_SEL_UART0_TX;
  // UART RX Softshell virtual pin 30 (chip pin 36)
  REG_PINMUX_IN_UART_RX_SEL = 30 + 1;

  // This is highly timing dependent, we are using the UART TX to delay us
  // before we readback.
  REG_UART0_DATA = 0x55;
  REG_UART0_DATA = 0x55;
  REG_UART0_DATA = 0x55;
  REG_UART0_DATA = 0x55;

  if (REG_UART0_DATA != 0x55) {
    asm volatile("ebreak");
  }

  print("H");

  // Indicate test finish.
  reg_gpio_data = 0;
}
