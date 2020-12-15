#ifndef SOFTSHELL_DV_HW_H_
#define SOFTSHELL_DV_HW_H_

#include <stdint.h>
#include <stdbool.h>

extern uint32_t flashio_worker_begin;
extern uint32_t flashio_worker_end;

// Addresses.
#define GPIO_BASE_ADDR      0x20000000
#define PINMUX_BASE_ADDR    0x30810000
#define UART0_BASE_ADDR     0x30820000

// Private GPIO peripheral.
#define REG_GPIO_DATA (*(volatile uint32_t*)(GPIO_BASE_ADDR + 0x00))
#define REG_GPIO_ENA  (*(volatile uint32_t*)(GPIO_BASE_ADDR + 0x04))
#define REG_GPIO_PU   (*(volatile uint32_t*)(GPIO_BASE_ADDR + 0x08))
#define REG_GPIO_PD   (*(volatile uint32_t*)(GPIO_BASE_ADDR + 0x0c))

// Shared PINMUX.
#define REG_PINMUX_IN_UART_RX_SEL \
  (*(volatile uint32_t*)(PINMUX_BASE_ADDR + 0x1000 + 0))
#define REG_PINMUX_OUT_GPIOX_SEL(x) \
  (*(volatile uint32_t*)(PINMUX_BASE_ADDR + 0x2000 + (x << 2)))

#define REG_PINMUX_OUT_SEL_UART0_TX 1
#define REG_PINMUX_OUT_SEL_CPU0_FLEXIO_0 2
#define REG_PINMUX_OUT_SEL_CPU0_FLEXIO_1 3
#define REG_PINMUX_OUT_SEL_CPU0_FLEXIO_2 4
#define REG_PINMUX_OUT_SEL_CPU0_FLEXIO_3 5
#define REG_PINMUX_OUT_SEL_CPU0_FLEXIO_4 6
#define REG_PINMUX_OUT_SEL_CPU0_FLEXIO_5 7
#define REG_PINMUX_OUT_SEL_CPU0_FLEXIO_6 8
#define REG_PINMUX_OUT_SEL_CPU0_FLEXIO_7 9
#define REG_PINMUX_OUT_SEL_CPU0_FLEXIO_8 10

// Shared UART0.
#define REG_UART0_CLK_DIV (*(volatile uint32_t*)(UART0_BASE_ADDR + 0x00))
#define REG_UART0_DATA    (*(volatile uint32_t*)(UART0_BASE_ADDR + 0x04))
#define REG_UART0_CONFIG  (*(volatile uint32_t*)(UART0_BASE_ADDR + 0x08))

#endif  // SOFTSHELL_DV_
